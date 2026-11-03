-- ============================================================================
-- GM:FM Procedural Fight Scene — Main Bootstrap Loader
-- Supports 2+ Fighters, Melee (BSMod Compat + Random KillMoves) & Gunfight,
-- and 3 Pacing Modes: Cinematic, Realistic, Normal
-- ============================================================================
if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("speditor/procfight/component.lua")
    AddCSLuaFile("speditor/procfight/sh_procfight.lua")
    AddCSLuaFile("speditor/procfight/cl_procfight.lua")
    AddCSLuaFile("speditor/procfight/cl_procfight_ui.lua")

    -- Register network strings upfront at autorun time
    local netStrings = {
        "SPeditor_PF_Start",
        "SPeditor_PF_Stop",
        "SPeditor_PF_ForceKillMove",
        "SPeditor_PF_SpawnFighter",
        "SPeditor_PF_CMenuAction",
        "SPeditor_PF_State",
        "SPeditor_PF_Event",
    }
    for _, name in ipairs(netStrings) do
        util.AddNetworkString(name)
    end
end

GMFM_ProcFight = GMFM_ProcFight or {}

local function LoadProcFightComponent()
    if not SPeditor or not SPeditor.Component then return false end
    if GMFM_ProcFight._loaded then return true end
    GMFM_ProcFight._loaded = true

    if SPeditor.Components and isfunction(SPeditor.Components.Load) then
        SPeditor.Components.Load("procfight")
    else
        include("speditor/procfight/sh_procfight.lua")
        if SERVER then
            include("speditor/procfight/sv_procfight_killmoves.lua")
            include("speditor/procfight/sv_procfight_ai.lua")
            include("speditor/procfight/sv_procfight_director.lua")
            include("speditor/procfight/sv_procfight.lua")
        else
            include("speditor/procfight/cl_procfight.lua")
            include("speditor/procfight/cl_procfight_ui.lua")
        end
    end
    return true
end

-- If GM:FM is already loaded, initialize immediately
if SPeditor and SPeditor.Component then
    LoadProcFightComponent()
end

-- Hook into GM:FM and GMod lifecycle events so load order never matters
hook.Add("SPeditor_LanguagesLoaded", "GMFM_ProcFight_OnLanguagesLoaded", function()
    LoadProcFightComponent()
end)

hook.Add("GMFM_Loaded", "GMFM_ProcFight_OnLoaded", function()
    LoadProcFightComponent()
end)

hook.Add("Initialize", "GMFM_ProcFight_Initialize", function()
    local precacheMdls = {
        "models/weapons/c_limbs.mdl",
        "models/bsmodimations_human.mdl",
        "models/bsmodimations_hunter.mdl",
        "models/player/kleiner.mdl",
        "models/player/alyx.mdl",
        "models/humans/group03/male_07.mdl",
        "models/humans/group03/female_01.mdl",
        "models/combine_soldier.mdl",
    }
    for _, m in ipairs(precacheMdls) do
        if util.IsValidModel(m) then
            util.PrecacheModel(m)
        end
    end

    if not LoadProcFightComponent() then
        if file.Exists("autorun/speditor_init.lua", "LUA") then
            include("autorun/speditor_init.lua")
            LoadProcFightComponent()
        end
    end
end)

hook.Add("InitPostEntity", "GMFM_ProcFight_InitPostEntity", function()
    LoadProcFightComponent()
end)
