-- ============================================================================
-- GM:FM Procedural Fight Scene — Skeleton Puppeteer, Auto-Director Camera
-- & Timeline Keyframe Baker
-- ============================================================================
if CLIENT then return end

GMFM_ProcFight = GMFM_ProcFight or {}
local PF = GMFM_ProcFight

local function SetPhysSafe(p, pos, ang)
    if not IsValid(p) then return end
    if SPeditor and SPeditor.ValidVec and (not SPeditor.ValidVec(pos) or not SPeditor.ValidAng(ang)) then return end
    local ent = p:GetEntity()
    if IsValid(ent) then ent.SPeditor_Placed = true end
    p:EnableMotion(false)
    p:SetPos(pos)
    p:SetAngles(ang)
    p:Wake()
end

-- ============================================================================
-- SYNC ACTIVE ANIMATION SOURCE (HL2 NPC / BSMOD MELEE RIG / BSMOD KILLMOVE RIG)
-- TO GM:FM SCENE RAGDOLL (Matches GMFM_ref sv_saeditor_record.lua + S.SnapRigid)
-- ============================================================================
function PF.SyncFighterToRagdoll(session, entry, forceSnap)
    local rag = entry and entry.sceneEnt
    if not IsValid(rag) then return end

    -- If fighter died and is now driven by natural ragdoll physics, keep ragdoll guard off and update flex
    if entry.ragdollPhysicsActive and not forceSnap then
        rag.SPeditor_Placed = true
        rag.SPeditor_Guard = nil
        PF.UpdateFighterFlexes(session, entry)
        return
    end

    -- Select active animation source:
    --   1. BSMod KillMove rig (models/weapons/c_limbs.mdl or models/bsmodimations_human.mdl)
    --   2. BSMod Melee rig (models/player/kleiner.mdl or models/player/alyx.mdl playing fist_idle_01 / range_fists_*)
    --   3. HL2 AI NPC (playing Half-Life 2 default gun animations in Gunfight mode)
    local animSource = nil
    if IsValid(entry.kmAnim) then
        animSource = entry.kmAnim
    elseif session and session.config and session.config.combatType == "melee" and IsValid(entry.meleeAnimRig) then
        animSource = entry.meleeAnimRig
    elseif IsValid(entry.npc) then
        animSource = entry.npc
    end

    if not IsValid(animSource) then return end

    -- Force Source Engine server-side skeleton bone cache to update for this tick
    animSource:GetBonePosition(0)
    if animSource.SetupBones then animSource:SetupBones() end
    rag:GetBonePosition(0)

    local basePos = animSource:GetPos()
    local baseAng = animSource:GetAngles()
    local srcMdl  = string.lower(animSource:GetModel() or "")
    local ragMdl  = string.lower(rag:GetModel() or "")
    local sameModel = (srcMdl == ragMdl)

    entry.prevBonePos  = entry.prevBonePos or {}
    entry.lastBoneVel  = entry.lastBoneVel or {}
    entry.boneMapCache = entry.boneMapCache or {}
    local dt = math.max(0.005, FrameTime())

    if rag:GetClass() == "prop_ragdoll" and rag:GetPhysicsObjectCount() > 1 then
        local physCount = rag:GetPhysicsObjectCount()
        local map = entry.boneMapCache[srcMdl]
        if not map then
            map = {}
            for pIdx = 0, physCount - 1 do
                local ragBone = rag:TranslatePhysBoneToBone(pIdx)
                if ragBone and ragBone >= 0 then
                    if sameModel then
                        map[pIdx] = ragBone
                    else
                        local bName = rag:GetBoneName(ragBone)
                        map[pIdx] = (bName and animSource:LookupBone(bName)) or -1
                    end
                else
                    map[pIdx] = -1
                end
            end
            entry.boneMapCache[srcMdl] = map
        end

        for pIdx = 0, physCount - 1 do
            local srcBone = map[pIdx]
            if srcBone and srcBone >= 0 then
                local phys = rag:GetPhysicsObjectNum(pIdx)
                if IsValid(phys) then
                    local pos, ang
                    local m = animSource:GetBoneMatrix(srcBone)
                    if m then
                        pos, ang = m:GetTranslation(), m:GetAngles()
                    else
                        pos, ang = animSource:GetBonePosition(srcBone)
                    end

                    if pos and ang then
                        if entry.prevBonePos[pIdx] then
                            entry.lastBoneVel[pIdx] = (pos - entry.prevBonePos[pIdx]) / dt
                        end
                        entry.prevBonePos[pIdx] = pos
                        SetPhysSafe(phys, pos, ang)
                    end
                end
            end
        end

        -- Snap child physics objects to the ragdoll's own rigid bone lengths while preserving animated world angles
        if SPeditor and SPeditor.Server and SPeditor.Server.SnapRigid then
            SPeditor.Server.SnapRigid(rag)
        end
    else
        rag:SetPos(basePos)
        rag:SetAngles(baseAng)
    end

    -- Keep S.WEAR (EF_BONEMERGE) weapons attached cleanly without fighting bonemerge
    if IsValid(entry.wepEnt) and not entry.dead and not entry.wepEnt.SPeditor_Attach then
        local rhId = rag:LookupAttachment("anim_attachment_RH")
        local rh = (rhId and rhId > 0) and rag:GetAttachment(rhId) or nil
        if rh and rh.Pos and rh.Ang then
            entry.wepEnt:SetPos(rh.Pos)
            entry.wepEnt:SetAngles(rh.Ang)
            local wPhys = entry.wepEnt:GetPhysicsObjectNum(0)
            if IsValid(wPhys) then
                SetPhysSafe(wPhys, rh.Pos, rh.Ang)
            end
        end
    end

    PF.UpdateFighterFlexes(session, entry)
end

-- ============================================================================
-- PROCEDURAL FACIAL EXPRESSIONS (CACHED & THROTTLED FOR ZERO LAG)
-- ============================================================================
function PF.UpdateFighterFlexes(session, entry)
    if not session or not session.config.recordFlex then return end
    local rag = entry and entry.sceneEnt
    if not IsValid(rag) or not rag.GetFlexNum then return end

    local now = CurTime()
    local isAttacking = (entry.activeStrike ~= nil) or (entry.inKillMove and entry.inKillMove.attacker == entry)
    local isVictim    = (entry.inKillMove and entry.inKillMove.victim == entry) or (entry.flinchUntil and now < entry.flinchUntil)
    local isDead      = entry.dead
    local stateKey    = isDead and 3 or (isVictim and 2 or (isAttacking and 1 or 0))

    if entry.lastFlexState == stateKey and now < (entry.nextFlexUpdate or 0) then
        return
    end
    entry.lastFlexState  = stateKey
    entry.nextFlexUpdate = now + 0.12

    local nFlex = rag:GetFlexNum() or 0
    if nFlex <= 0 then return end

    if not rag._pfFlexRoles then
        local roles = {}
        for i = 0, nFlex - 1 do
            local name = string.lower(rag:GetFlexName(i) or "")
            if string.find(name, "lid_closer", 1, true) or string.find(name, "blink", 1, true) then
                roles[i] = "blink"
            elseif string.find(name, "jaw_drop", 1, true) or string.find(name, "pain", 1, true) then
                roles[i] = "jaw"
            elseif string.find(name, "wrinkler", 1, true) or string.find(name, "lowerer", 1, true) then
                roles[i] = "brow"
            elseif string.find(name, "lid_tightener", 1, true) then
                roles[i] = "squint"
            elseif string.find(name, "bite", 1, true) or string.find(name, "sneer", 1, true) then
                roles[i] = "sneer"
            end
        end
        rag._pfFlexRoles = roles
    end

    local S = SPeditor and SPeditor.Server
    local blinkNow = (math.floor(now * 3 + entry.index) % 11 == 0)

    for i, role in pairs(rag._pfFlexRoles) do
        local weight = 0
        if stateKey == 3 then
            if role == "blink" then weight = 0.95 elseif role == "jaw" then weight = 0.25 end
        elseif stateKey == 2 then
            if role == "jaw" then weight = 0.75 elseif role == "brow" then weight = 0.85 elseif role == "squint" then weight = 0.65 end
        elseif stateKey == 1 then
            if role == "sneer" or role == "brow" then weight = 0.80 elseif role == "jaw" then weight = 0.45 end
        else
            if role == "brow" then weight = 0.35 elseif role == "blink" and blinkNow then weight = 0.90 end
        end

        if S and S.SetFlex then
            S.SetFlex(rag, i, weight)
        elseif SPeditor and SPeditor.FlexSet then
            SPeditor.FlexSet(rag, i, weight)
        else
            rag:SetFlexWeight(i, weight)
        end
    end
end

-- ============================================================================
-- RECORD TIMELINE EFFECTS & SOUNDS
-- ============================================================================
function PF.RecordCombatEffect(session, effectClass, pos, ang)
    if not session or not session.config.recordEffects then return end
    session.recordedEffects = session.recordedEffects or {}
    if #session.recordedEffects >= 120 then return end
    table.insert(session.recordedEffects, {
        simFrame = session.simFrame or 0,
        effect   = effectClass,
        pos      = Vector(pos.x, pos.y, pos.z),
        ang      = Angle(ang.p, ang.y, ang.r),
    })
end

function PF.RecordCombatSound(session, sndPath, volume, pitch, uid)
    if not session or not session.config.recordSounds then return end
    if not isstring(sndPath) or sndPath == "" then return end
    session.recordedSounds = session.recordedSounds or {}
    if #session.recordedSounds >= 250 then return end
    table.insert(session.recordedSounds, {
        simFrame = session.simFrame or 0,
        path     = sndPath,
        volume   = math.Clamp(tonumber(volume) or 1, 0, 2),
        pitch    = math.Clamp(math.Round(tonumber(pitch) or 100), 50, 200),
        uid      = uid or 0,
    })
end

-- ============================================================================
-- CINEMATIC AUTO-DIRECTOR CAMERA
-- ============================================================================
function PF.OnDirectorEvent(session, evType, data)
    if not session or not session.config.autoDirectorCam then return end
    local now = CurTime()

    if evType == "killmove_start" and data then
        session.directorShot = {
            mode      = "killmove_closeup",
            untilTime = data.endTime + 0.35,
            attacker  = data.attacker,
            victim    = data.victim,
            fov       = 52,
            cutQueued = true,
        }
    elseif evType == "fighter_killed" and data then
        session.directorShot = {
            mode      = "ko_hero",
            untilTime = now + 1.25,
            attacker  = data.attacker,
            victim    = data.victim,
            fov       = 56,
            cutQueued = true,
        }
    end
end

function PF.StepAutoDirectorCamera(session, frameIdx)
    if not session or not session.config.autoDirectorCam then return end
    local S = SPeditor.Server
    local ply = session.ply
    if not IsValid(ply) or not S then return end

    -- Ensure Director Camera exists in the GM:FM scene
    if not IsValid(session.directorCam) then
        local firstFighter = session.fighters[1]
        local startPos = (firstFighter and firstFighter.origPos or ply:GetPos()) + Vector(-180, -140, 72)
        local startAng = Angle(10, 40, 0)
        session.directorCam = S.SpawnCamera(ply, { pos = startPos, ang = startAng, fov = 68 })
        if IsValid(session.directorCam) then
            local camName = "ProcFight Director Cam"
            session.directorCam.SPeditor_Name = camName
            session.directorCam:SetNW2String("SPeditor_Name", camName)
            session.directorCuts = session.directorCuts or {}
            table.insert(session.directorCuts, {
                simFrame = 0,
                uid      = session.directorCam.SPeditor_UID,
            })
        end
    end

    local cam = session.directorCam
    if not IsValid(cam) then return end

    local now = CurTime()
    local shot = session.directorShot

    -- Rotate shot style every few seconds if no special event shot is active
    if not shot or now >= (shot.untilTime or 0) then
        local living = {}
        for _, f in ipairs(session.fighters) do
            if not f.dead then table.insert(living, f) end
        end

        local modes = { "wide_orbit", "over_shoulder", "low_action" }
        local nextMode = modes[((session.shotCounter or 0) % #modes) + 1]
        session.shotCounter = (session.shotCounter or 0) + 1

        shot = {
            mode      = nextMode,
            untilTime = now + ((session.config.fightStyle == "cinematic") and 3.2 or 4.5),
            attacker  = living[1] or session.fighters[1],
            victim    = living[2] or session.fighters[2] or session.fighters[1],
            fov       = (nextMode == "wide_orbit") and 68 or (nextMode == "low_action" and 58 or 62),
            cutQueued = true,
        }
        session.directorShot = shot
    end

    local f1 = shot.attacker or session.fighters[1]
    local f2 = shot.victim or session.fighters[2] or f1
    local p1 = (f1 and IsValid(f1.sceneEnt) and f1.sceneEnt:GetPos() or f1 and f1.lastPos or Vector(0, 0, 0)) + Vector(0, 0, 46)
    local p2 = (f2 and IsValid(f2.sceneEnt) and f2.sceneEnt:GetPos() or f2 and f2.lastPos or p1) + Vector(0, 0, 46)
    local mid = (p1 + p2) * 0.5
    local dir = (p2 - p1)
    dir.z = 0
    if dir:LengthSqr() < 1 then dir = Vector(1, 0, 0) else dir:Normalize() end
    local right = dir:Angle():Right()

    local targetPos, targetLook, targetFov = mid - right * 160 + Vector(0, 0, 18), mid, shot.fov or 65

    if shot.mode == "killmove_closeup" then
        targetPos  = mid + right * 78 - dir * 32 + Vector(0, 0, -10)
        targetLook = mid + Vector(0, 0, 4)
        targetFov  = 50
    elseif shot.mode == "ko_hero" then
        targetPos  = p1 + right * 68 - dir * 48 + Vector(0, 0, -14)
        targetLook = mid
        targetFov  = 54
    elseif shot.mode == "over_shoulder" then
        targetPos  = p1 - dir * 58 + right * 32 + Vector(0, 0, 14)
        targetLook = p2
        targetFov  = 60
    elseif shot.mode == "low_action" then
        local orbit = math.sin(now * 0.7) * 45
        targetPos  = mid + right * 115 + dir * orbit + Vector(0, 0, -18)
        targetLook = mid + Vector(0, 0, 6)
        targetFov  = 58
    else
        -- wide_orbit framing all living fighters
        local center = Vector(0, 0, 0)
        local count = 0
        local maxSpan = 120
        for _, f in ipairs(session.fighters) do
            local fp = (IsValid(f.sceneEnt) and f.sceneEnt:GetPos() or f.lastPos) + Vector(0, 0, 44)
            center = center + fp
            count = count + 1
        end
        if count > 0 then center = center / count end
        for _, f in ipairs(session.fighters) do
            local fp = (IsValid(f.sceneEnt) and f.sceneEnt:GetPos() or f.lastPos) + Vector(0, 0, 44)
            maxSpan = math.max(maxSpan, center:Distance(fp) * 2.1)
        end
        local orbitAng = Angle(12, (now * 16) % 360, 0)
        targetPos  = center - orbitAng:Forward() * math.Clamp(maxSpan * 1.15, 135, 360) + Vector(0, 0, 22)
        targetLook = center
        targetFov  = 68
    end

    -- Trace camera against walls so it doesn't clip behind geometry
    local tr = util.TraceLine({
        start  = targetLook,
        endpos = targetPos,
        mask   = MASK_SOLID_BRUSHONLY,
    })
    if tr.Hit then
        targetPos = tr.HitPos + tr.HitNormal * 12
    end

    -- Smoothly interpolate camera unless a hard cut was just queued
    if shot.cutQueued or not session.lastCamPos then
        shot.cutQueued = false
        session.lastCamPos = targetPos
        session.lastCamAng = (targetLook - targetPos):Angle()
    else
        session.lastCamPos = LerpVector(0.22, session.lastCamPos, targetPos)
        session.lastCamAng = LerpAngle(0.25, session.lastCamAng, (targetLook - session.lastCamPos):Angle())
    end

    -- Subtle impact camera shake during hit-stop
    local finalPos = session.lastCamPos
    local finalAng = session.lastCamAng
    if session.hitStopUntil and now < session.hitStopUntil then
        finalAng = finalAng + Angle(math.Rand(-2.2, 2.2), math.Rand(-2.2, 2.2), math.Rand(-1.8, 1.8))
    end

    cam:SetPos(finalPos)
    cam:SetAngles(finalAng)
    if cam.SetCameraFOV then cam:SetCameraFOV(targetFov) end
end

-- ============================================================================
-- SAMPLE FRAME & BAKE KEYFRAMES ONTO GM:FM TIMELINE
-- ============================================================================
function PF.SampleTimelineFrame(session, simFrame)
    local S = SPeditor.Server
    local SA_COMP = SPeditor.Component and SPeditor.Component("saeditor")
    local SA = SA_COMP and SA_COMP.SA
    local ply = session.ply
    if not IsValid(ply) or not S or not SA then return end

    local stretch = math.Clamp(tonumber(session.config.bakeTimeStretch) or 1.0, 0.5, 4.0)
    local timelineFrame = session.startFrame + math.Round(simFrame * stretch)
    local kfMode = session.config.keyframeMode or "spline"

    session.maxTimelineFrame = math.max(session.maxTimelineFrame or timelineFrame, timelineFrame)

    -- Sample each fighter & their weapon
    for _, f in ipairs(session.fighters) do
        local rag = f.sceneEnt
        if IsValid(rag) and rag.SPeditor_UID then
            if f.ragdollPhysicsActive then
                S.SnapRigid(rag)
            end
            SA.SetKey(ply, rag, timelineFrame, kfMode)
        end
        if IsValid(f.wepEnt) and f.wepEnt.SPeditor_UID and not f.wepEnt.SPeditor_Attach then
            SA.SetKey(ply, f.wepEnt, timelineFrame, kfMode)
        end
    end

    -- Sample Director Camera
    if IsValid(session.directorCam) and session.directorCam.SPeditor_UID then
        SA.SetKey(ply, session.directorCam, timelineFrame, kfMode)
    end
end

function PF.FinalizeBakeToTimeline(session)
    if not session then return end
    local S = SPeditor.Server
    local SA_COMP = SPeditor.Component and SPeditor.Component("saeditor")
    local SA = SA_COMP and SA_COMP.SA
    local ply = session.ply
    if not IsValid(ply) or not S or not SA then return end

    local a = SA.Anim(ply)
    local stretch = math.Clamp(tonumber(session.config.bakeTimeStretch) or 1.0, 0.5, 4.0)

    -- Freeze all fighter ragdolls cleanly so GM:FM timeline scrubbing controls them
    for _, f in ipairs(session.fighters) do
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
        local rag = f.sceneEnt
        if IsValid(rag) then
            rag.SPeditor_PhysRec = nil
            rag.SPeditor_Guard = nil
            rag:SetNotSolid(false)
            rag:SetNoDraw(false)
            rag:SetCollisionGroup(COLLISION_GROUP_NONE)
            S.Freeze(rag)
        end
        if IsValid(f.wepEnt) then
            S.Freeze(f.wepEnt)
        end
    end

    -- Write recorded sounds onto GM:FM timeline (using SAeditor's clip format)
    if session.config.recordSounds and istable(session.recordedSounds) and #session.recordedSounds > 0 then
        local list = table.Copy(a.sounds or {})
        local maxId = 0
        for _, c in ipairs(list) do maxId = math.max(maxId, c.id or 0) end

        local pitchScale = (session.config.fightStyle == "cinematic") and 0.85 or 1.0
        for _, snd in ipairs(session.recordedSounds) do
            if #list >= (SA.MAX_SOUNDS or 256) then break end
            local fIdx = math.Clamp(session.startFrame + math.Round((snd.simFrame or 0) * stretch), 0, SA.MAX_FRAMES or 7200)
            local rawPath = tostring(snd.path or "")
            local fullPath = string.StartWith(rawPath, "sound/") and rawPath or ("sound/" .. rawPath)
            maxId = maxId + 1
            list[#list + 1] = {
                id    = maxId,
                path  = fullPath,
                f     = fIdx,
                uid   = snd.uid or (session.fighters[1] and session.fighters[1].uid) or 0,
                vol   = snd.volume or 1,
                pitch = math.Clamp(math.Round((snd.pitch or 100) * pitchScale), 50, 200),
                dist  = 600,
            }
        end
        if SA.CleanSounds then
            a.sounds = SA.CleanSounds(list)
        else
            a.sounds = list
        end
    end

    -- Write recorded combat effects (blood impacts, muzzle flashes) onto GM:FM timeline
    if session.config.recordEffects and istable(session.recordedEffects) and isfunction(S.SpawnEffect) then
        local poolByName = {}
        local fps = a.fps or 24
        for i, ef in ipairs(session.recordedEffects) do
            if i > 48 then break end
            local fIdx = math.Clamp(session.startFrame + math.Round((ef.simFrame or 0) * stretch), 1, SA.MAX_FRAMES or 7200)
            local pool = poolByName[ef.effect] or {}
            poolByName[ef.effect] = pool

            local slot
            for _, o in ipairs(pool) do
                if fIdx >= o.prev + 2 then slot = o break end
            end
            if not slot and #pool < 4 then
                local fx = S.SpawnEffect(ply, { src = "lua", name = ef.effect, file = "", pos = ef.pos, ang = ef.ang })
                if IsValid(fx) then
                    local fxLabel = string.format("PF %s #%d", ef.effect, #pool + 1)
                    fx.SPeditor_Name = fxLabel
                    fx:SetNW2String("SPeditor_Name", fxLabel)
                    slot = { fx = fx, prev = -10 }
                    pool[#pool + 1] = slot
                end
            end
            if slot and IsValid(slot.fx) then
                local fx = slot.fx
                fx:SetPos(ef.pos)
                fx:SetAngles(ef.ang)
                if fx.SetFxTime then fx:SetFxTime(0) end
                SA.SetKey(ply, fx, math.max(0, fIdx - 1), "hold")
                if fx.SetFxTime then fx:SetFxTime(1 / fps) end
                SA.SetKey(ply, fx, fIdx, "hold")
                slot.prev = fIdx
            end
        end
        for _, pool in pairs(poolByName) do
            for _, o in ipairs(pool) do
                if IsValid(o.fx) and o.fx.SetFxTime then o.fx:SetFxTime(0) end
            end
        end
    end

    -- Write Director Camera Cuts if enabled
    if session.config.autoDirectorCam and IsValid(session.directorCam) and istable(session.directorCuts) then
        a.cuts = a.cuts or {}
        for _, c in ipairs(session.directorCuts) do
            local fIdx = math.Clamp(session.startFrame + math.Round((c.simFrame or 0) * stretch), 0, SA.MAX_FRAMES or 7200)
            a.cuts[#a.cuts + 1] = {
                f   = fIdx,
                uid = c.uid,
            }
        end
        table.sort(a.cuts, function(x, y) return (x.f or 0) < (y.f or 0) end)
    end

    -- Extend timeline frames if needed and rewind playhead to the start of the fight take
    if (session.maxTimelineFrame or 0) > (a.frames or 0) then
        a.frames = math.Clamp(session.maxTimelineFrame + 15, a.frames or 96, SA.MAX_FRAMES or 7200)
    end

    SA.SendSummary(ply)
    SA.ApplyAll(ply, session.startFrame or 0)
    if S.AttachFollow then S.AttachFollow() end
    if S.Notice then
        S.Notice(ply, string.format("Procedural Fight baked (%d frames)!", (session.maxTimelineFrame or 0) - (session.startFrame or 0)), 2)
    end
end
