-- ============================================================================
-- GM:FM Procedural Fight Scene — Shared Definitions, Modes & Presets
-- ============================================================================
GMFM_ProcFight = GMFM_ProcFight or {}
local PF = GMFM_ProcFight

local COMP = SPeditor and SPeditor.Component and SPeditor.Component("procfight") or nil
if COMP then
    PF.COMP = COMP
    COMP.PF = PF

    local langEN = {
        -- Context Menu & Menus
        ["pf.menu"]                     = "Procedural Fight",
        ["pf.menu.open_studio"]         = "Procedural Fight Studio...",
        ["pf.menu.quick_start"]         = "Start Procedural Fight Now!",
        ["pf.menu.stop_bake"]           = "Stop Fight & Bake to Timeline",
        ["pf.menu.trigger_killmove"]    = "Trigger Random KillMove Now!",
        ["pf.menu.add_fighter"]         = "Add to Procedural Fight Roster",
        ["pf.menu.remove_fighter"]      = "Remove from Procedural Fight Roster",
        ["pf.menu.add_selected"]        = "Add All Selected Characters to Fight",
        ["pf.menu.clear_roster"]        = "Clear Fighter Roster",
        ["pf.menu.combat_type"]         = "Combat Mode",
        ["pf.menu.fight_style"]         = "Procedural Style (Pacing)",
        ["pf.menu.preset_melee_cine"]   = "Melee (BSMod KillMoves) — Cinematic",
        ["pf.menu.preset_melee_real"]   = "Melee (BSMod KillMoves) — Realistic",
        ["pf.menu.preset_melee_norm"]   = "Melee (BSMod KillMoves) — Normal",
        ["pf.menu.preset_melee_spam"]   = "🔥 Melee EXTRA: BSMod Attack Spam (Punch & Kick Frenzy)",
        ["pf.menu.preset_gun_cine"]     = "Gunfight — Cinematic",
        ["pf.menu.preset_gun_real"]     = "Gunfight — Realistic",
        ["pf.menu.preset_gun_norm"]     = "Gunfight — Normal",

        -- Combat Types
        ["pf.type.melee"]               = "Melee (BSMod Compat + KillMoves)",
        ["pf.type.melee.desc"]          = "Hand-to-hand & close-quarters combat with dodges, blocks, combos, and random BSMod / procedural KillMove finishers.",
        ["pf.type.gunfight"]            = "Gunfight (Tactical Ranged)",
        ["pf.type.gunfight.desc"]       = "Firearm shootouts using GMod AI with cover, strafing, crouch-fire, reloads, tracers, muzzle flashes, and impacts.",

        -- Procedural Fight Styles
        ["pf.style.cinematic"]          = "Cinematic (Slow & Dramatic)",
        ["pf.style.cinematic.desc"]     = "Slows down and choreographs combat for GM:FM filmmaking: smooth slow-mo keyframes, hit-stop, dynamic camera cuts, and dramatic KillMoves.",
        ["pf.style.realistic"]          = "Realistic (Tactical & Lethal)",
        ["pf.style.realistic.desc"]     = "Authentic speed and high lethality: realistic recoil, flinching, cover usage, quick decisive exchanges, and physics ragdoll deaths.",
        ["pf.style.normal"]             = "Normal (Standard GMod AI)",
        ["pf.style.normal.desc"]        = "Balanced classic Garry's Mod AI combat speed, standard health pools, and arcade-paced action.",

        -- Studio Window UI
        ["pf.ui.title"]                 = "GM:FM Procedural Fight Studio",
        ["pf.ui.subtitle"]              = "AI Choreography, BSMod Melee KillMoves & Gunfight Recorder",
        ["pf.ui.roster"]                = "Fighters Roster (2 or more characters)",
        ["pf.ui.add_sel"]               = "+ Add Selected",
        ["pf.ui.add_all_scene"]         = "+ Add All Scene Ragdolls",
        ["pf.ui.spawn_npc"]             = "+ Spawn Fighter",
        ["pf.ui.clear"]                 = "Clear",
        ["pf.ui.team_ffa"]              = "Free-For-All (All vs All)",
        ["pf.ui.team_1"]                = "Team 1 (Blue)",
        ["pf.ui.team_2"]                = "Team 2 (Red)",
        ["pf.ui.team_3"]                = "Team 3 (Green)",
        ["pf.ui.team_4"]                = "Team 4 (Gold)",
        ["pf.ui.combat_header"]         = "1. Combat Type (Melee BSMod vs Gunfight)",
        ["pf.ui.style_header"]          = "2. Procedural Fight Style (Cinematic / Realistic / Normal)",
        ["pf.ui.settings_header"]       = "3. Choreography, KillMoves & Camera Settings",
        ["pf.ui.killmove_chance"]       = "Random KillMove Chance (%)",
        ["pf.ui.killmove_midfight"]     = "Allow Non-Lethal / Mid-Fight KillMoves",
        ["pf.ui.bsmod_spam"]            = "🔥 EXTRA: BSMod Attack Spam Mode (Punch & Kick Barrage)",
        ["pf.ui.bsmod_compat"]          = "BSMod Integration + Built-in KillMove Engine",
        ["pf.ui.cinematic_speed"]       = "Cinematic Time Scale (Slow-Mo)",
        ["pf.ui.time_stretch"]          = "Timeline Bake Stretch (Slower Playback)",
        ["pf.ui.hitstop"]               = "Cinematic Hit-Stop & Impact Shake",
        ["pf.ui.auto_director"]         = "Auto-Director Camera & Timeline Cuts",
        ["pf.ui.record_weapons"]        = "Record Weapons, Muzzle Flashes & Tracers",
        ["pf.ui.record_sounds"]         = "Record Combat Sounds & Impacts",
        ["pf.ui.record_flex"]           = "Procedural Facial Expressions (Rage/Pain)",
        ["pf.ui.duration"]              = "Max Fight Duration (s)",
        ["pf.ui.step"]                  = "Keyframe Sample Step (frames)",
        ["pf.ui.start_btn"]             = "START PROCEDURAL FIGHT (RECORD TO TIMELINE)",
        ["pf.ui.stop_btn"]              = "STOP FIGHT & BAKE KEYFRAMES",
        ["pf.ui.killmove_btn"]          = "FORCE RANDOM KILLMOVE NOW!",
    }

    local langPT = {
        ["pf.menu"]                     = "Procedural Fight (Luta Procedural)",
        ["pf.menu.open_studio"]         = "Estúdio Procedural Fight...",
        ["pf.menu.quick_start"]         = "Iniciar Luta Procedural Agora!",
        ["pf.menu.stop_bake"]           = "Parar Luta e Gravar na Timeline",
        ["pf.menu.trigger_killmove"]    = "Forçar KillMove Aleatório Agora!",
        ["pf.menu.add_fighter"]         = "Adicionar Lutador ao Procedural Fight",
        ["pf.menu.remove_fighter"]      = "Remover Lutador do Procedural Fight",
        ["pf.menu.add_selected"]        = "Adicionar Selecionados à Luta",
        ["pf.menu.clear_roster"]        = "Limpar Lista de Lutadores",
        ["pf.menu.combat_type"]         = "Tipo de Combate",
        ["pf.menu.fight_style"]         = "Estilo Procedural (Ritmo)",
        ["pf.menu.preset_melee_cine"]   = "Melee (BSMod KillMoves) — Cinematic",
        ["pf.menu.preset_melee_real"]   = "Melee (BSMod KillMoves) — Realistic",
        ["pf.menu.preset_melee_norm"]   = "Melee (BSMod KillMoves) — Normal",
        ["pf.menu.preset_melee_spam"]   = "🔥 Melee EXTRA: Spam de Ataques BSMod (Punch & Kick Frenético)",
        ["pf.menu.preset_gun_cine"]     = "Gunfight (Tiroteio) — Cinematic",
        ["pf.menu.preset_gun_real"]     = "Gunfight (Tiroteio) — Realistic",
        ["pf.menu.preset_gun_norm"]     = "Gunfight (Tiroteio) — Normal",
        ["pf.ui.bsmod_spam"]            = "🔥 EXTRA: Modo Spam de Ataques BSMod (Rajada de Punch & Kick)",
    }

    local langRU = {
        ["pf.menu"]                     = "Процедурный бой (Procedural Fight)",
        ["pf.menu.open_studio"]         = "Студия процедурного боя...",
        ["pf.menu.quick_start"]         = "Начать процедурный бой!",
        ["pf.menu.stop_bake"]           = "Остановить и запечь в таймлайн",
        ["pf.menu.trigger_killmove"]    = "Случайный KillMove сейчас!",
        ["pf.menu.add_fighter"]         = "Добавить в список бойцов",
        ["pf.menu.remove_fighter"]      = "Убрать из списка бойцов",
        ["pf.menu.add_selected"]        = "Добавить выбранных в бой",
        ["pf.menu.clear_roster"]        = "Очистить список бойцов",
        ["pf.menu.combat_type"]         = "Тип боя",
        ["pf.menu.fight_style"]         = "Стиль боя",
        ["pf.menu.preset_melee_cine"]   = "Ближний бой (BSMod KillMoves) — Кинематографичный",
        ["pf.menu.preset_melee_real"]   = "Ближний бой (BSMod KillMoves) — Реалистичный",
        ["pf.menu.preset_melee_norm"]   = "Ближний бой (BSMod KillMoves) — Обычный",
        ["pf.menu.preset_gun_cine"]     = "Перестрелка (Gunfight) — Кинематографичный",
        ["pf.menu.preset_gun_real"]     = "Перестрелка (Gunfight) — Реалистичный",
        ["pf.menu.preset_gun_norm"]     = "Перестрелка (Gunfight) — Обычный",
    }

    COMP:Lang("en", langEN)
    COMP:Lang("pt", langPT)
    COMP:Lang("pt-br", langPT)
    COMP:Lang("ru", langRU)
end

-- ============================================================================
-- 1. COMBAT TYPES (Melee BSMod Compat vs Gunfight)
-- ============================================================================
PF.CombatTypes = {
    melee = {
        id          = "melee",
        name        = "Melee (BSMod Compat)",
        shortName   = "Melee (BSMod)",
        icon        = "icon16/sport_boxing.png",
        color       = Color(235, 110, 50),
        description = "Close-quarters hand-to-hand & melee combat with blocks, dodges, combos, and random BSMod / procedural KillMove finishers.",
        defaultWep  = "unarmed",
    },
    gunfight = {
        id          = "gunfight",
        name        = "Gunfight",
        shortName   = "Gunfight",
        icon        = "icon16/gun.png",
        color       = Color(75, 165, 245),
        description = "Tactical firearm combat using GMod AI with cover, strafing, crouch-shooting, reloads, muzzle flashes, tracers, and bullet impacts.",
        defaultWep  = "auto_gun",
    }
}

PF.CombatTypeOrder = { "melee", "gunfight" }

-- ============================================================================
-- 2. PROCEDURAL FIGHT STYLES (Cinematic / Realistic / Normal)
-- ============================================================================
PF.FightStyles = {
    cinematic = {
        id               = "cinematic",
        name             = "Cinematic",
        badge            = "CINEMATIC INTENSE",
        icon             = "icon16/film.png",
        color            = Color(245, 185, 55),
        description      = "Intense choreographed combat for GM:FM filmmaking: smooth 60fps keyframes, dynamic camera cuts, relentless combos, and frequent BSMod KillMoves.",
        timeScale        = 0.85,   -- Smooth, responsive live simulation without laggy slowdown
        bakeTimeStretch  = 1.35,   -- Stretches timeline frames slightly for weighty cinematic playback
        hitStopDuration  = 0.03,   -- Crisp 30ms real-time micro-accent on heavy finishers only
        killMoveChance   = 65,     -- 65% default chance for random KillMoves in Melee
        midFightKillMove = true,   -- Allow dynamic takedowns/grapples mid-fight as well as fatal finishers
        hpMultiplier     = 2.2,    -- Longer, intense back-and-forth exchanges
        damageMultiplier = 0.80,   -- Prevents instant 1-shot deaths before choreography builds up
        attackInterval   = 0.28,   -- Fast, relentless combo cadence
        choreoCircling   = true,   -- Fighters weave, pressure, and square up dynamically
        autoDirectorCam  = true,   -- Automatically generates dynamic camera cuts & KillMove close-ups
        keyframeMode     = "spline",
        step             = 1,      -- Sample every frame for buttery smooth motion
    },
    realistic = {
        id               = "realistic",
        name             = "Realistic",
        badge            = "REALISTIC LETHAL",
        icon             = "icon16/shield.png",
        color            = Color(90, 210, 125),
        description      = "Grounded, hyper-aggressive, and lethal combat: 1.0x speed, high weapon lethality, rapid firefights, and physics ragdoll deaths.",
        timeScale        = 1.0,
        bakeTimeStretch  = 1.0,
        hitStopDuration  = 0.0,
        killMoveChance   = 40,
        midFightKillMove = false,
        hpMultiplier     = 1.0,
        damageMultiplier = 1.35,
        attackInterval   = 0.20,
        choreoCircling   = false,
        autoDirectorCam  = false,
        keyframeMode     = "linear",
        step             = 1,
    },
    normal = {
        id               = "normal",
        name             = "Normal",
        badge            = "NORMAL GMOD AI",
        icon             = "icon16/controller.png",
        color            = Color(140, 175, 230),
        description      = "Fast-paced Garry's Mod AI combat speed and balanced health/damage for intense NPC brawls and shootouts.",
        timeScale        = 1.0,
        bakeTimeStretch  = 1.0,
        hitStopDuration  = 0.0,
        killMoveChance   = 50,
        midFightKillMove = true,
        hpMultiplier     = 1.4,
        damageMultiplier = 1.0,
        attackInterval   = 0.25,
        choreoCircling   = false,
        autoDirectorCam  = false,
        keyframeMode     = "spline",
        step             = 1,
    }
}

PF.FightStyleOrder = { "cinematic", "realistic", "normal" }

-- ============================================================================
-- 3. WEAPON LOADOUT PRESETS
-- ============================================================================
PF.WeaponPresets = {
    -- Melee Presets
    { id = "unarmed",          name = "Unarmed Martial Arts (BSMod Fists/Kicks)", mode = "melee",    class = "" },
    { id = "melee_random",     name = "Random Melee (Fists / Crowbar / Baton)",   mode = "melee",    class = "random_melee" },
    { id = "weapon_crowbar",   name = "Crowbar (Heavy Melee)",                    mode = "melee",    class = "weapon_crowbar" },
    { id = "weapon_stunstick", name = "Stunstick / Shock Baton",                  mode = "melee",    class = "weapon_stunstick" },

    -- Gunfight Presets
    { id = "auto_gun",         name = "Auto Tactical Loadout (SMG / AR2 / Shotgun)", mode = "gunfight", class = "random_gun" },
    { id = "weapon_smg1",      name = "MP7 Submachine Gun (weapon_smg1)",         mode = "gunfight", class = "weapon_smg1" },
    { id = "weapon_ar2",       name = "OSIPR Pulse Rifle (weapon_ar2)",           mode = "gunfight", class = "weapon_ar2" },
    { id = "weapon_shotgun",   name = "SPAS-12 Combat Shotgun (weapon_shotgun)",  mode = "gunfight", class = "weapon_shotgun" },
    { id = "weapon_pistol",    name = "9mm Tactical Pistol (weapon_pistol)",      mode = "gunfight", class = "weapon_pistol" },
    { id = "weapon_357",       name = ".357 Magnum Revolver (weapon_357)",        mode = "gunfight", class = "weapon_357" },
    { id = "weapon_crossbow",  name = "Resistance Crossbow (weapon_crossbow)",    mode = "gunfight", class = "weapon_crossbow" },
    { id = "weapon_annabelle", name = "Grigori Rifle (weapon_annabelle)",         mode = "gunfight", class = "weapon_annabelle" },
    { id = "weapon_rpg",       name = "RPG Launcher (weapon_rpg)",                mode = "gunfight", class = "weapon_rpg" },
}

PF.RandomGuns = {
    "weapon_smg1",
    "weapon_ar2",
    "weapon_shotgun",
    "weapon_pistol",
    "weapon_357",
}

PF.RandomMelee = {
    "", -- unarmed martial arts
    "",
    "weapon_crowbar",
    "weapon_stunstick",
}

-- ============================================================================
-- 4. SPAWNABLE FIGHTER TEMPLATES (For quick testing / adding characters)
-- ============================================================================
PF.FighterTemplates = {
    { name = "Rebel Fighter (Male 07)",   model = "models/humans/group03/male_07.mdl",             npc = "npc_citizen",     team = 1 },
    { name = "Rebel Medic (Female 01)",   model = "models/humans/group03m/female_01.mdl",          npc = "npc_citizen",     team = 1 },
    { name = "Combine Soldier",           model = "models/combine_soldier.mdl",                    npc = "npc_combine_s",   team = 2 },
    { name = "Combine Elite",             model = "models/combine_super_soldier.mdl",              npc = "npc_combine_s",   team = 2 },
    { name = "Metrocop Officer",          model = "models/police.mdl",                             npc = "npc_metropolice", team = 2 },
    { name = "Barney Calhoun",            model = "models/barney.mdl",                             npc = "npc_barney",      team = 1 },
    { name = "Alyx Vance",                model = "models/alyx.mdl",                               npc = "npc_alyx",        team = 1 },
    { name = "Father Grigori",            model = "models/monk.mdl",                               npc = "npc_monk",        team = 1 },
    { name = "G-Man (Martial Artist)",    model = "models/gman_high.mdl",                          npc = "npc_citizen",     team = 3 },
    { name = "Breen Enforcer",            model = "models/breen.mdl",                              npc = "npc_citizen",     team = 4 },
}

-- ============================================================================
-- 5. KILLMOVE DEFINITIONS (Authentic BSMod Sequences from BSMOD_ref)
--    Attacker Rig: models/weapons/c_limbs.mdl
--    Victim Rig:   models/bsmodimations_human.mdl (or models/bsmodimations_hunter.mdl)
-- ============================================================================
PF.KillMoves = {
    {
        id           = "killmove_front_1",
        seq          = "killmove_front_1",
        name         = "BSMod Front Finisher 1 (Combo + Spartan Kick)",
        attModel     = "models/weapons/c_limbs.mdl",
        vicModel     = "models/bsmodimations_human.mdl",
        duration     = 1.31,
        targetKMTime = 1.15,
        plyKMTime    = 1.25,
        impactFrac   = 0.65,
        lethal       = true,
        direction    = "front",
        camAngle     = "closeup_side",
        soundSetup   = "player/fists/fists_fire01.wav",
        soundImpact  = "player/killmove/km_hit2.wav",
    },
    {
        id           = "killmove_front_2",
        seq          = "killmove_front_2",
        name         = "BSMod Front Finisher 2 (Brutal Uppercut & Slam)",
        attModel     = "models/weapons/c_limbs.mdl",
        vicModel     = "models/bsmodimations_human.mdl",
        duration     = 1.77,
        targetKMTime = 1.65,
        plyKMTime    = 1.75,
        impactFrac   = 0.68,
        lethal       = true,
        direction    = "front",
        camAngle     = "low_hero",
        soundSetup   = "player/fists/fists_fire02.wav",
        soundImpact  = "player/killmove/km_bonebreak1.wav",
    },
    {
        id           = "killmove_left_1",
        seq          = "killmove_left_1",
        name         = "BSMod Left Flank Takedown",
        attModel     = "models/weapons/c_limbs.mdl",
        vicModel     = "models/bsmodimations_human.mdl",
        duration     = 1.75,
        targetKMTime = 1.50,
        plyKMTime    = 1.65,
        impactFrac   = 0.60,
        lethal       = true,
        direction    = "left",
        camAngle     = "closeup_side",
        soundSetup   = "player/fists/fists_fire03.wav",
        soundImpact  = "player/killmove/km_bonebreak2.wav",
    },
    {
        id           = "killmove_right_1",
        seq          = "killmove_right_1",
        name         = "BSMod Right Side Takedown",
        attModel     = "models/weapons/c_limbs.mdl",
        vicModel     = "models/bsmodimations_human.mdl",
        duration     = 1.51,
        targetKMTime = 1.40,
        plyKMTime    = 1.50,
        impactFrac   = 0.62,
        lethal       = true,
        direction    = "right",
        camAngle     = "orbit_action",
        soundSetup   = "player/kick/foot_fire.wav",
        soundImpact  = "player/killmove/km_hit4.wav",
    },
    {
        id           = "killmove_back_1",
        seq          = "killmove_back_1",
        name         = "BSMod Back Execution (Stealth Neck Snap)",
        attModel     = "models/weapons/c_limbs.mdl",
        vicModel     = "models/bsmodimations_human.mdl",
        duration     = 1.61,
        targetKMTime = 1.48,
        plyKMTime    = 1.58,
        impactFrac   = 0.64,
        lethal       = true,
        direction    = "back",
        camAngle     = "over_shoulder",
        soundSetup   = "player/fists/fists_fire01.wav",
        soundImpact  = "player/killmove/km_bonebreak3.wav",
    },
    {
        id           = "killmove_front_air_1",
        seq          = "killmove_front_air_1",
        name         = "BSMod Aerial Dropkick Finisher",
        attModel     = "models/weapons/c_limbs.mdl",
        vicModel     = "models/bsmodimations_human.mdl",
        duration     = 1.51,
        targetKMTime = 1.38,
        plyKMTime    = 1.48,
        impactFrac   = 0.52,
        lethal       = true,
        direction    = "front_air",
        camAngle     = "low_hero",
        soundSetup   = "player/kick/foot_fire.wav",
        soundImpact  = "player/kick/foot_kickbody.wav",
    },
}

-- ============================================================================
-- 6.TEAM COLORS & HELPERS
-- ============================================================================
PF.Teams = {
    [0] = { id = 0, name = "Free-For-All", color = Color(240, 155, 50) },
    [1] = { id = 1, name = "Team 1 (Blue)", color = Color(75, 165, 250) },
    [2] = { id = 2, name = "Team 2 (Red)",  color = Color(240, 75, 75) },
    [3] = { id = 3, name = "Team 3 (Green)",color = Color(80, 215, 115) },
    [4] = { id = 4, name = "Team 4 (Gold)", color = Color(245, 205, 65) },
}

function PF.IsBSModInstalled()
    if ConVarExists("bsmod_killmove_anytime") or ConVarExists("bsmod_punch_damage") or ConVarExists("bsmod_killmove_chance") then
        return true
    end
    if weapons and weapons.GetStored and (weapons.GetStored("weapon_bsmod_punch") or weapons.GetStored("bsmod_punch")) then
        return true
    end
    if isfunction(_G.BSMod_KillMove) or isfunction(_G.PerformKillMove) then
        return true
    end
    return false
end

function PF.GuessNPCClassForModel(mdl)
    mdl = string.lower(tostring(mdl or ""))
    if string.find(mdl, "combine_super_soldier", 1, true) or string.find(mdl, "combine_soldier", 1, true) then
        return "npc_combine_s"
    elseif string.find(mdl, "police", 1, true) or string.find(mdl, "metrocop", 1, true) then
        return "npc_metropolice"
    elseif string.find(mdl, "alyx", 1, true) then
        return "npc_alyx"
    elseif string.find(mdl, "barney", 1, true) then
        return "npc_barney"
    elseif string.find(mdl, "monk", 1, true) then
        return "npc_monk"
    elseif string.find(mdl, "zombine", 1, true) then
        return "npc_zombine"
    elseif string.find(mdl, "zombie_fast", 1, true) then
        return "npc_fastzombie"
    elseif string.find(mdl, "zombie", 1, true) then
        return "npc_zombie"
    elseif string.find(mdl, "antlion", 1, true) then
        return "npc_antlion"
    end
    return "npc_citizen"
end

function PF.DefaultConfig(combatType, fightStyle)
    combatType = PF.CombatTypes[combatType] and combatType or "melee"
    fightStyle = PF.FightStyles[fightStyle] and fightStyle or "cinematic"
    local st = PF.FightStyles[fightStyle]
    local ct = PF.CombatTypes[combatType]

    return {
        combatType       = combatType,
        fightStyle       = fightStyle,
        weaponPreset     = ct.defaultWep,
        timeScale        = st.timeScale,
        bakeTimeStretch  = st.bakeTimeStretch,
        hitStopDuration  = st.hitStopDuration,
        killMoveChance   = st.killMoveChance,
        midFightKillMove = st.midFightKillMove,
        hpMultiplier     = st.hpMultiplier,
        damageMultiplier = st.damageMultiplier,
        choreoCircling   = st.choreoCircling,
        autoDirectorCam  = st.autoDirectorCam,
        keyframeMode     = st.keyframeMode,
        step             = st.step,
        maxDuration      = 25,
        recordWeapons    = true,
        recordSounds     = true,
        recordEffects    = true,
        recordFlex       = true,
        bsmodCompat      = true,
        bsmodSpam        = false,
    }
end
