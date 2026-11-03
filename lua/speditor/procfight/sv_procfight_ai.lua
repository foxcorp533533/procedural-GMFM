-- ============================================================================
-- GM:FM Procedural Fight Scene — High-Intensity AI Combat Brain & Choreographer
--   * GUNFIGHT MODE: Intense shootouts using 100% Half-Life 2 default NPC gun
--     animations (ACT_IDLE_SMG1, ACT_RANGE_ATTACK_SMG1, ACT_RELOAD_SMG1, etc.)
--   * MELEE MODE: Fast, aggressive BSMod combos (punches, blocks, kicks &
--     KillMoves) + EXTRA "BSMod Attack Spam" (non-stop Punch & Kick barrage!)
-- ============================================================================
if CLIENT then return end

GMFM_ProcFight = GMFM_ProcFight or {}
local PF = GMFM_ProcFight

-- ============================================================================
-- WEAPON STATS FOR HIGH-INTENSITY GUNFIGHT & MELEE
-- ============================================================================
PF.WeaponProfiles = {
    ["weapon_smg1"] = {
        model      = "models/weapons/w_smg1.mdl",
        sound      = "Weapon_SMG1.NPC_Single",
        reloadSnd  = "Weapon_SMG1.NPC_Reload",
        dmg        = 7,
        burstMin   = 5,
        burstMax   = 10,
        fireRate   = 0.075,
        cooldown   = 0.32,
        clipSize   = 45,
        spread     = 0.042,
        tracer     = "Tracer",
        muzzle     = "MuzzleEffect",
        shell      = "ShellEject",
        shootAct   = ACT_GESTURE_RANGE_ATTACK_SMG1,
        reloadAct  = ACT_RELOAD_SMG1,
    },
    ["weapon_ar2"] = {
        model      = "models/weapons/w_irifle.mdl",
        sound      = "Weapon_AR2.NPC_Single",
        reloadSnd  = "Weapon_AR2.NPC_Reload",
        dmg        = 10,
        burstMin   = 4,
        burstMax   = 8,
        fireRate   = 0.09,
        cooldown   = 0.35,
        clipSize   = 30,
        spread     = 0.032,
        tracer     = "AR2Tracer",
        muzzle     = "MuzzleEffect",
        shell      = "RifleShellEject",
        shootAct   = ACT_GESTURE_RANGE_ATTACK_AR2,
        reloadAct  = ACT_RELOAD_SMG1,
    },
    ["weapon_shotgun"] = {
        model      = "models/weapons/w_shotgun.mdl",
        sound      = "Weapon_Shotgun.NPC_Single",
        reloadSnd  = "Weapon_Shotgun.NPC_Reload",
        dmg        = 6,
        pellets    = 8,
        burstMin   = 2,
        burstMax   = 3,
        fireRate   = 0.42,
        cooldown   = 0.55,
        clipSize   = 8,
        spread     = 0.08,
        tracer     = "Tracer",
        muzzle     = "MuzzleEffect",
        shell      = "ShotgunShellEject",
        shootAct   = ACT_GESTURE_RANGE_ATTACK_SHOTGUN,
        reloadAct  = ACT_RELOAD_SHOTGUN,
    },
    ["weapon_pistol"] = {
        model      = "models/weapons/w_pistol.mdl",
        sound      = "Weapon_Pistol.NPC_Single",
        reloadSnd  = "Weapon_Pistol.NPC_Reload",
        dmg        = 9,
        burstMin   = 3,
        burstMax   = 6,
        fireRate   = 0.14,
        cooldown   = 0.32,
        clipSize   = 18,
        spread     = 0.028,
        tracer     = "Tracer",
        muzzle     = "MuzzleEffect",
        shell      = "ShellEject",
        shootAct   = ACT_GESTURE_RANGE_ATTACK_PISTOL,
        reloadAct  = ACT_RELOAD_PISTOL,
    },
    ["weapon_357"] = {
        model      = "models/weapons/w_357.mdl",
        sound      = "Weapon_357.Single",
        reloadSnd  = "Weapon_357.Reload",
        dmg        = 22,
        burstMin   = 2,
        burstMax   = 3,
        fireRate   = 0.36,
        cooldown   = 0.52,
        clipSize   = 6,
        spread     = 0.018,
        tracer     = "Tracer",
        muzzle     = "MuzzleEffect",
        shootAct   = ACT_GESTURE_RANGE_ATTACK_PISTOL,
        reloadAct  = ACT_RELOAD_PISTOL,
    },
    ["weapon_crossbow"] = {
        model      = "models/weapons/w_crossbow.mdl",
        sound      = "Weapon_Crossbow.Single",
        reloadSnd  = "Weapon_Crossbow.BoltElectrify",
        dmg        = 34,
        burstMin   = 1,
        burstMax   = 1,
        fireRate   = 0.85,
        cooldown   = 0.90,
        clipSize   = 5,
        spread     = 0.012,
        tracer     = "Tracer",
        muzzle     = "MuzzleEffect",
        shootAct   = ACT_GESTURE_RANGE_ATTACK_SMG1,
        reloadAct  = ACT_RELOAD_SMG1,
    },
    ["weapon_annabelle"] = {
        model      = "models/weapons/w_annabelle.mdl",
        sound      = "Weapon_Shotgun.NPC_Single",
        reloadSnd  = "Weapon_Shotgun.NPC_Reload",
        dmg        = 18,
        burstMin   = 2,
        burstMax   = 2,
        fireRate   = 0.45,
        cooldown   = 0.60,
        clipSize   = 4,
        spread     = 0.022,
        tracer     = "Tracer",
        muzzle     = "MuzzleEffect",
        shootAct   = ACT_GESTURE_RANGE_ATTACK_SHOTGUN,
        reloadAct  = ACT_RELOAD_SHOTGUN,
    },
    ["weapon_crowbar"] = {
        model      = "models/weapons/w_crowbar.mdl",
        isMelee    = true,
        dmg        = 16,
    },
    ["weapon_stunstick"] = {
        model      = "models/weapons/w_stunbaton.mdl",
        isMelee    = true,
        dmg        = 15,
    },
}

-- ============================================================================
-- BSMOD MELEE ATTACK DEFINITIONS (From BSMOD_ref weapon_bsmod_punch.lua & bsmod_kick.lua)
-- ============================================================================
PF.BSModAttacks = {
    {
        id       = "bsmod_punch_left",
        name     = "BSMod Left Hook",
        gesture  = "range_fists_l",
        duration = 0.24,
        hitDelay = 0.09,
        dmg      = 10,
        knock    = 65,
        isKick   = false,
        isLeft   = true,
    },
    {
        id       = "bsmod_punch_right",
        name     = "BSMod Right Cross",
        gesture  = "range_fists_r",
        duration = 0.24,
        hitDelay = 0.09,
        dmg      = 11,
        knock    = 75,
        isKick   = false,
        isLeft   = false,
    },
    {
        id       = "bsmod_kick",
        name     = "BSMod Heavy Kick",
        gesture  = "range_fists_r",
        duration = 0.34,
        hitDelay = 0.13,
        dmg      = 16,
        knock    = 185,
        isKick   = true,
    },
}

-- ============================================================================
-- MODEL HELPERS FOR HL2 GUN ANIMATIONS & BSMOD MELEE RIGS
-- ============================================================================
local function IsFemaleModel(mdl)
    mdl = string.lower(tostring(mdl or ""))
    if string.find(mdl, "female", 1, true)
        or string.find(mdl, "alyx", 1, true)
        or string.find(mdl, "mossman", 1, true) then
        return true
    end
    return false
end

local function ChooseHL2GunNPCModel(mdl, npcClass)
    local low = string.lower(tostring(mdl or ""))
    local lacksNpcAnims = string.StartWith(low, "models/player/")
        or string.find(low, "gman", 1, true)
        or string.find(low, "breen", 1, true)
        or string.find(low, "kleiner", 1, true)
        or string.find(low, "eli", 1, true)
        or string.find(low, "mossman", 1, true)
        or string.find(low, "odessa", 1, true)
        or string.find(low, "magnusson", 1, true)

    if not lacksNpcAnims and util.IsValidModel(mdl) then
        return mdl
    end

    if npcClass == "npc_combine_s" then
        return "models/combine_soldier.mdl"
    elseif npcClass == "npc_metropolice" then
        return "models/police.mdl"
    elseif IsFemaleModel(mdl) then
        return "models/humans/group03/female_01.mdl"
    end
    return "models/humans/group03/male_07.mdl"
end

local function SpawnBSModMeleeRig(mdl, pos, ang, session, ownerEnt)
    local rigMdl = IsFemaleModel(mdl) and "models/player/alyx.mdl" or "models/player/kleiner.mdl"
    if not util.IsValidModel(rigMdl) then
        rigMdl = "models/player/kleiner.mdl"
    end

    local rig = ents.Create("ent_km_model")
    if not IsValid(rig) then
        rig = ents.Create("prop_dynamic")
    end
    if not IsValid(rig) then return nil end

    rig.NoOwnerCheck = true
    rig.GMFM_PF_Session = session
    if IsValid(ownerEnt) then
        rig:SetOwner(ownerEnt)
    end

    rig:SetModel(rigMdl)
    rig:SetPos(pos)
    rig:SetAngles(ang)
    rig:Spawn()
    rig:Activate()

    rig:SetRenderMode(RENDERMODE_TRANSALPHA)
    rig:SetColor(Color(255, 255, 255, 0))
    rig:DrawShadow(false)
    rig:SetNotSolid(true)
    rig:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    if rig.SetIK then rig:SetIK(false) end

    local idleSeq = rig:LookupSequence("fist_idle_01")
    if idleSeq and idleSeq >= 0 then
        rig:ResetSequence(idleSeq)
        rig:ResetSequenceInfo()
        rig:SetCycle(0)
        rig:SetPlaybackRate(1)
        rig.curBaseSeq = idleSeq
        rig.curSeqDur  = math.max(0.2, rig:SequenceDuration(idleSeq) or 1.0)
    end

    rig:GetBonePosition(0)
    if rig.SetupBones then rig:SetupBones() end

    return rig
end

-- Smoothly update & advance the rig's base sequence without resetting cycle on minor speed changes
local function StepRigBaseLocomotion(rig, seqName, dt, rate, moveX, moveY)
    if not IsValid(rig) then return end
    local seqId = rig:LookupSequence(seqName)
    if not seqId or seqId < 0 then
        seqId = rig:LookupSequence("fist_idle_01")
    end
    if not seqId or seqId < 0 then return end

    if rig.curBaseSeq ~= seqId then
        rig.curBaseSeq = seqId
        rig.curSeqDur  = math.max(0.2, rig:SequenceDuration(seqId) or 1.0)
        rig:SetSequence(seqId)
    end

    rate = rate or 1.0
    rig:SetPlaybackRate(rate)

    if rig.SetPoseParameter then
        rig:SetPoseParameter("move_x", moveX or 0)
        rig:SetPoseParameter("move_y", moveY or 0)
    end

    local nextCycle = ((rig:GetCycle() or 0) + (dt * rate) / (rig.curSeqDur or 1.0)) % 1.0
    rig:SetCycle(nextCycle)
end

local function StartRigGestureLayer(rig, seqName, rate)
    if not IsValid(rig) then return nil end
    local seqId = rig:LookupSequence(seqName)
    if not seqId or seqId < 0 then return nil end

    if rig.AddGestureSequence then
        local layer = rig:AddGestureSequence(seqId, false)
        if layer and layer >= 0 then
            if rig.SetLayerWeight then rig:SetLayerWeight(layer, 1.0) end
            if rig.SetLayerPlaybackRate then rig:SetLayerPlaybackRate(layer, rate or 1.0) end
            if rig.SetLayerCycle then rig:SetLayerCycle(layer, 0.0) end
            return layer
        end
    end
    return nil
end

-- Exact BSMod kick leg manipulation + upper-body punch snap on meleeAnimRig
local BSMOD_KICK_BONES = {
    ["ValveBiped.Bip01_Pelvis"]  = Angle(0, 0, 14.0),
    ["ValveBiped.Bip01_R_Thigh"] = Angle(0, -56.0, 0),
    ["ValveBiped.Bip01_R_Calf"]  = Angle(0, -45.0, 0),
    ["ValveBiped.Bip01_R_Foot"]  = Angle(0, 28.0, 0),
}

local function UpdateRigCombatBoneDynamics(rig, kickWeight, punchFrac, isLeftPunch)
    if not IsValid(rig) or not rig.ManipulateBoneAngles then return end
    kickWeight = math.Clamp(kickWeight or 0, 0, 1)

    -- 1. BSMod Kick Leg Dynamics (from BSMOD_ref/lua/autorun/bsmod_kick.lua)
    if kickWeight > 0.001 or rig.hasKickManip then
        for boneName, targetAng in pairs(BSMOD_KICK_BONES) do
            local b = rig:LookupBone(boneName)
            if b and b >= 0 then
                if kickWeight <= 0.001 then
                    rig:ManipulateBoneAngles(b, angle_zero)
                else
                    local boneW = kickWeight
                    if boneName == "ValveBiped.Bip01_R_Calf" then
                        boneW = kickWeight * (1.0 - 0.85 * kickWeight)
                    end
                    rig:ManipulateBoneAngles(b, Angle(targetAng.p * boneW, targetAng.y * boneW, targetAng.r * boneW))
                end
            end
        end
        rig.hasKickManip = (kickWeight > 0.001)
    end

    -- 2. Torso & Shoulder Snap on Punches so BSMod punches look explosive & weighty
    local spineBone = rig:LookupBone("ValveBiped.Bip01_Spine2")
    if spineBone and spineBone >= 0 then
        if punchFrac and punchFrac > 0 and punchFrac < 1 then
            local snap = math.sin(punchFrac * math.pi)
            local yawTwist = (isLeftPunch and -22 or 22) * snap
            rig:ManipulateBoneAngles(spineBone, Angle(0, 10 * snap, yawTwist))
            rig.hasSpineManip = true
        elseif rig.hasSpineManip then
            rig:ManipulateBoneAngles(spineBone, angle_zero)
            rig.hasSpineManip = false
        end
    end
end

-- ============================================================================
-- RESOLVE WEAPON CLASS FOR A FIGHTER
-- ============================================================================
function PF.ResolveFighterWeapon(session, fighterCfg)
    local wep = fighterCfg and fighterCfg.weapon or session.config.weaponPreset or ""
    if session.config.combatType == "melee" then
        if wep == "unarmed" or wep == "" then return "" end
        if wep == "melee_random" or wep == "random_melee" then
            return PF.RandomMelee[math.random(#PF.RandomMelee)] or ""
        end
        if PF.WeaponProfiles[wep] and PF.WeaponProfiles[wep].isMelee then
            return wep
        end
        return ""
    else
        if wep == "" or wep == "unarmed" or wep == "auto_gun" or wep == "random_gun" then
            return PF.RandomGuns[math.random(#PF.RandomGuns)]
        end
        return wep
    end
end

-- ============================================================================
-- SPAWN & INITIALIZE AI PROXY FOR EACH FIGHTER
-- ============================================================================
function PF.SetupFighterAI(session, idx, fighterSpec)
    local S = SPeditor.Server
    local ply = session.ply
    local cfg = session.config

    local sceneEnt = fighterSpec.ent
    if not IsValid(sceneEnt) then return nil end

    local mdl  = sceneEnt:GetModel() or "models/humans/group03/male_07.mdl"
    local pos  = sceneEnt:GetPos()
    local ang  = sceneEnt:GetAngles()
    local skin = sceneEnt:GetSkin() or 0

    local bodygroups = {}
    for _, bg in ipairs(sceneEnt:GetBodyGroups() or {}) do
        bodygroups[bg.id] = sceneEnt:GetBodygroup(bg.id)
    end

    local rag = sceneEnt
    if sceneEnt:IsNPC() then
        local spawnName = fighterSpec.name or (sceneEnt:GetClass() .. " #" .. idx)
        rag = S.SpawnModel(ply, mdl, pos, ang)
        if not IsValid(rag) then return nil end
        rag.SPeditor_Name = spawnName
        rag:SetNW2String("SPeditor_Name", spawnName)
        rag:SetSkin(skin)
        for bgId, bgVal in pairs(bodygroups) do
            rag:SetBodygroup(bgId, bgVal)
        end
        SafeRemoveEntity(sceneEnt)
        sceneEnt = rag
    elseif not sceneEnt.SPeditor_UID then
        S.Freeze(sceneEnt)
        S.StoreInit(sceneEnt)
        S.Track(ply, sceneEnt)
        local adoptName = fighterSpec.name or ("Fighter #" .. idx)
        sceneEnt.SPeditor_Name = adoptName
        sceneEnt:SetNW2String("SPeditor_Name", adoptName)
        rag = sceneEnt
    end

    local npcClass = fighterSpec.npcClass or PF.GuessNPCClassForModel(mdl)
    local npc = ents.Create(npcClass)
    if not IsValid(npc) then
        npc = ents.Create("npc_citizen")
        npcClass = "npc_citizen"
    end
    if not IsValid(npc) then return nil end

    npc:SetPos(pos)
    npc:SetAngles(Angle(0, ang.y, 0))

    local wepClass = PF.ResolveFighterWeapon(session, fighterSpec)
    if wepClass ~= "" then
        npc:SetKeyValue("additionalequipment", wepClass)
    end

    if npcClass == "npc_citizen" then
        npc:SetKeyValue("citizentype", "3")
        npc:SetKeyValue("spawnflags", tostring(bit.bor(SF_CITIZEN_AMMORESUPPLIER or 0, 256)))
    end

    npc:Spawn()
    npc:Activate()

    local npcMdl = ChooseHL2GunNPCModel(mdl, npcClass)
    if util.IsValidModel(npcMdl) then
        npc:SetModel(npcMdl)
    end

    if cfg.combatType == "gunfight" and npc.SelectWeightedSequence then
        local hasGunAct = (npc:SelectWeightedSequence(ACT_RANGE_ATTACK_SMG1) >= 0)
            or (npc:SelectWeightedSequence(ACT_IDLE_SMG1) >= 0)
            or (npc:SelectWeightedSequence(ACT_RANGE_ATTACK_PISTOL) >= 0)
        if not hasGunAct then
            local fallbackMdl = IsFemaleModel(mdl) and "models/humans/group03/female_01.mdl" or "models/humans/group03/male_07.mdl"
            npc:SetModel(fallbackMdl)
        end
    end

    npc:SetRenderMode(RENDERMODE_TRANSALPHA)
    npc:SetColor(Color(255, 255, 255, 0))
    npc:DrawShadow(false)
    npc:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

    local wepEnt = npc:GetActiveWeapon()
    if not IsValid(wepEnt) and wepClass ~= "" and npc.Give then
        wepEnt = npc:Give(wepClass)
    end
    if IsValid(wepEnt) then
        wepEnt:SetRenderMode(RENDERMODE_TRANSALPHA)
        wepEnt:SetColor(Color(255, 255, 255, 0))
        wepEnt:DrawShadow(false)
        wepEnt.GMFM_PF_Session = session
    end

    local baseHP = tonumber(fighterSpec.hp) or 100
    local spamMul = cfg.bsmodSpam and 1.6 or 1.0
    local maxHP = math.max(40, math.Round(baseHP * (cfg.hpMultiplier or 1.0) * spamMul))
    npc:SetMaxHealth(maxHP)
    npc:SetHealth(maxHP)

    if npc.CapabilitiesAdd then
        npc:CapabilitiesAdd(bit.bor(CAP_MOVE_GROUND, CAP_ANIMATEDFACE, CAP_TURN_HEAD, CAP_USE_WEAPONS, CAP_AIM_GUN, CAP_MOVE_SHOOT))
    end

    if npc.SetCurrentWeaponProficiency then
        npc:SetCurrentWeaponProficiency(WEAPON_PROFICIENCY_VERY_GOOD)
    end

    rag:SetNoDraw(false)
    rag:SetNotSolid(true)
    S.Freeze(rag)
    if not rag.SPeditor_Init then
        S.StoreInit(rag)
    end

    local wepRag = nil
    local wepProf = PF.WeaponProfiles[wepClass]
    if cfg.recordWeapons ~= false and wepProf and wepProf.model and util.IsValidModel(wepProf.model) then
        local wName = (rag.SPeditor_Name or ("Fighter " .. idx)) .. " [" .. string.gsub(wepClass, "^weapon_", "") .. "]"
        wepRag = S.SpawnModel(ply, wepProf.model, pos + Vector(0, 0, 40), ang)
        if IsValid(wepRag) then
            wepRag.SPeditor_Name = wName
            wepRag:SetNW2String("SPeditor_Name", wName)
            wepRag:SetNotSolid(true)
            wepRag:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
            if S.Attach and S.WEAR then
                S.Attach(wepRag, rag, S.WEAR)
            end
        end
    end

    local meleeAnimRig = nil
    if cfg.combatType == "melee" then
        meleeAnimRig = SpawnBSModMeleeRig(mdl, pos, Angle(0, ang.y, 0), session, npc)
        if npc.SetSchedule then
            npc:SetSchedule(SCHED_NPC_FREEZE)
        end
    end

    local entry = {
        index        = idx,
        name         = fighterSpec.name or rag.SPeditor_Name or ("Fighter #" .. idx),
        team         = tonumber(fighterSpec.team) or 0,
        sceneEnt     = rag,
        uid          = rag.SPeditor_UID,
        npc          = npc,
        meleeAnimRig = meleeAnimRig,
        wepClass     = wepClass,
        wepProf      = wepProf,
        wepEnt       = wepRag,
        maxHP        = maxHP,
        hp           = maxHP,
        origPos      = pos,
        origAng      = ang,
        smoothPos    = Vector(pos.x, pos.y, pos.z),
        smoothSpeed  = 0,
        lastPos      = Vector(pos.x, pos.y, pos.z),
        lastAng      = Angle(0, ang.y, 0),
        dead         = false,
        nextThink    = CurTime(),
        nextAttack   = CurTime() + math.Rand(0.10, 0.25),
        nextMove     = CurTime(),
        strafeDir    = (idx % 2 == 0) and 1 or -1,
        clip         = wepProf and wepProf.clipSize or 30,
        reloading    = false,
        reloadUntil  = 0,
        comboCount   = 0,
        spamCounter  = 0,
    }

    npc.GMFM_PF_Entry   = entry
    npc.GMFM_PF_Session = session
    rag.GMFM_PF_Entry   = entry
    rag.GMFM_PF_Session = session

    return entry
end

-- ============================================================================
-- CONFIGURE AI RELATIONSHIPS
-- ============================================================================
function PF.RefreshFighterRelationships(session)
    if not session or not session.fighters then return end

    for _, p in ipairs(player.GetAll()) do
        for _, f in ipairs(session.fighters) do
            if IsValid(f.npc) and f.npc.AddEntityRelationship then
                f.npc:AddEntityRelationship(p, D_NU, 99)
            end
        end
    end

    for i, f1 in ipairs(session.fighters) do
        local n1 = f1.npc
        if IsValid(n1) and not f1.dead then
            for j, f2 in ipairs(session.fighters) do
                if i ~= j and IsValid(f2.npc) and not f2.dead then
                    local isAlly = (f1.team > 0 and f1.team == f2.team)
                    if n1.AddEntityRelationship then
                        n1:AddEntityRelationship(f2.npc, isAlly and D_LI or D_HT, 99)
                    end
                end
            end
        end
    end
end

function PF.AreEnemies(f1, f2)
    if not f1 or not f2 or f1 == f2 then return false end
    if f1.dead or f2.dead then return false end
    if f1.team > 0 and f1.team == f2.team then return false end
    return true
end

function PF.FindNearestEnemy(session, fighter)
    local best, bestDistSqr = nil, math.huge
    local myPos = fighter.smoothPos or (IsValid(fighter.npc) and fighter.npc:GetPos()) or fighter.lastPos
    for _, other in ipairs(session.fighters) do
        if PF.AreEnemies(fighter, other) then
            local oPos = other.smoothPos or (IsValid(other.npc) and other.npc:GetPos()) or other.lastPos
            local d2 = myPos:DistToSqr(oPos)
            if d2 < bestDistSqr then
                bestDistSqr = d2
                best = other
            end
        end
    end
    return best, math.sqrt(bestDistSqr)
end

-- ============================================================================
-- HIT-STOP CONTROLLER (Uses RealTime() so game NEVER freezes or feels laggy!)
-- ============================================================================
function PF.TriggerHitStop(session, duration)
    if not session or not duration or duration <= 0 then return end
    local clampDur = math.Clamp(duration, 0.015, 0.05)
    session.hitStopRealUntil = math.max(session.hitStopRealUntil or 0, RealTime() + clampDur)
    game.SetTimeScale(0.45)
end

function PF.UpdateTimeScale(session)
    if not session then return end
    local rNow = RealTime()
    if session.hitStopRealUntil and rNow < session.hitStopRealUntil then
        if game.GetTimeScale() > 0.5 then
            game.SetTimeScale(0.45)
        end
    else
        session.hitStopRealUntil = nil
        local targetScale = math.Clamp(tonumber(session.config.timeScale) or 1.0, 0.4, 1.0)
        if math.abs(game.GetTimeScale() - targetScale) > 0.02 then
            game.SetTimeScale(targetScale)
        end
    end
end

-- ============================================================================
-- STEP MELEE COMBAT (INTENSE BSMOD COMBOS + EXTRA BSMOD ATTACK SPAM MODE!)
-- ============================================================================
function PF.StepMeleeFighter(session, fighter, now)
    local npc = fighter.npc
    if not IsValid(npc) or fighter.dead or fighter.inKillMove then return end

    fighter.combatOverlay = nil
    fighter.poseOverlay   = nil

    local dt = math.Clamp(now - (fighter.lastTickTime or (now - 0.015)), 0.004, 0.05)
    fighter.lastTickTime = now

    local rig = fighter.meleeAnimRig
    if not IsValid(rig) then
        rig = SpawnBSModMeleeRig(IsValid(fighter.sceneEnt) and fighter.sceneEnt:GetModel() or "", npc:GetPos(), npc:GetAngles(), session, npc)
        fighter.meleeAnimRig = rig
    end

    local isSpamMode  = (session.config.bsmodSpam == true)
    local hasMeleeWep = (fighter.wepClass and fighter.wepClass ~= "")

    local enemy, dist = PF.FindNearestEnemy(session, fighter)
    if not enemy or not IsValid(enemy.npc) then
        if IsValid(rig) then
            StepRigBaseLocomotion(rig, hasMeleeWep and "idle_melee" or "fist_idle_01", dt, 1.0, 0, 0)
            UpdateRigCombatBoneDynamics(rig, 0, nil, false)
            if rig.FrameAdvance then rig:FrameAdvance(dt) end
        end
        return
    end

    local myPos = fighter.smoothPos or npc:GetPos()
    local enPos = enemy.smoothPos or enemy.npc:GetPos()
    local dir   = (enPos - myPos)
    dir.z = 0
    if dir:LengthSqr() < 1 then dir = Vector(1, 0, 0) else dir:Normalize() end

    -- Keep AI proxy NPC frozen so C++ motor never rubberbands against our smooth movement
    if npc.SetSchedule then npc:SetSchedule(SCHED_NPC_FREEZE) end
    npc:SetLocalVelocity(vector_origin)

    -- Smoothly face opponent
    local curYaw    = fighter.lastAng and fighter.lastAng.y or npc:GetAngles().y
    local targetYaw = dir:Angle().y
    local turnSpeed = isSpamMode and 720 or 540
    local newYaw    = math.ApproachAngle(curYaw, targetYaw, turnSpeed * dt)
    local faceAng   = Angle(0, newYaw, 0)

    -- Smooth Ground-Hugging Footwork & Aggressive Gap Closing
    local desiredVel = Vector(0, 0, 0)
    local pocketRange = isSpamMode and 40 or 44

    if dist > pocketRange + 10 then
        local rushSpeed = isSpamMode and 245 or ((session.config.fightStyle == "cinematic") and 185 or 215)
        desiredVel = dir * rushSpeed
    elseif dist < 34 then
        desiredVel = -dir * 110
    elseif not fighter.activeStrike and session.config.choreoCircling and now < (fighter.circleUntil or 0) then
        desiredVel = faceAng:Right() * (fighter.strafeDir * 95) + dir * 25
    elseif fighter.activeStrike then
        -- Slight forward step-in during strikes for aggressive pressure
        desiredVel = dir * (isSpamMode and 35 or 22)
    end

    local stepVec = desiredVel * dt
    if stepVec:LengthSqr() > 0.001 then
        local trHull = util.TraceHull({
            start  = myPos + Vector(0, 0, 14),
            endpos = myPos + stepVec + Vector(0, 0, 14),
            mins   = Vector(-13, -13, 0),
            maxs   = Vector(13, 13, 54),
            filter = { npc, fighter.sceneEnt, rig, enemy.npc, enemy.sceneEnt, enemy.meleeAnimRig },
        })
        if not trHull.Hit then
            myPos = myPos + stepVec
        end

        -- Keep feet planted cleanly on ground/slopes
        local trGround = util.TraceLine({
            start  = myPos + Vector(0, 0, 32),
            endpos = myPos - Vector(0, 0, 48),
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if trGround.Hit then
            myPos.z = Lerp(0.35, myPos.z, trGround.HitPos.z)
        end
    end

    fighter.smoothPos   = myPos
    fighter.lastPos     = myPos
    fighter.lastAng     = faceAng
    fighter.smoothSpeed = Lerp(0.35, fighter.smoothSpeed or 0, desiredVel:Length())

    npc:SetPos(myPos)
    npc:SetAngles(faceAng)

    -- Update BSMod Melee Rig Base Locomotion with Hysteresis so it never flickers
    if IsValid(rig) then
        rig:SetPos(myPos)
        rig:SetAngles(faceAng)

        local spd = fighter.smoothSpeed
        local moveX, moveY = 0, 0
        if spd > 15 then
            local moveNorm = desiredVel:GetNormalized()
            moveX = math.Clamp(moveNorm:Dot(faceAng:Forward()), -1, 1)
            moveY = math.Clamp(moveNorm:Dot(faceAng:Right()), -1, 1)
            if math.abs(moveX) < 0.2 and math.abs(moveY) < 0.2 then moveX = 1 end
        end

        local targetLoco = fighter.locoState or "idle"
        if spd > 145 then
            targetLoco = "run"
        elseif spd > 30 then
            targetLoco = "walk"
        elseif spd < 15 then
            targetLoco = "idle"
        end
        fighter.locoState = targetLoco

        local seqName = "fist_idle_01"
        local locoRate = isSpamMode and 1.35 or 1.15
        if targetLoco == "run" then
            seqName = hasMeleeWep and "run_melee" or "run_fist"
        elseif targetLoco == "walk" then
            seqName = hasMeleeWep and "walk_melee" or "walk_fist"
        else
            seqName = hasMeleeWep and "idle_melee" or "fist_idle_01"
            locoRate = isSpamMode and 1.6 or 1.2
        end

        StepRigBaseLocomotion(rig, seqName, dt, locoRate, moveX, moveY)
    end

    -- Update Active Flinch Layer if Defender was recently hit
    if IsValid(rig) and fighter.flinchLayer and fighter.flinchStart then
        local fElapsed = now - fighter.flinchStart
        local fFrac = fElapsed / (fighter.flinchDur or 0.25)
        if fFrac >= 1.0 then
            if rig.SetLayerWeight then rig:SetLayerWeight(fighter.flinchLayer, 0) end
            fighter.flinchLayer = nil
        else
            if rig.SetLayerCycle then rig:SetLayerCycle(fighter.flinchLayer, fFrac) end
            if rig.SetLayerWeight then rig:SetLayerWeight(fighter.flinchLayer, 1.0 - fFrac * 0.5) end
        end
    end

    -- Update Active BSMod Strike (Punch or Kick)
    if fighter.activeStrike then
        local st      = fighter.activeStrike
        local elapsed = now - st.startTime
        local frac    = elapsed / math.max(0.06, st.duration)

        if IsValid(rig) then
            if st.layer and st.layer >= 0 then
                if rig.SetLayerCycle then rig:SetLayerCycle(st.layer, math.Clamp(frac, 0, 1)) end
                if rig.SetLayerWeight then rig:SetLayerWeight(st.layer, math.sin(math.Clamp(frac, 0, 1) * math.pi)) end
            end

            if st.def.isKick then
                local kickWeight = math.sin(math.Clamp(frac, 0, 1) * math.pi)
                UpdateRigCombatBoneDynamics(rig, kickWeight, nil, false)
            else
                UpdateRigCombatBoneDynamics(rig, 0, math.Clamp(frac, 0, 1), st.def.isLeft)
            end

            if rig.FrameAdvance then rig:FrameAdvance(dt) end
        end

        if not st.hitDone and elapsed >= (st.hitDelay or 0.09) then
            st.hitDone = true
            PF.ResolveMeleeStrikeImpact(session, fighter, enemy, st.def, dir)
        end

        if frac >= 1.0 then
            if IsValid(rig) and st.layer and st.layer >= 0 and rig.SetLayerWeight then
                rig:SetLayerWeight(st.layer, 0)
            end
            fighter.activeStrike = nil
            UpdateRigCombatBoneDynamics(rig, 0, nil, false)
        else
            return
        end
    else
        UpdateRigCombatBoneDynamics(rig, 0, nil, false)
        if IsValid(rig) and rig.FrameAdvance then
            rig:FrameAdvance(dt)
        end
    end

    -- Launch Next BSMod Attack / Combo / Spam Barrage when in range!
    if dist <= 80 and now >= (fighter.nextAttack or 0) then
        -- Roll for Random BSMod KillMove!
        local kmChance = tonumber(session.config.killMoveChance) or 55
        local enemyLowHP = (enemy.hp <= enemy.maxHP * 0.38)
        local canMidKM = session.config.midFightKillMove and (not isSpamMode or enemyLowHP or (fighter.spamCounter or 0) >= 8)
        local effectiveChance = enemyLowHP and math.min(95, kmChance * 1.5) or (canMidKM and (kmChance * 0.30) or 0)

        if not enemy.inKillMove and math.random(1, 100) <= effectiveChance then
            local forceLethal = enemyLowHP or (not session.config.midFightKillMove)
            fighter.spamCounter = 0
            if PF.StartKillMove(session, fighter, enemy, nil, forceLethal) then
                return
            end
        end

        -- Select BSMod Punch or BSMod Kick
        fighter.spamCounter = (fighter.spamCounter or 0) + 1
        fighter.comboCount  = (fighter.comboCount or 0) + 1

        local attackDef
        local kickChance = isSpamMode and 28 or 25
        if not hasMeleeWep and ((fighter.comboCount >= 4) or (math.random(1, 100) <= kickChance)) then
            attackDef = PF.BSModAttacks[3] -- bsmod_kick
            fighter.comboCount = 0
        else
            fighter.lastPunchLeft = not fighter.lastPunchLeft
            attackDef = fighter.lastPunchLeft and PF.BSModAttacks[1] or PF.BSModAttacks[2]
        end

        -- Compute strike speed & next-attack cadence:
        --   * BSMod Spam Mode: ultra-fast 0.12s-0.16s punches & 0.22s kicks with ZERO pause!
        --   * Standard Intense Melee: fast 3-5 hit combo chains (0.20s per hit), short 0.22s breather after chain
        local strikeDur, hitDelay, nextGap, animRate
        if isSpamMode then
            strikeDur = attackDef.isKick and 0.21 or 0.13
            hitDelay  = attackDef.isKick and 0.09 or 0.055
            nextGap   = 0.01
            animRate  = 2.2
        else
            strikeDur = attackDef.duration or 0.24
            hitDelay  = attackDef.hitDelay or 0.09
            animRate  = 1.45
            if fighter.comboCount > 0 and fighter.comboCount < 4 then
                nextGap = 0.03 -- Immediate follow-up strike in the combo chain!
            else
                fighter.comboCount = 0
                local style = PF.FightStyles[session.config.fightStyle] or PF.FightStyles.cinematic
                nextGap = (style.attackInterval or 0.25) * math.Rand(0.75, 1.15)
            end
        end

        fighter.nextAttack = now + strikeDur + nextGap

        local gLayer = nil
        if IsValid(rig) then
            local gestureName = hasMeleeWep and "range_melee" or attackDef.gesture
            gLayer = StartRigGestureLayer(rig, gestureName, animRate)
        end

        fighter.activeStrike = {
            def       = attackDef,
            startTime = now,
            duration  = strikeDur,
            hitDelay  = hitDelay,
            hitDone   = false,
            layer     = gLayer,
        }

        -- Authentic BSMod swing sounds (from BSMOD_ref weapon_bsmod_punch.lua & bsmod_kick.lua)
        if attackDef.isKick then
            npc:EmitSound("player/kick/foot_fire.wav", 90, math.random(95, 112), 0.9, CHAN_AUTO)
        elseif hasMeleeWep then
            npc:EmitSound("Weapon_Crowbar.Single", 82, math.random(96, 106), 0.85, CHAN_AUTO)
        else
            local side = attackDef.isLeft and "l" or "r"
            npc:EmitSound("player/fists/fists_crack" .. side .. ".wav", 88, math.random(94, 114), 0.32, CHAN_AUTO)
            npc:EmitSound("player/fists/fists_fire0" .. math.random(1, 3) .. ".wav", 88, math.random(94, 114), 0.45, CHAN_AUTO)
            npc:EmitSound("player/fists/fists_miss0" .. math.random(1, 3) .. ".wav", 88, math.random(94, 114), 0.72, CHAN_AUTO)
        end

        if not isSpamMode and session.config.choreoCircling and fighter.comboCount == 0 and math.random() < 0.30 then
            fighter.circleUntil = now + strikeDur + math.Rand(0.25, 0.55)
            if math.random() < 0.5 then fighter.strafeDir = -fighter.strafeDir end
        end
    end
end

function PF.ResolveMeleeStrikeImpact(session, attacker, defender, attackDef, dir)
    if not defender or defender.dead or defender.inKillMove then return end
    local defNpc = defender.npc
    local attNpc = attacker.npc
    if not IsValid(defNpc) then return end

    local attPos = attacker.smoothPos or (IsValid(attNpc) and attNpc:GetPos()) or attacker.lastPos
    local defPos = defender.smoothPos or defNpc:GetPos()
    if attPos:Distance(defPos) > 92 then return end

    local now = CurTime()
    local isSpamMode = (session.config.bsmodSpam == true)
    local defRig = defender.meleeAnimRig
    local roll = math.random(1, 100)

    -- Defender Block / Parry (16% chance)
    if roll <= 16 and not defender.activeStrike then
        defNpc:EmitSound("player/fists/fists_hit0" .. math.random(1, 3) .. ".wav", 85, math.random(80, 95), 0.75, CHAN_AUTO)
        if IsValid(defRig) then
            defender.flinchLayer = StartRigGestureLayer(defRig, "flinch_phys_0" .. math.random(1, 2), 1.35)
            defender.flinchStart = now
            defender.flinchDur   = 0.20
        end
        defender.flinchUntil = now + 0.20
        return
    end

    -- Direct Hit!
    local rawDmg = (attacker.wepProf and attacker.wepProf.dmg) or attackDef.dmg or 11
    if isSpamMode then
        rawDmg = rawDmg * 0.55 -- Allow longer, ultra-intense 20-30 hit BSMod spam barrages before KO!
    end
    local finalDmg = math.max(2, math.Round(rawDmg * (session.config.damageMultiplier or 1.0)))

    -- Convert finishing blow into an authentic BSMod KillMove!
    if defender.hp - finalDmg <= 0 then
        local kmChance = tonumber(session.config.killMoveChance) or 55
        if math.random(1, 100) <= math.max(kmChance, 70) then
            defender.hp = 10
            if PF.StartKillMove(session, attacker, defender, nil, true) then
                return
            end
        end
    end

    defender.hp          = defender.hp - finalDmg
    defender.flinchUntil = now + 0.25
    if IsValid(defNpc) then
        defNpc:SetHealth(math.max(1, defender.hp))
    end

    local hitPos = defPos + Vector(0, 0, 50) + VectorRand() * 4

    if attackDef.isKick then
        defNpc:EmitSound("player/kick/foot_kickbody.wav", 94, math.random(92, 110), 1.0, CHAN_AUTO)
        local fxKick = EffectData()
        fxKick:SetOrigin(hitPos)
        fxKick:SetNormal(-dir)
        util.Effect("kick_groundhit", fxKick, true, true)
    else
        defNpc:EmitSound("player/fists/fists_hit0" .. math.random(1, 3) .. ".wav", 90, math.random(92, 112), 1.0, CHAN_AUTO)
    end

    local ed = EffectData()
    ed:SetOrigin(hitPos)
    ed:SetNormal(-dir)
    ed:SetScale(1.0)
    util.Effect("BloodImpact", ed, true, true)

    if PF.RecordCombatEffect then
        PF.RecordCombatEffect(session, "BloodImpact", hitPos, (-dir):Angle())
    end

    if IsValid(defRig) then
        local flinchAnims = {
            "flinch_head_01",
            "flinch_head_02",
            "flinch_phys_01",
            "flinch_phys_02",
            "flinch_stomach_01",
        }
        local fAnim = attackDef.isKick and "flinch_stomach_01" or flinchAnims[math.random(#flinchAnims)]
        defender.flinchLayer = StartRigGestureLayer(defRig, fAnim, isSpamMode and 1.8 or 1.3)
        defender.flinchStart = now
        defender.flinchDur   = isSpamMode and 0.14 or 0.22
    end

    -- Knockback on kicks (kept tight during spam mode so fighters stay in each other's face!)
    local pushDist = attackDef.isKick and (isSpamMode and 7 or 16) or (isSpamMode and 2 or 5)
    local pushedPos = defPos + dir * pushDist
    local trPush = util.TraceHull({
        start  = defPos + Vector(0, 0, 14),
        endpos = pushedPos + Vector(0, 0, 14),
        mins   = Vector(-13, -13, 0),
        maxs   = Vector(13, 13, 54),
        filter = { defNpc, defender.sceneEnt, defRig, attNpc, attacker.sceneEnt },
    })
    if not trPush.Hit then
        defender.smoothPos = pushedPos
        defender.lastPos   = pushedPos
        defNpc:SetPos(pushedPos)
    end

    if defender.hp <= 0 then
        PF.KillFighterWithRagdoll(session, attacker, defender, dir * (attackDef.knock or 160) + Vector(0, 0, 65))
    end
end

-- ============================================================================
-- STEP GUNFIGHT COMBAT (INTENSE HL2 DEFAULT GUN ANIMATIONS + RAPID FIREFIGHTS)
-- ============================================================================
function PF.StepGunfightFighter(session, fighter, now)
    local npc = fighter.npc
    if not IsValid(npc) or fighter.dead or fighter.inKillMove then return end

    fighter.combatOverlay = nil
    fighter.poseOverlay   = nil

    local enemy, dist = PF.FindNearestEnemy(session, fighter)
    if not enemy or not IsValid(enemy.npc) then return end

    local myPos = npc:GetPos()
    local enPos = enemy.npc:GetPos()
    local dir   = (enPos - myPos)
    dir.z = 0
    if dir:LengthSqr() < 1 then dir = Vector(1, 0, 0) else dir:Normalize() end

    npc:SetEnemy(enemy.npc)
    npc:UpdateEnemyMemory(enemy.npc, enPos)

    fighter.smoothPos = myPos
    fighter.lastPos   = myPos
    fighter.lastAng   = npc:GetAngles()

    local prof = fighter.wepProf or PF.WeaponProfiles["weapon_smg1"]

    -- Point-Blank CQC Takedown if two gunfighters rush right into each other!
    if dist <= 64 and math.random(1, 100) <= 35 then
        if PF.StartKillMove(session, fighter, enemy, nil, enemy.hp <= enemy.maxHP * 0.5) then
            return
        end
    end

    -- Reloading state using native HL2 reload activity
    if fighter.reloading then
        if now >= fighter.reloadUntil then
            fighter.reloading = false
            fighter.clip = prof.clipSize or 30
            local wep = npc:GetActiveWeapon()
            if IsValid(wep) and wep.SetClip1 then
                wep:SetClip1(fighter.clip)
            end
        else
            return
        end
    end

    local activeWep = npc:GetActiveWeapon()
    if IsValid(activeWep) and activeWep.Clip1 and activeWep:Clip1() <= 0 and fighter.clip > 0 then
        activeWep:SetClip1(fighter.clip)
    end

    -- Dynamic HL2 AI tactical schedules (aggressive flanking, advancing & firing)
    if now >= (fighter.nextMove or 0) then
        fighter.nextMove = now + math.Rand(0.65, 1.25)
        if dist > 480 then
            npc:SetLastPosition(enPos - dir * 200)
            npc:SetSchedule(SCHED_CHASE_ENEMY)
        elseif dist < 105 then
            npc:SetSchedule(SCHED_BACK_AWAY_FROM_ENEMY)
        else
            if math.random() < 0.35 then
                local flankPos = myPos + dir:Angle():Right() * (fighter.strafeDir * 95) + dir * 40
                fighter.strafeDir = -fighter.strafeDir
                npc:SetLastPosition(flankPos)
                npc:SetSchedule(SCHED_ESTABLISH_LINE_OF_FIRE)
            else
                npc:SetSchedule(SCHED_RANGE_ATTACK1)
            end
        end
    end

    local curYaw    = npc:GetAngles().y
    local targetYaw = dir:Angle().y
    local newYaw    = math.ApproachAngle(curYaw, targetYaw, 18)
    npc:SetAngles(Angle(0, newYaw, 0))

    -- Intense HL2 Gunfire Bursts
    if now >= (fighter.nextAttack or 0) then
        if fighter.clip <= 0 then
            fighter.reloading   = true
            fighter.reloadUntil = now + 1.45
            if prof.reloadSnd then
                npc:EmitSound(prof.reloadSnd, 80, 100, 0.9)
            end
            if npc.SetSchedule then
                npc:SetSchedule(SCHED_RELOAD)
            end
            if npc.RestartGesture and prof.reloadAct then
                npc:RestartGesture(prof.reloadAct)
            end
            return
        end

        if not fighter.burstRemaining or fighter.burstRemaining <= 0 then
            fighter.burstRemaining = math.random(prof.burstMin or 4, prof.burstMax or 8)
            if npc.SetSchedule and dist <= 480 then
                npc:SetSchedule(SCHED_RANGE_ATTACK1)
            end
        end

        if (now - (fighter.lastNativeShot or 0)) > 0.09 then
            PF.FireFighterWeapon(session, fighter, enemy, prof, now)
        end

        fighter.clip = fighter.clip - 1
        fighter.burstRemaining = fighter.burstRemaining - 1

        if fighter.burstRemaining > 0 and fighter.clip > 0 then
            fighter.nextAttack = now + (prof.fireRate or 0.08)
        else
            local styleMul = (session.config.fightStyle == "cinematic") and 0.95
                or (session.config.fightStyle == "realistic" and 0.70 or 0.85)
            fighter.nextAttack = now + (prof.cooldown or 0.35) * styleMul * math.Rand(0.75, 1.15)
        end
    end
end

function PF.FireFighterWeapon(session, attacker, target, prof, now)
    local npc = attacker.npc
    if not IsValid(npc) or not target or target.dead then return end

    attacker.lastShotTime = now

    -- Play native HL2 shoot gesture overlay on the NPC
    if npc.RestartGesture and prof.shootAct then
        npc:RestartGesture(prof.shootAct)
    end

    local shootPos = npc:GetShootPos()
    local shootAng = npc:GetAimVector():Angle()
    if IsValid(attacker.wepEnt) then
        local muzId = attacker.wepEnt:LookupAttachment("muzzle")
        local muz   = (muzId and muzId > 0) and attacker.wepEnt:GetAttachment(muzId) or nil
        if muz and muz.Pos then
            shootPos = muz.Pos
            shootAng = muz.Ang
        else
            shootPos = attacker.wepEnt:GetPos() + attacker.wepEnt:GetForward() * 12
        end
    end

    local targetPos = (IsValid(target.npc) and (target.npc:GetPos() + Vector(0, 0, 44)) or (target.lastPos + Vector(0, 0, 44)))
    local aimDir    = (targetPos - shootPos):GetNormalized()

    if prof.sound then
        npc:EmitSound(prof.sound, 90, math.random(97, 104), 1.0)
    end

    -- Muzzle flash at gun barrel
    local edMuz = EffectData()
    edMuz:SetOrigin(shootPos)
    edMuz:SetNormal(aimDir)
    edMuz:SetAngles(shootAng)
    edMuz:SetScale(1.0)
    util.Effect(prof.muzzle or "MuzzleEffect", edMuz, true, true)

    -- Brass shell ejection for extra gunfight intensity
    if prof.shell then
        local edSh = EffectData()
        edSh:SetOrigin(shootPos - aimDir * 6)
        edSh:SetAngles(shootAng + Angle(0, 90, 0))
        util.Effect(prof.shell, edSh, true, true)
    end

    if PF.RecordCombatEffect then
        PF.RecordCombatEffect(session, prof.muzzle or "MuzzleEffect", shootPos, shootAng)
    end

    local spread  = prof.spread or 0.038
    local pellets = prof.pellets or 1

    for p = 1, pellets do
        local spreadVec = Vector(
            math.Rand(-spread, spread),
            math.Rand(-spread, spread),
            math.Rand(-spread * 0.7, spread * 0.7)
        )
        local shotDir = (aimDir + spreadVec):GetNormalized()

        local tr = util.TraceLine({
            start  = shootPos,
            endpos = shootPos + shotDir * 2600,
            filter = { npc, attacker.sceneEnt, attacker.wepEnt },
        })

        local edTr = EffectData()
        edTr:SetStart(shootPos)
        edTr:SetOrigin(tr.HitPos)
        edTr:SetScale(5500)
        util.Effect(prof.tracer or "Tracer", edTr, true, true)

        local hitFighter = nil
        if IsValid(tr.Entity) then
            for _, f in ipairs(session.fighters) do
                if f ~= attacker and not f.dead and (tr.Entity == f.npc or tr.Entity == f.sceneEnt) then
                    hitFighter = f
                    break
                end
            end
        end

        if not hitFighter and p == 1 then
            local distToRay = util.DistanceToLine(shootPos, tr.HitPos, targetPos)
            if distToRay <= 24 then
                hitFighter = target
            end
        end

        if hitFighter and PF.AreEnemies(attacker, hitFighter) then
            PF.ApplyGunshotHit(session, attacker, hitFighter, prof, shotDir, targetPos + VectorRand() * 6, now)
            if hitFighter.dead then break end
        elseif tr.Hit then
            local edImp = EffectData()
            edImp:SetOrigin(tr.HitPos)
            edImp:SetNormal(tr.HitNormal)
            util.Effect("Impact", edImp, true, true)
        end
    end
end

function PF.ApplyGunshotHit(session, attacker, hitFighter, prof, shotDir, bloodPos, now)
    if not hitFighter or hitFighter.dead then return end
    local rawDmg = (prof and prof.dmg) or 9
    local dmg    = math.max(2, math.Round(rawDmg * (session.config.damageMultiplier or 1.0)))

    hitFighter.hp          = hitFighter.hp - dmg
    hitFighter.flinchUntil = (now or CurTime()) + 0.22

    local edBl = EffectData()
    edBl:SetOrigin(bloodPos)
    edBl:SetNormal(-shotDir)
    edBl:SetScale(1.0)
    util.Effect("BloodImpact", edBl, true, true)

    if PF.RecordCombatEffect then
        PF.RecordCombatEffect(session, "BloodImpact", bloodPos, (-shotDir):Angle())
    end

    if IsValid(hitFighter.npc) then
        hitFighter.npc:SetHealth(math.max(1, hitFighter.hp))
        hitFighter.npc:EmitSound("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav", 80, 100, 0.9)
        if hitFighter.npc.RestartGesture then
            hitFighter.npc:RestartGesture(ACT_GESTURE_SMALL_FLINCH)
        end
    end

    if hitFighter.hp <= 0 then
        PF.KillFighterWithRagdoll(session, attacker, hitFighter, shotDir * 280 + Vector(0, 0, 65))
    end
end

hook.Add("EntityFireBullets", "GMFM_ProcFight_NPCFireBullets", function(ent, data)
    if table.IsEmpty(PF.Sessions) or not IsValid(ent) or not data then return end
    local fighter = ent.GMFM_PF_Entry
    local session = ent.GMFM_PF_Session
    if not fighter and IsValid(ent:GetOwner()) then
        fighter = ent:GetOwner().GMFM_PF_Entry
        session = ent:GetOwner().GMFM_PF_Session
    end
    if not fighter or not session or not session.active then return end

    local now = CurTime()
    fighter.lastNativeShot = now
    fighter.lastShotTime   = now

    local muzPos = data.Src or ent:GetPos()
    local muzAng = (data.Dir or ent:GetForward()):Angle()
    if IsValid(fighter.wepEnt) then
        local muzId = fighter.wepEnt:LookupAttachment("muzzle")
        local muz   = (muzId and muzId > 0) and fighter.wepEnt:GetAttachment(muzId) or nil
        if muz and muz.Pos then
            muzPos = muz.Pos
            muzAng = muz.Ang
        end
    end

    if PF.RecordCombatEffect then
        PF.RecordCombatEffect(session, (fighter.wepProf and fighter.wepProf.muzzle) or "MuzzleEffect", muzPos, muzAng)
    end

    local origCallback = data.Callback
    data.Callback = function(att, tr, dmgInfo)
        if origCallback then origCallback(att, tr, dmgInfo) end
        if not tr or not IsValid(tr.Entity) then return end
        for _, f in ipairs(session.fighters) do
            if f ~= fighter and not f.dead and (tr.Entity == f.npc or tr.Entity == f.sceneEnt) and PF.AreEnemies(fighter, f) then
                PF.ApplyGunshotHit(session, fighter, f, fighter.wepProf, tr.Normal or data.Dir, tr.HitPos, now)
                break
            end
        end
    end
    return true
end)

-- ============================================================================
-- KILL FIGHTER & ENABLE NATURAL RAGDOLL PHYSICS COLLAPSE
-- ============================================================================
function PF.KillFighterWithRagdoll(session, attacker, victim, impulseVec)
    if not victim or victim.dead then return end

    local rag = victim.sceneEnt
    local npc = victim.npc

    if IsValid(rag) and rag:GetClass() == "prop_ragdoll" and PF.SyncFighterToRagdoll then
        PF.SyncFighterToRagdoll(session, victim, true)
    end

    victim.dead          = true
    victim.deathTime     = CurTime()
    victim.killedBy      = attacker
    victim.poseOverlay   = nil
    victim.combatOverlay = nil

    if IsValid(victim.meleeAnimRig) then
        SafeRemoveEntity(victim.meleeAnimRig)
        victim.meleeAnimRig = nil
    end
    if IsValid(victim.kmAnim) then
        SafeRemoveEntity(victim.kmAnim)
        victim.kmAnim = nil
    end

    if IsValid(rag) and rag:GetClass() == "prop_ragdoll" then
        victim.ragdollPhysicsActive = true
        rag:SetNotSolid(false)
        rag:SetNoDraw(false)
        rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        local vel = impulseVec or Vector(0, 0, -40)
        for i = 0, rag:GetPhysicsObjectCount() - 1 do
            local phys = rag:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                phys:EnableMotion(true)
                phys:Wake()
                phys:SetVelocity(vel * (i == 0 and 1.0 or 0.75))
            end
        end
    end

    if IsValid(npc) then
        npc:EmitSound("npc/metropolice/die" .. math.random(1, 4) .. ".wav", 80, math.random(94, 105), 0.9)
        SafeRemoveEntity(npc)
        victim.npc = nil
    end

    if PF.OnDirectorEvent then
        PF.OnDirectorEvent(session, "fighter_killed", { attacker = attacker, victim = victim })
    end
    if PF.BroadcastEvent then
        PF.BroadcastEvent(session, "ko", {
            attacker = attacker and attacker.name or "Fighter",
            victim   = victim.name or "Fighter",
        })
    end
end
