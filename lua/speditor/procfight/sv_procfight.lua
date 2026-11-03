-- ============================================================================
-- GM:FM Procedural Fight Scene — Server Session Manager & Net Handlers
-- ============================================================================
if CLIENT then return end

GMFM_ProcFight = GMFM_ProcFight or {}
local PF = GMFM_ProcFight
PF.Sessions = PF.Sessions or {}

-- ============================================================================
-- BROADCAST HELPERS
-- ============================================================================
function PF.SendSessionState(ply, session)
    if not IsValid(ply) then return end
    net.Start("SPeditor_PF_State")
    net.WriteBool(session ~= nil and session.active == true)
    if session and session.active then
        net.WriteString(session.config.combatType or "melee")
        net.WriteString(session.config.fightStyle or "cinematic")
        net.WriteFloat(session.startTime or CurTime())
        net.WriteFloat(session.config.maxDuration or 25)
        net.WriteUInt(#session.fighters, 8)
        for _, f in ipairs(session.fighters) do
            net.WriteInt(f.uid or 0, 32)
            net.WriteString(f.name or "Fighter")
            net.WriteUInt(math.Clamp(f.team or 0, 0, 8), 4)
            net.WriteInt(math.max(0, math.Round(f.hp or 0)), 16)
            net.WriteInt(math.max(1, math.Round(f.maxHP or 100)), 16)
            net.WriteBool(f.dead == true)
            net.WriteVector(IsValid(f.sceneEnt) and f.sceneEnt:GetPos() or f.lastPos or vector_origin)
        end
    end
    net.Send(ply)
end

function PF.BroadcastEvent(session, evType, payload)
    if not session or not IsValid(session.ply) then return end
    net.Start("SPeditor_PF_Event")
    net.WriteString(tostring(evType or "info"))
    net.WriteString(util.TableToJSON(payload or {}) or "{}")
    net.Send(session.ply)
end

-- ============================================================================
-- RESOLVE OR AUTO-POPULATE 2+ FIGHTERS FOR A SESSION
-- ============================================================================
local function GatherOrSpawnFighters(ply, requestedSpecs)
    local S = SPeditor.Server
    local listOut = {}
    local seenEnts = {}

    if istable(requestedSpecs) then
        for _, spec in ipairs(requestedSpecs) do
            local ent = nil
            if spec.uid and spec.uid > 0 and S.FindUID then
                ent = S.FindUID(ply, spec.uid)
            end
            if not IsValid(ent) and spec.entIndex and spec.entIndex > 0 then
                ent = Entity(spec.entIndex)
            end
            if IsValid(ent) and not seenEnts[ent] and (ent:GetClass() == "prop_ragdoll" or ent:GetClass() == "prop_dynamic" or ent:IsNPC()) then
                seenEnts[ent] = true
                table.insert(listOut, {
                    ent      = ent,
                    name     = spec.name or ent.SPeditor_Name or ent:GetClass(),
                    team     = tonumber(spec.team) or 0,
                    weapon   = spec.weapon or "",
                    hp       = tonumber(spec.hp) or 100,
                    npcClass = spec.npcClass,
                })
            end
        end
    end

    -- If fewer than 2 fighters were explicitly passed, look for existing GM:FM ragdolls in the scene
    if #listOut < 2 and S.List then
        for _, ent in ipairs(S.List(ply)) do
            if IsValid(ent) and not seenEnts[ent] and ent:GetClass() == "prop_ragdoll" and not S.IsAux(ent) and not ent.SPeditor_Attach then
                seenEnts[ent] = true
                table.insert(listOut, {
                    ent    = ent,
                    name   = ent.SPeditor_Name or ("Fighter #" .. (#listOut + 1)),
                    team   = (#listOut % 2) + 1,
                    weapon = "",
                    hp     = 100,
                })
                if #listOut >= 4 then break end
            end
        end
    end

    -- Still fewer than 2? Spawn missing fighters automatically so 1-click fight ALWAYS works!
    if #listOut < 2 then
        local tr = ply:GetEyeTrace()
        local centerPos = (tr.Hit and tr.HitPos:Distance(ply:GetPos()) < 900)
            and tr.HitPos
            or (ply:GetPos() + ply:GetForward() * 180)

        if #listOut == 1 and IsValid(listOut[1].ent) then
            centerPos = listOut[1].ent:GetPos()
        end

        local needed = 2 - #listOut
        for i = 1, needed do
            local slotIdx = #listOut + 1
            local tpl = PF.FighterTemplates[(slotIdx % 2 == 1) and 1 or 3]
            local offset = (slotIdx == 1) and Vector(-65, 0, 2) or Vector(65, 0, 2)
            local faceAng = (slotIdx == 1) and Angle(0, 0, 0) or Angle(0, 180, 0)

            local rag = S.SpawnModel(ply, tpl.model, centerPos + offset, faceAng)
            if IsValid(rag) then
                rag.SPeditor_Name = tpl.name
                rag:SetNW2String("SPeditor_Name", tpl.name)
                seenEnts[rag] = true
                table.insert(listOut, {
                    ent      = rag,
                    name     = tpl.name,
                    team     = slotIdx,
                    weapon   = "",
                    hp       = 100,
                    npcClass = tpl.npc,
                })
            end
        end
    end

    return listOut
end

-- ============================================================================
-- START PROCEDURAL FIGHT SESSION
-- ============================================================================
function PF.StartSession(ply, configIn, fighterSpecs)
    if not IsValid(ply) then return false end
    local S = SPeditor.Server
    local SA_COMP = SPeditor.Component and SPeditor.Component("saeditor")
    local SA = SA_COMP and SA_COMP.SA
    if not S or not SA then return false end

    -- Stop any active session first
    if PF.Sessions[ply] and PF.Sessions[ply].active then
        PF.StopSession(ply, true)
    end

    -- Also stop standard SAeditor take if one was running
    if SA.StopRecord then
        pcall(SA.StopRecord, ply)
    end

    local combatType = configIn and configIn.combatType or "melee"
    local fightStyle = configIn and configIn.fightStyle or "cinematic"
    local cfg = PF.DefaultConfig(combatType, fightStyle)

    if istable(configIn) then
        for k, v in pairs(configIn) do
            if v ~= nil then cfg[k] = v end
        end
    end

    cfg.timeScale        = math.Clamp(tonumber(cfg.timeScale) or 1.0, 0.20, 1.0)
    cfg.bakeTimeStretch  = math.Clamp(tonumber(cfg.bakeTimeStretch) or 1.0, 0.50, 3.5)
    cfg.killMoveChance   = math.Clamp(tonumber(cfg.killMoveChance) or 50, 0, 100)
    cfg.maxDuration      = math.Clamp(tonumber(cfg.maxDuration) or 25, 4, 180)
    cfg.step             = math.Clamp(math.Round(tonumber(cfg.step) or 1), 1, 6)

    local resolvedSpecs = GatherOrSpawnFighters(ply, fighterSpecs)
    if #resolvedSpecs < 2 then
        return false
    end

    local a = SA.Anim(ply)
    a.playing = false

    local startFrame = math.Clamp(math.Round(a.cur or 0), 0, (SA.MAX_FRAMES or 7200) - 30)

    local session = {
        ply             = ply,
        active          = true,
        config          = cfg,
        startTime       = CurTime(),
        startFrame      = startFrame,
        simFrame        = 0,
        lastSampledStep = -1,
        fps             = a.fps or 24,
        fighters        = {},
        recordedSounds  = {},
        recordedEffects = {},
        directorCuts    = {},
    }

    for i, spec in ipairs(resolvedSpecs) do
        local entry = PF.SetupFighterAI(session, i, spec)
        if entry then
            table.insert(session.fighters, entry)
        end
    end

    if #session.fighters < 2 then
        for _, f in ipairs(session.fighters) do
            if IsValid(f.npc) then SafeRemoveEntity(f.npc) end
            if IsValid(f.meleeAnimRig) then SafeRemoveEntity(f.meleeAnimRig) end
            if IsValid(f.kmAnim) then SafeRemoveEntity(f.kmAnim) end
        end
        return false
    end

    PF.RefreshFighterRelationships(session)

    -- Apply Cinematic / Realistic / Normal timescale
    game.SetTimeScale(cfg.timeScale)

    -- Configure BSMod convars if BSMod is installed
    if PF.IsBSModInstalled() and cfg.bsmodCompat then
        local cAny = GetConVar("bsmod_killmove_anytime")
        if cAny then
            session.oldBSModAnytime = cAny:GetInt()
            RunConsoleCommand("bsmod_killmove_anytime", "1")
        end
    end

    PF.Sessions[ply] = session

    -- Sample frame 0 immediately
    for _, f in ipairs(session.fighters) do
        PF.SyncFighterToRagdoll(session, f, true)
    end
    PF.StepAutoDirectorCamera(session, 0)
    PF.SampleTimelineFrame(session, 0)

    PF.SendSessionState(ply, session)
    PF.BroadcastEvent(session, "started", {
        combatType = cfg.combatType,
        fightStyle = cfg.fightStyle,
        fighters   = #session.fighters,
    })

    return true
end

-- ============================================================================
-- STOP & BAKE PROCEDURAL FIGHT SESSION
-- ============================================================================
function PF.StopSession(ply, bakeToTimeline)
    local session = PF.Sessions[ply]
    if not session then return end
    PF.Sessions[ply] = nil
    session.active = false

    -- Restore normal game time scale
    game.SetTimeScale(1.0)

    -- Restore BSMod convar if changed
    if session.oldBSModAnytime ~= nil and ConVarExists("bsmod_killmove_anytime") then
        RunConsoleCommand("bsmod_killmove_anytime", tostring(session.oldBSModAnytime))
    end

    -- Clean up any remaining AI proxy NPCs & BSMod animation rigs
    if session.activeKillMove then
        if IsValid(session.activeKillMove.attKmAnim) then SafeRemoveEntity(session.activeKillMove.attKmAnim) end
        if IsValid(session.activeKillMove.vicKmAnim) then SafeRemoveEntity(session.activeKillMove.vicKmAnim) end
        session.activeKillMove = nil
    end
    for _, f in ipairs(session.fighters or {}) do
        if IsValid(f.npc) then
            SafeRemoveEntity(f.npc)
            f.npc = nil
        end
        if IsValid(f.meleeAnimRig) then
            SafeRemoveEntity(f.meleeAnimRig)
            f.meleeAnimRig = nil
        end
        if IsValid(f.kmAnim) then
            SafeRemoveEntity(f.kmAnim)
            f.kmAnim = nil
        end
    end

    if bakeToTimeline ~= false and IsValid(ply) then
        PF.FinalizeBakeToTimeline(session)
        PF.BroadcastEvent(session, "baked", {
            frames = (session.maxTimelineFrame or session.startFrame or 0) - (session.startFrame or 0),
        })
    end

    if IsValid(ply) then
        PF.SendSessionState(ply, nil)
    end
end

-- ============================================================================
-- THINK LOOP: DRIVE AI, KILLMOVES, BONE PUPPETEERING & TIMELINE RECORDING
-- ============================================================================
hook.Add("Think", "GMFM_ProcFight_ServerThink", function()
    if table.IsEmpty(PF.Sessions) then return end

    local now = CurTime()

    for ply, session in pairs(PF.Sessions) do
        if not IsValid(ply) or not session.active then
            PF.StopSession(ply, false)
        else
            PF.UpdateTimeScale(session)

            local elapsed = now - session.startTime
            if elapsed >= (session.config.maxDuration or 25) then
                PF.StopSession(ply, true)
            else
                -- Step active KillMove choreography
                if session.activeKillMove then
                    PF.StepKillMove(session)
                end

                -- Step each living fighter's AI & combat choreography
                local livingTeams = {}
                local livingCount = 0

                for _, f in ipairs(session.fighters) do
                    if not f.dead and not IsValid(f.npc) then
                        f.dead = true
                        f.deathTime = now
                    end
                    if not f.dead then
                        livingCount = livingCount + 1
                        local teamKey = (f.team and f.team > 0) and ("T" .. f.team) or ("FFA_" .. f.index)
                        livingTeams[teamKey] = true

                        if session.config.combatType == "gunfight" then
                            PF.StepGunfightFighter(session, f, now)
                        else
                            PF.StepMeleeFighter(session, f, now)
                        end
                    end

                    -- Sync NPC skeleton + procedural combat/killmove pose overlays onto GM:FM ragdoll
                    PF.SyncFighterToRagdoll(session, f, false)
                end

                -- Compute simulation frame and sample onto GM:FM timeline
                local simFrame = math.floor(elapsed * (session.fps or 30))
                session.simFrame = simFrame

                PF.StepAutoDirectorCamera(session, simFrame)

                local step = session.config.step or 1
                local stepBucket = math.floor(simFrame / step)
                if stepBucket > (session.lastSampledStep or -1) then
                    session.lastSampledStep = stepBucket
                    PF.SampleTimelineFrame(session, simFrame)
                end

                -- Periodically update client HUD state
                if now >= (session.nextStateSend or 0) then
                    session.nextStateSend = now + 0.25
                    PF.SendSessionState(ply, session)
                end

                -- Check if only 1 team/fighter remains alive -> wait 1.6s to record victory pose & ragdoll settle, then auto-bake!
                if table.Count(livingTeams) <= 1 and not session.activeKillMove then
                    if not session.victoryEndTime then
                        session.victoryEndTime = now + 1.65
                    elseif now >= session.victoryEndTime then
                        PF.StopSession(ply, true)
                    end
                else
                    session.victoryEndTime = nil
                end
            end
        end
    end
end)

-- ============================================================================
-- CAPTURE COMBAT SOUNDS EMITTED BY FIGHTERS FOR TIMELINE BAKING
-- ============================================================================
hook.Add("EntityEmitSound", "GMFM_ProcFight_CaptureSounds", function(data)
    if table.IsEmpty(PF.Sessions) or not data then return end
    local ent = data.Entity
    if not IsValid(ent) then return end

    local session = ent.GMFM_PF_Session
    if not session then
        local owner = ent:GetOwner()
        if IsValid(owner) then session = owner.GMFM_PF_Session end
    end
    if not session or not session.active then return end

    PF.RecordCombatSound(session, data.SoundName, data.Volume, data.Pitch)
end)

hook.Add("PlayerDisconnected", "GMFM_ProcFight_Disconnect", function(ply)
    if PF.Sessions[ply] then
        PF.StopSession(ply, false)
    end
end)

hook.Add("PostCleanupMap", "GMFM_ProcFight_Cleanup", function()
    for ply, _ in pairs(PF.Sessions) do
        PF.StopSession(ply, false)
    end
end)

-- ============================================================================
-- NETWORK HANDLERS
-- ============================================================================
net.Receive("SPeditor_PF_Start", function(_, ply)
    local configJson = net.ReadString()
    local specsJson  = net.ReadString()
    local config = util.JSONToTable(configJson or "{}") or {}
    local specs  = util.JSONToTable(specsJson or "[]") or {}
    PF.StartSession(ply, config, specs)
end)

net.Receive("SPeditor_PF_Stop", function(_, ply)
    local bake = net.ReadBool()
    PF.StopSession(ply, bake)
end)

net.Receive("SPeditor_PF_ForceKillMove", function(_, ply)
    local session = PF.Sessions[ply]
    if not session or not session.active then return end
    local kmId = net.ReadString()
    if kmId == "" then kmId = nil end

    -- Find two living enemy fighters and trigger an immediate KillMove!
    for _, f1 in ipairs(session.fighters) do
        if not f1.dead and not f1.inKillMove then
            local enemy = PF.FindNearestEnemy(session, f1)
            if enemy and not enemy.dead and not enemy.inKillMove then
                PF.StartKillMove(session, f1, enemy, kmId, true)
                break
            end
        end
    end
end)

net.Receive("SPeditor_PF_SpawnFighter", function(_, ply)
    local S = SPeditor.Server
    if not S then return end
    local tplIdx = net.ReadUInt(8)
    local teamId = net.ReadUInt(4)
    local tpl = PF.FighterTemplates[tplIdx] or PF.FighterTemplates[1]

    local tr = ply:GetEyeTrace()
    local spawnPos = (tr.Hit and tr.HitPos:Distance(ply:GetPos()) < 800)
        and (tr.HitPos + Vector(math.Rand(-45, 45), math.Rand(-45, 45), 2))
        or (ply:GetPos() + ply:GetForward() * 150 + Vector(0, 0, 4))
    local spawnAng = Angle(0, (ply:GetPos() - spawnPos):Angle().y, 0)

    local rag = S.SpawnModel(ply, tpl.model, spawnPos, spawnAng)
    if IsValid(rag) then
        rag.SPeditor_Name = tpl.name
        rag:SetNW2String("SPeditor_Name", tpl.name)
        if S.SendSpawned then S.SendSpawned(ply, rag, false) end
        PF.BroadcastEvent({ ply = ply }, "spawned_fighter", {
            uid      = rag.SPeditor_UID,
            entIndex = rag:EntIndex(),
            name     = tpl.name,
            model    = tpl.model,
            team     = (teamId > 0) and teamId or tpl.team or 1,
        })
    end
end)

net.Receive("SPeditor_PF_CMenuAction", function(_, ply)
    local action     = net.ReadString()
    local combatType = net.ReadString()
    local fightStyle = net.ReadString()
    local count      = net.ReadUInt(8)
    local specs      = {}

    local S = SPeditor.Server
    for i = 1, count do
        local entIdx = net.ReadUInt(16)
        local ent = Entity(entIdx)
        if IsValid(ent) then
            table.insert(specs, {
                entIndex = entIdx,
                uid      = ent:GetNW2Int("SPeditor_UID", 0),
                name     = ent.SPeditor_Name or ent:GetClass(),
                team     = 0,
            })
        end
    end

    if action == "quick_start" then
        local cfg = PF.DefaultConfig(combatType, fightStyle)
        PF.StartSession(ply, cfg, specs)
    end
end)
