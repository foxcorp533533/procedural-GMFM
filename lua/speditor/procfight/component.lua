-- ============================================================================
-- GM:FM Component Manifest: Procedural Fight Scene (procfight)
-- ============================================================================
return {
    name   = "Procedural Fight",
    net    = {
        "Start",
        "Stop",
        "ForceKillMove",
        "SpawnFighter",
        "CMenuAction",
        "State",
        "Event",
    },
    shared = {
        "sh_procfight.lua",
    },
    server = {
        "sv_procfight_killmoves.lua",
        "sv_procfight_ai.lua",
        "sv_procfight_director.lua",
        "sv_procfight.lua",
    },
    client = {
        "cl_procfight.lua",
        "cl_procfight_ui.lua",
    },
}
