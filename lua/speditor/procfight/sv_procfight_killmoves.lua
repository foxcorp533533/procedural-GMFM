-- ============================================================================
-- GM:FM Procedural Fight Scene — Authentic BSMod KillMove Engine
-- Uses BSMod's actual models & sequences from BSMOD_ref:
--   Attacker: models/weapons/c_limbs.mdl
--   Victim:   models/bsmodimations_human.mdl (or models/bsmodimations_hunter.mdl)
--   Entity:   ent_km_model
-- ============================================================================
if CLIENT then return end

GMFM_ProcFight = GMFM_ProcFight or {}
local PF = GMFM_ProcFight

-- Legacy ID mapping so any old presets or external calls resolve to real BSMod sequences
PF.KillMoveLegacyMap = {
    ["neck_snap"]         = "killmove_back_1",
    ["takedown_slam"]     = "killmove_front_2",
    ["haymaker_uppercut"] = "killmove_front_2",
    ["combo_flurry"]      = "killmove_front_1",
    ["spartan_kick"]      = "killmove_front_1",
    ["spine_breaker"]     = "killmove_left_1",
    ["curb_stomp"]        = "killmove_right_1",
    ["disarm_counter"]    = "killmove_left_1",
}

-- ============================================================================
-- EXACT BSMOD SOUND & BLOOD EFFECT SCHEDULES (From BSMOD_ref bsmod_killmove.lua)
-- ============================================================================
local function BuildBSModKillMoveEvents(seqName)
    if seqName == "killmove_front_1" then
        return {
            { t = 0.15, bone = "ValveBiped.Bip01_Spine",   snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true },
            { t = 0.40, bone = "ValveBiped.Bip01_Head1",   snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true },
            { t = 0.75, bone = "ValveBiped.Bip01_Spine2",  snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true, climax = true },
        }
    elseif seqName == "killmove_front_2" then
        return {
            { t = 0.25, bone = "ValveBiped.Bip01_L_Calf",  snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = false },
            { t = 0.65, bone = "ValveBiped.Bip01_Head1",   snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true },
            { t = 1.00, bone = "ValveBiped.Bip01_Head1",   snd = "player/killmove/km_bonebreak" .. math.random(1, 2) .. ".wav", snd2 = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true, climax = true },
        }
    elseif seqName == "killmove_front_air_1" then
        return {
            { t = 0.08, bone = "ValveBiped.Bip01_Spine2",  snd = "player/kick/foot_kickbody.wav", blood = true },
            { t = 0.70, bone = "ValveBiped.Bip01_Head1",   snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true, climax = true },
        }
    elseif seqName == "killmove_left_1" then
        return {
            { t = 0.10, bone = "ValveBiped.Bip01_L_Forearm", snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = false },
            { t = 0.25, bone = "ValveBiped.Bip01_L_Forearm", snd = "player/killmove/km_bonebreak" .. math.random(1, 3) .. ".wav", blood = false },
            { t = 0.75, bone = "ValveBiped.Bip01_Head1",     snd = "player/killmove/km_punch1.wav", snd2 = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true, climax = true },
        }
    elseif seqName == "killmove_right_1" then
        return {
            { t = 0.30, bone = "ValveBiped.Bip01_Spine1",  snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true },
            { t = 0.90, bone = "ValveBiped.Bip01_Head1",   snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true, climax = true },
        }
    elseif seqName == "killmove_back_1" then
        return {
            { t = 0.30, bone = "ValveBiped.Bip01_R_Calf",  snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = false },
            { t = 0.85, bone = "ValveBiped.Bip01_Head1",   snd = "player/killmove/km_bonebreak" .. math.random(1, 3) .. ".wav", blood = false, climax = true },
        }
    elseif seqName == "killmove_hunter_front_1" then
        local evs = {
            { t = 0.10, bone = "MiniStrider.body_joint", snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true },
        }
        for i = 1, 7 do
            table.insert(evs, {
                t      = 0.80 + (i * 0.14),
                bone   = "MiniStrider.body_joint",
                snd    = "player/killmove/km_gorehit" .. math.random(1, 2) .. ".wav",
                snd2   = (i == 7) and "player/killmove/km_hit" .. math.random(1, 5) .. ".wav" or nil,
                blood  = true,
                climax = (i == 7),
            })
        end
        return evs
    end

    return {
        { t = 0.50, bone = "ValveBiped.Bip01_Head1", snd = "player/killmove/km_hit" .. math.random(1, 5) .. ".wav", blood = true, climax = true },
    }
end

-- ============================================================================
-- COMPUTE EXACT BSMOD POSITIONS & ANGLES (From BSMOD_ref bsmod_killmove.lua L612-677)
-- ============================================================================
local function ComputeBSModAlignment(seqName, attOrigin, vicOrigin)
    local approachDir = (vicOrigin - attOrigin)
    approachDir.z = 0
    if approachDir:LengthSqr() < 1 then
        approachDir = Vector(1, 0, 0)
    else
        approachDir:Normalize()
    end

    local vicPos = Vector(vicOrigin.x, vicOrigin.y, attOrigin.z)
    local vicAng = (-approachDir):Angle()
    local attPos = attOrigin
    local attAng = approachDir:Angle()

    if seqName == "killmove_front_1" or seqName == "killmove_hunter_front_1" then
        vicAng = (-approachDir):Angle()
        attPos = vicPos + (vicAng:Forward() * 31.5)
        attAng = (vicPos - attPos):Angle()
    elseif seqName == "killmove_front_2" then
        vicAng = (-approachDir):Angle()
        attPos = vicPos + (vicAng:Forward() * 29.0)
        attAng = (vicPos - attPos):Angle()
    elseif seqName == "killmove_front_air_1" then
        vicAng = (-approachDir):Angle()
        attPos = vicPos + (vicAng:Forward() * 39.0)
        attAng = (vicPos - attPos):Angle()
    elseif seqName == "killmove_left_1" then
        -- Attacker is on the victim's left side (-vicAng:Right() * 31.5)
        vicAng = Angle(0, approachDir:Angle().y - 90, 0)
        attPos = vicPos + (-vicAng:Right() * 31.5)
        attAng = (vicPos - attPos):Angle()
    elseif seqName == "killmove_right_1" then
        -- Attacker is on the victim's right side (vicAng:Right() * 95 + vicAng:Forward() * 10)
        vicAng = Angle(0, approachDir:Angle().y + 90, 0)
        attPos = vicPos + (vicAng:Right() * 95.0) + (vicAng:Forward() * 10.0)
        attAng = (-vicAng:Right()):Angle()
    elseif seqName == "killmove_back_1" then
        -- Attacker is behind the victim (-vicAng:Forward() * 30)
        vicAng = approachDir:Angle()
        attPos = vicPos + (-vicAng:Forward() * 30.0)
        attAng = (vicPos - attPos):Angle()
    end

    attAng.p = 0
    attAng.r = 0
    vicAng.p = 0
    vicAng.r = 0

    return attPos, attAng, vicPos, vicAng, approachDir
end

-- ============================================================================
-- SPAWN HIDDEN BSMOD ent_km_model FOR SERVER-SIDE SKELETON EVALUATION
-- ============================================================================
local function SpawnBSModAnimEnt(mdl, pos, ang, seqName, ownerEnt, session)
    local ent = ents.Create("ent_km_model")
    if not IsValid(ent) then
        ent = ents.Create("prop_dynamic")
    end
    if not IsValid(ent) then return nil, 1.5 end

    ent.NoOwnerCheck = true
    ent.GMFM_PF_Session = session
    if IsValid(ownerEnt) then
        ent:SetOwner(ownerEnt)
    end

    ent:SetModel(mdl)
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:Activate()

    -- Keep server bone evaluation active (never EF_NODRAW!) while hiding the helper mesh
    ent:SetRenderMode(RENDERMODE_TRANSALPHA)
    ent:SetColor(Color(255, 255, 255, 0))
    ent:DrawShadow(false)
    ent:SetNotSolid(true)
    ent:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    if ent.SetIK then ent:SetIK(false) end

    local seqId = ent:LookupSequence(seqName)
    local seqDur = 1.5
    if seqId and seqId >= 0 then
        ent:ResetSequence(seqId)
        ent:ResetSequenceInfo()
        ent:SetCycle(0)
        ent:SetPlaybackRate(1)
        local d = ent:SequenceDuration(seqId)
        if d and d > 0 then seqDur = d end
    end

    ent:GetBonePosition(0)
    if ent.SetupBones then ent:SetupBones() end

    return ent, seqDur
end

-- ============================================================================
-- TRIGGER & STEP BSMOD KILLMOVES DURING SESSION
-- ============================================================================
function PF.CanTriggerKillMove(session, attEntry, vicEntry)
    if not session or not attEntry or not vicEntry then return false end
    if attEntry == vicEntry then return false end
    if attEntry.dead or vicEntry.dead then return false end
    if attEntry.inKillMove or vicEntry.inKillMove then return false end
    if session.activeKillMove and CurTime() < (session.activeKillMove.endTime or 0) then return false end
    if CurTime() < (session.nextKillMoveAllowed or 0) then return false end
    return true
end

function PF.StartKillMove(session, attEntry, vicEntry, forcedKmId, forceLethal)
    if not PF.CanTriggerKillMove(session, attEntry, vicEntry) then return false end

    if forcedKmId and PF.KillMoveLegacyMap[forcedKmId] then
        forcedKmId = PF.KillMoveLegacyMap[forcedKmId]
    end

    local kmDef
    if forcedKmId then
        for _, k in ipairs(PF.KillMoves) do
            if k.id == forcedKmId or k.seq == forcedKmId then
                kmDef = k
                break
            end
        end
    end

    -- Check if victim is a Hunter model
    local vicMdl = IsValid(vicEntry.sceneEnt) and string.lower(vicEntry.sceneEnt:GetModel() or "") or ""
    if not kmDef and string.find(vicMdl, "hunter", 1, true) then
        kmDef = {
            id           = "killmove_hunter_front_1",
            seq          = "killmove_hunter_front_1",
            name         = "BSMod Hunter Takedown",
            attModel     = "models/weapons/c_limbs.mdl",
            vicModel     = "models/bsmodimations_hunter.mdl",
            duration     = 2.73,
            targetKMTime = 2.65,
            plyKMTime    = 2.73,
            lethal       = true,
        }
    end

    if not kmDef then
        kmDef = PF.KillMoves[math.random(#PF.KillMoves)]
    end

    local seqName = kmDef.seq or kmDef.id or "killmove_front_1"
    local attModel = kmDef.attModel or "models/weapons/c_limbs.mdl"
    local vicModel = kmDef.vicModel or "models/bsmodimations_human.mdl"

    if not util.IsValidModel(attModel) or not util.IsValidModel(vicModel) then
        return false
    end

    local isLethal = (forceLethal ~= nil) and forceLethal or (kmDef.lethal ~= false)
    if not session.config.midFightKillMove then
        isLethal = true
    end

    local attNpc = attEntry.npc
    local vicNpc = vicEntry.npc
    local attOrigin = IsValid(attNpc) and attNpc:GetPos() or attEntry.lastPos or Vector(0, 0, 0)
    local vicOrigin = IsValid(vicNpc) and vicNpc:GetPos() or vicEntry.lastPos or (attOrigin + Vector(32, 0, 0))

    local attPos, attAng, vicPos, vicAng, dir = ComputeBSModAlignment(seqName, attOrigin, vicOrigin)

    -- Freeze both AI NPCs in place during the BSMod KillMove sequence
    if IsValid(attNpc) then
        attNpc:SetPos(attPos)
        attNpc:SetAngles(attAng)
        attNpc:SetLocalVelocity(vector_origin)
        if attNpc.ClearSchedule then attNpc:ClearSchedule() end
        if attNpc.SetSchedule then attNpc:SetSchedule(SCHED_NPC_FREEZE) end
    end

    if IsValid(vicNpc) then
        vicNpc:SetPos(vicPos)
        vicNpc:SetAngles(vicAng)
        vicNpc:SetLocalVelocity(vector_origin)
        if vicNpc.ClearSchedule then vicNpc:ClearSchedule() end
        if vicNpc.SetSchedule then vicNpc:SetSchedule(SCHED_NPC_FREEZE) end
    end

    -- Clean up any previous kmAnim entities just in case
    if IsValid(attEntry.kmAnim) then SafeRemoveEntity(attEntry.kmAnim) end
    if IsValid(vicEntry.kmAnim) then SafeRemoveEntity(vicEntry.kmAnim) end

    -- Spawn BSMod's attacker & victim animation rigs
    local attKmAnim, attSeqDur = SpawnBSModAnimEnt(attModel, attPos, attAng, seqName, attNpc or attEntry.sceneEnt, session)
    local vicKmAnim, vicSeqDur = SpawnBSModAnimEnt(vicModel, vicPos, vicAng, seqName, vicNpc or vicEntry.sceneEnt, session)
    if not IsValid(attKmAnim) or not IsValid(vicKmAnim) then
        if IsValid(attKmAnim) then SafeRemoveEntity(attKmAnim) end
        if IsValid(vicKmAnim) then SafeRemoveEntity(vicKmAnim) end
        return false
    end

    local duration     = math.max(attSeqDur or 1.4, kmDef.duration or 1.4)
    local targetKMTime = kmDef.targetKMTime or math.min(vicSeqDur or duration, duration - 0.08)
    if seqName == "killmove_front_1" then
        targetKMTime = 1.15
    end

    local now = CurTime()

    if kmDef.soundSetup and IsValid(attNpc) then
        attNpc:EmitSound(kmDef.soundSetup, 78, math.random(96, 104), 0.9)
    end

    -- Fire BSMod custom killmove hook if BSMod addon is also present
    if PF.IsBSModInstalled() then
        hook.Run("CustomKillMoves", attNpc, vicNpc, Angle(0, attAng.y, 0))
    end

    local kmState = {
        def          = kmDef,
        seqName      = seqName,
        attacker     = attEntry,
        victim       = vicEntry,
        attKmAnim    = attKmAnim,
        vicKmAnim    = vicKmAnim,
        attSeqDur    = attSeqDur,
        vicSeqDur    = vicSeqDur,
        startTime    = now,
        endTime      = now + duration,
        duration     = duration,
        targetKMTime = targetKMTime,
        victimFreed  = false,
        lethal       = isLethal,
        attPos       = attPos,
        attAng       = attAng,
        vicPos       = vicPos,
        vicAng       = vicAng,
        dir          = dir,
        events       = BuildBSModKillMoveEvents(seqName),
    }

    attEntry.kmAnim        = attKmAnim
    vicEntry.kmAnim        = vicKmAnim
    attEntry.inKillMove    = kmState
    vicEntry.inKillMove    = kmState
    attEntry.combatOverlay = nil
    vicEntry.combatOverlay = nil
    attEntry.poseOverlay   = nil
    vicEntry.poseOverlay   = nil

    session.activeKillMove      = kmState
    session.nextKillMoveAllowed = now + duration + 1.0

    if PF.OnDirectorEvent then
        PF.OnDirectorEvent(session, "killmove_start", kmState)
    end
    if PF.BroadcastEvent then
        PF.BroadcastEvent(session, "killmove", {
            name     = kmDef.name,
            id       = kmDef.id,
            attacker = attEntry.name or "Fighter 1",
            victim   = vicEntry.name or "Fighter 2",
            duration = duration,
        })
    end

    return true
end

function PF.StepKillMove(session)
    local km = session and session.activeKillMove
    if not km then return end

    local now     = CurTime()
    local elapsed = math.max(0, now - km.startTime)

    local attEntry  = km.attacker
    local vicEntry  = km.victim
    local attNpc    = attEntry and attEntry.npc
    local vicNpc    = vicEntry and vicEntry.npc
    local attKmAnim = km.attKmAnim
    local vicKmAnim = km.vicKmAnim

    -- Keep AI proxy NPCs frozen at the BSMod alignment transform
    if IsValid(attNpc) then
        attNpc:SetPos(km.attPos)
        attNpc:SetAngles(km.attAng)
        attNpc:SetLocalVelocity(vector_origin)
    end
    if IsValid(vicNpc) and not vicEntry.dead then
        vicNpc:SetPos(km.vicPos)
        vicNpc:SetAngles(km.vicAng)
        vicNpc:SetLocalVelocity(vector_origin)
    end

    -- Explicitly set animation cycle on both BSMod ent_km_model rigs for 100% frame-accurate bone sync
    if IsValid(attKmAnim) then
        local attCycle = math.Clamp(elapsed / math.max(0.1, km.attSeqDur or km.duration), 0, 1)
        attKmAnim:SetPos(km.attPos)
        attKmAnim:SetAngles(km.attAng)
        attKmAnim:SetCycle(attCycle)
        attKmAnim:GetBonePosition(0)
        if attKmAnim.SetupBones then attKmAnim:SetupBones() end
    end

    if IsValid(vicKmAnim) and not km.victimFreed then
        local vicCycle = math.Clamp(elapsed / math.max(0.1, km.vicSeqDur or km.duration), 0, 1)
        vicKmAnim:SetPos(km.vicPos)
        vicKmAnim:SetAngles(km.vicAng)
        vicKmAnim:SetCycle(vicCycle)
        vicKmAnim:GetBonePosition(0)
        if vicKmAnim.SetupBones then vicKmAnim:SetupBones() end
    end

    -- Process BSMod DoKMEffects scheduled sounds & blood impacts
    if istable(km.events) then
        for _, ev in ipairs(km.events) do
            if not ev.done and elapsed >= ev.t then
                ev.done = true

                local bPos = km.vicPos + Vector(0, 0, 48)
                local bAng = (-km.dir):Angle()
                if IsValid(vicKmAnim) and ev.bone then
                    local bIdx = vicKmAnim:LookupBone(ev.bone)
                    if bIdx and bIdx >= 0 then
                        local p, a = vicKmAnim:GetBonePosition(bIdx)
                        if p then bPos = p end
                        if a then bAng = a end
                    end
                end

                local sndEmitter = IsValid(vicNpc) and vicNpc or (IsValid(attNpc) and attNpc or vicKmAnim)
                if IsValid(sndEmitter) then
                    if ev.snd then
                        sndEmitter:EmitSound(ev.snd, 85, math.random(96, 104), 1.0, CHAN_AUTO)
                    end
                    if ev.snd2 then
                        sndEmitter:EmitSound(ev.snd2, 85, math.random(96, 104), 1.0, CHAN_AUTO)
                    end
                end

                if ev.blood then
                    local ed = EffectData()
                    ed:SetOrigin(bPos)
                    ed:SetNormal(-km.dir)
                    ed:SetScale(1.2)
                    util.Effect("BloodImpact", ed, true, true)

                    if PF.RecordCombatEffect then
                        PF.RecordCombatEffect(session, "BloodImpact", bPos, bAng)
                    end
                end

                if ev.climax and session.config.fightStyle == "cinematic" and (session.config.hitStopDuration or 0) > 0 then
                    PF.TriggerHitStop(session, math.max(0.10, session.config.hitStopDuration * 1.25))
                end
            end
        end
    end

    -- When victim reaches targetKMTime (e.g. 1.15s on killmove_front_1 after Spartan kick), release victim to ragdoll!
    if not km.victimFreed and elapsed >= (km.targetKMTime or km.duration) then
        km.victimFreed = true
        if km.lethal then
            PF.KillFighterFromKillMove(session, attEntry, vicEntry, km)
        elseif vicEntry then
            vicEntry.hp = math.max(10, (vicEntry.hp or 100) - 35)
            if IsValid(vicNpc) then
                vicNpc:SetHealth(vicEntry.hp)
            end
        end
    end

    -- Finish KillMove when attacker animation finishes
    if elapsed >= km.duration then
        -- Update attacker's world position to where c_limbs.mdl finished (matching BSMod ent_km_model L27-32)
        if IsValid(attKmAnim) and attEntry then
            local newOrigin = nil
            local pelvIdx = attKmAnim:LookupBone("ValveBiped.Bip01_Pelvis")
            if pelvIdx and pelvIdx >= 0 then
                local pPos = attKmAnim:GetBonePosition(pelvIdx)
                if pPos then
                    newOrigin = Vector(pPos.x, pPos.y, km.attPos.z)
                end
            end
            local eyeAtt = attKmAnim:LookupAttachment("eyes")
            if eyeAtt and eyeAtt > 0 then
                local headAtt = attKmAnim:GetAttachment(eyeAtt)
                if headAtt and headAtt.Pos then
                    newOrigin = Vector(headAtt.Pos.x, headAtt.Pos.y, km.attPos.z)
                end
            end
            if newOrigin then
                attEntry.smoothPos = newOrigin
                attEntry.lastPos   = newOrigin
                if IsValid(attNpc) then
                    attNpc:SetPos(newOrigin)
                end
            end
        end

        if IsValid(attKmAnim) then SafeRemoveEntity(attKmAnim) end
        if IsValid(vicKmAnim) then SafeRemoveEntity(vicKmAnim) end

        if attEntry then
            attEntry.kmAnim = nil
            attEntry.inKillMove = nil
            if IsValid(attNpc) and attNpc.SetSchedule then
                attNpc:SetSchedule(SCHED_ALERT_STAND)
            end
        end

        if vicEntry then
            vicEntry.kmAnim = nil
            vicEntry.inKillMove = nil
            if not vicEntry.dead and IsValid(vicNpc) and vicNpc.SetSchedule then
                vicNpc:SetSchedule(SCHED_ALERT_STAND)
            end
        end

        session.activeKillMove = nil
    end
end

-- ============================================================================
-- TRANSITION VICTIM FROM BSMOD KILLMOVE TO RAGDOLL (BSMOD_ref L1222-1250)
-- ============================================================================
function PF.KillFighterFromKillMove(session, attEntry, vicEntry, km)
    if not vicEntry or vicEntry.dead then return end

    local rag = vicEntry.sceneEnt
    local vicNpc = vicEntry.npc
    local vicKmAnim = km and km.vicKmAnim or vicEntry.kmAnim

    -- Snap the GM:FM ragdoll to the exact current BSMod victim bone positions BEFORE releasing physics
    if IsValid(rag) and rag:GetClass() == "prop_ragdoll" and PF.SyncFighterToRagdoll then
        PF.SyncFighterToRagdoll(session, vicEntry, true)
    end

    vicEntry.dead = true
    vicEntry.deathTime = CurTime()
    vicEntry.killedBy = attEntry
    vicEntry.kmAnim = nil
    vicEntry.poseOverlay = nil
    vicEntry.combatOverlay = nil

    if IsValid(rag) and rag:GetClass() == "prop_ragdoll" then
        vicEntry.ragdollPhysicsActive = true
        rag:SetNotSolid(false)
        rag:SetNoDraw(false)
        rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        local seqName = km and km.seqName or "killmove_front_1"
        local vicFwd  = (km and km.vicAng) and km.vicAng:Forward() or (-km.dir)

        for i = 0, rag:GetPhysicsObjectCount() - 1 do
            local phys = rag:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                phys:EnableMotion(true)
                phys:Wake()

                local boneIdx  = rag:TranslatePhysBoneToBone(i)
                local boneName = boneIdx and rag:GetBoneName(boneIdx) or ""

                -- Inherit bone velocity from the BSMod animation plus BSModKMRagdoll impulse
                local vel = vicEntry.lastBoneVel and vicEntry.lastBoneVel[i] or Vector(0, 0, 0)
                if vel:LengthSqr() < 400 then
                    vel = (-vicFwd) * 90 + Vector(0, 0, -30)
                end

                if seqName == "killmove_front_1" and boneName == "ValveBiped.Bip01_Spine2" then
                    -- Exact BSMod kick launch from bsmod_killmove.lua line 1018
                    vel = (-vicFwd) * 240 + Vector(0, 0, 45)
                elseif seqName == "killmove_front_air_1" then
                    vel = (-vicFwd) * 260 + Vector(0, 0, 60)
                elseif seqName == "killmove_front_2" then
                    vel = Vector(0, 0, -160)
                end

                phys:SetVelocity(vel)
            end
        end
    end

    if IsValid(vicKmAnim) then
        SafeRemoveEntity(vicKmAnim)
    end

    if IsValid(vicNpc) then
        SafeRemoveEntity(vicNpc)
        vicEntry.npc = nil
    end

    if PF.OnDirectorEvent then
        PF.OnDirectorEvent(session, "fighter_killed", { attacker = attEntry, victim = vicEntry, killMove = km })
    end
    if PF.BroadcastEvent then
        PF.BroadcastEvent(session, "ko", {
            attacker = attEntry and attEntry.name or "Fighter",
            victim   = vicEntry.name or "Fighter",
        })
    end
end
