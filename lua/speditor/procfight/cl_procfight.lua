-- ============================================================================
-- GM:FM Procedural Fight Scene — Client Context Menus, State & Viewport HUD
-- Adds "Procedural Fight" to:
--   1. GM:FM Object Right-Click Context Menu (Viewport & ASE Tree)
--   2. Garry's Mod C-Menu Right-Click Entity Context Menu (properties.Add)
--   3. Garry's Mod C-Menu Desktop Bar & GM:FM Top Bar / Timeline
-- ============================================================================
if SERVER then return end

GMFM_ProcFight = GMFM_ProcFight or {}
local PF = GMFM_ProcFight
local COMP = PF.COMP or (SPeditor and SPeditor.Component and SPeditor.Component("procfight"))

PF.ClientConfig = PF.ClientConfig or PF.DefaultConfig("melee", "cinematic")
PF.Roster       = PF.Roster or {}   -- Array of { ent = Entity, uid = number, entIndex = number, name = string, team = number, weapon = string, hp = number }
PF.ActiveState  = PF.ActiveState or { active = false, fighters = {} }
PF.ActiveBanner = nil

local function L(key, fallback)
    if SPeditor and SPeditor.L then
        local v = SPeditor.L(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

-- ============================================================================
-- ROSTER MANAGEMENT (2 OR MORE FIGHTERS)
-- ============================================================================
function PF.CleanRoster()
    local C = SPeditor and SPeditor.Client
    for i = #PF.Roster, 1, -1 do
        local r = PF.Roster[i]
        if not IsValid(r.ent) and r.uid and r.uid > 0 and C and C.Objects then
            for _, obj in ipairs(C.Objects()) do
                if IsValid(obj) and obj:GetNW2Int("SPeditor_UID", 0) == r.uid then
                    r.ent = obj
                    break
                end
            end
        end
        if not IsValid(r.ent) and r.entIndex and r.entIndex > 0 then
            r.ent = Entity(r.entIndex)
        end
        if not IsValid(r.ent) and (not r.uid or r.uid <= 0) then
            table.remove(PF.Roster, i)
        end
    end
end

function PF.IsInRoster(ent)
    if not IsValid(ent) then return false, nil end
    local uid = ent:GetNW2Int("SPeditor_UID", 0)
    local eIdx = ent:EntIndex()
    for i, r in ipairs(PF.Roster) do
        if r.ent == ent or (uid > 0 and r.uid == uid) or (eIdx > 0 and r.entIndex == eIdx) then
            return true, i
        end
    end
    return false, nil
end

function PF.AddToRoster(ent, teamOverride)
    if not IsValid(ent) then return false end
    PF.CleanRoster()
    local exists, idx = PF.IsInRoster(ent)
    if exists then return true, PF.Roster[idx] end

    local uid = ent:GetNW2Int("SPeditor_UID", 0)
    local C = SPeditor and SPeditor.Client
    local name = (C and C.ObjectName and C.ObjectName(ent))
        or ent:GetNW2String("SPeditor_Name", "")
    if name == "" then
        name = string.GetFileFromFilename(ent:GetModel() or "") or ent:GetClass()
        name = string.gsub(name, "%.mdl$", "")
    end

    local defaultTeam = teamOverride
    if defaultTeam == nil then
        defaultTeam = ((#PF.Roster) % 2) + 1
    end

    local entry = {
        ent      = ent,
        uid      = uid,
        entIndex = ent:EntIndex(),
        name     = name,
        model    = ent:GetModel() or "",
        team     = defaultTeam,
        weapon   = "",
        hp       = 100,
    }
    table.insert(PF.Roster, entry)
    if PF.RefreshStudioUI then PF.RefreshStudioUI() end
    return true, entry
end

function PF.RemoveFromRoster(ent)
    local exists, idx = PF.IsInRoster(ent)
    if exists and idx then
        table.remove(PF.Roster, idx)
        if PF.RefreshStudioUI then PF.RefreshStudioUI() end
        return true
    end
    return false
end

function PF.AddSelectedToRoster(clickedEnt)
    local C = SPeditor and SPeditor.Client
    local added = 0
    if IsValid(clickedEnt) then
        if PF.AddToRoster(clickedEnt) then added = added + 1 end
    end
    if C and C.SelectionList then
        for _, e in ipairs(C.SelectionList()) do
            if IsValid(e) and (e:GetClass() == "prop_ragdoll" or e:GetClass() == "prop_dynamic" or e:IsNPC()) then
                if PF.AddToRoster(e) then added = added + 1 end
            end
        end
    end
    if PF.RefreshStudioUI then PF.RefreshStudioUI() end
    return added
end

function PF.AddAllSceneRagdollsToRoster()
    local C = SPeditor and SPeditor.Client
    local list = (C and C.Objects and C.Objects()) or ents.FindByClass("prop_ragdoll")
    local added = 0
    for _, e in ipairs(list) do
        if IsValid(e) and e:GetClass() == "prop_ragdoll" and not (C and C.IsAux and C.IsAux(e)) then
            if PF.AddToRoster(e) then added = added + 1 end
        end
    end
    if PF.RefreshStudioUI then PF.RefreshStudioUI() end
    return added
end

function PF.ApplyStylePresetToConfig(combatType, fightStyle)
    if combatType and PF.CombatTypes[combatType] then
        PF.ClientConfig.combatType = combatType
        PF.ClientConfig.weaponPreset = PF.CombatTypes[combatType].defaultWep
    end
    if fightStyle and PF.FightStyles[fightStyle] then
        PF.ClientConfig.fightStyle = fightStyle
        local st = PF.FightStyles[fightStyle]
        PF.ClientConfig.timeScale        = st.timeScale
        PF.ClientConfig.bakeTimeStretch  = st.bakeTimeStretch
        PF.ClientConfig.hitStopDuration  = st.hitStopDuration
        PF.ClientConfig.killMoveChance   = st.killMoveChance
        PF.ClientConfig.midFightKillMove = st.midFightKillMove
        PF.ClientConfig.hpMultiplier     = st.hpMultiplier
        PF.ClientConfig.damageMultiplier = st.damageMultiplier
        PF.ClientConfig.choreoCircling   = st.choreoCircling
        PF.ClientConfig.autoDirectorCam  = st.autoDirectorCam
        PF.ClientConfig.keyframeMode     = st.keyframeMode
        PF.ClientConfig.step             = st.step
    end
    if PF.RefreshStudioUI then PF.RefreshStudioUI() end
end

-- ============================================================================
-- START / STOP / KILLMOVE CLIENT ACTIONS
-- ============================================================================
function PF.RequestStartFight(combatType, fightStyle, clickedEnt)
    if combatType or fightStyle then
        PF.ApplyStylePresetToConfig(combatType, fightStyle)
    end

    -- Automatically gather selected characters if Roster has fewer than 2 fighters
    PF.CleanRoster()
    if IsValid(clickedEnt) then
        PF.AddToRoster(clickedEnt)
    end
    if #PF.Roster < 2 then
        PF.AddSelectedToRoster(clickedEnt)
    end
    if #PF.Roster < 2 then
        PF.AddAllSceneRagdollsToRoster()
    end

    local specs = {}
    for i, r in ipairs(PF.Roster) do
        table.insert(specs, {
            uid      = IsValid(r.ent) and r.ent:GetNW2Int("SPeditor_UID", r.uid or 0) or (r.uid or 0),
            entIndex = IsValid(r.ent) and r.ent:EntIndex() or (r.entIndex or 0),
            name     = r.name or ("Fighter #" .. i),
            team     = tonumber(r.team) or 0,
            weapon   = r.weapon or "",
            hp       = tonumber(r.hp) or 100,
        })
    end

    net.Start("SPeditor_PF_Start")
    net.WriteString(util.TableToJSON(PF.ClientConfig) or "{}")
    net.WriteString(util.TableToJSON(specs) or "[]")
    net.SendToServer()

    surface.PlaySound("buttons/button9.wav")
end

function PF.RequestStopFight(bake)
    net.Start("SPeditor_PF_Stop")
    net.WriteBool(bake ~= false)
    net.SendToServer()
    surface.PlaySound("buttons/button14.wav")
end

function PF.RequestForceKillMove(kmId)
    net.Start("SPeditor_PF_ForceKillMove")
    net.WriteString(kmId or "")
    net.SendToServer()
    surface.PlaySound("weapons/slam/mine_mode.wav")
end

function PF.RequestSpawnFighter(tplIdx, teamId)
    net.Start("SPeditor_PF_SpawnFighter")
    net.WriteUInt(tplIdx or 1, 8)
    net.WriteUInt(teamId or 1, 4)
    net.SendToServer()
    surface.PlaySound("ui/buttonclick.wav")
end

-- ============================================================================
-- POPULATE GM:FM RIGHT-CLICK CONTEXT MENU SUBMENU
-- ============================================================================
function PF.BuildContextMenuSubmenu(sub, ent)
    PF.CleanRoster()

    -- 1. Primary Action: Start or Stop Fight
    if PF.ActiveState and PF.ActiveState.active then
        sub:AddOption(L("pf.menu.stop_bake", "Stop Fight & Bake to Timeline"), function()
            PF.RequestStopFight(true)
        end):SetIcon("icon16/control_stop_blue.png")

        sub:AddOption(L("pf.menu.trigger_killmove", "Trigger Random KillMove Now!"), function()
            PF.RequestForceKillMove("")
        end):SetIcon("icon16/lightning.png")

        local kmSub, kmOpt = sub:AddSubMenu("Trigger Specific KillMove...")
        kmOpt:SetIcon("icon16/sport_boxing.png")
        for _, km in ipairs(PF.KillMoves) do
            kmSub:AddOption(km.name, function()
                PF.RequestForceKillMove(km.id)
            end):SetIcon("icon16/lightning_go.png")
        end
        sub:AddSpacer()
    else
        local startLabel = string.format("%s [%s - %s]",
            L("pf.menu.quick_start", "Start Procedural Fight Now!"),
            (PF.CombatTypes[PF.ClientConfig.combatType] and PF.CombatTypes[PF.ClientConfig.combatType].shortName or "Melee"),
            (PF.FightStyles[PF.ClientConfig.fightStyle] and PF.FightStyles[PF.ClientConfig.fightStyle].name or "Cinematic")
        )
        sub:AddOption(startLabel, function()
            PF.RequestStartFight(nil, nil, ent)
        end):SetIcon("icon16/control_play_blue.png")

        sub:AddOption(L("pf.menu.preset_melee_spam", "🔥 Melee EXTRA: BSMod Attack Spam (Punch & Kick Frenzy)"), function()
            PF.ClientConfig.bsmodSpam = true
            PF.RequestStartFight("melee", "normal", ent)
        end):SetIcon("icon16/lightning.png")
    end

    -- 2. Open Full Procedural Fight Studio Window
    sub:AddOption(L("pf.menu.open_studio", "Procedural Fight Studio..."), function()
        if IsValid(ent) then PF.AddSelectedToRoster(ent) end
        if PF.OpenStudioWindow then PF.OpenStudioWindow() end
    end):SetIcon("icon16/application_view_tile.png")

    sub:AddSpacer()

    -- 3. Quick Launch Presets: Melee (BSMod Compat) x 3 Pacing Styles + EXTRA BSMod Spam Mode
    local meleeSub, meleeOpt = sub:AddSubMenu("Melee (BSMod KillMoves)  ->  Start Fight")
    meleeOpt:SetIcon("icon16/sport_boxing.png")
    meleeSub:AddOption(L("pf.menu.preset_melee_spam", "🔥 Melee EXTRA: BSMod Attack Spam (Punch & Kick Frenzy)"), function()
        PF.ClientConfig.bsmodSpam = true
        PF.RequestStartFight("melee", "normal", ent)
    end):SetIcon("icon16/lightning.png")
    meleeSub:AddSpacer()
    meleeSub:AddOption(L("pf.menu.preset_melee_cine", "Melee (BSMod KillMoves) — Cinematic"), function()
        PF.ClientConfig.bsmodSpam = false
        PF.RequestStartFight("melee", "cinematic", ent)
    end):SetIcon("icon16/film.png")
    meleeSub:AddOption(L("pf.menu.preset_melee_real", "Melee (BSMod KillMoves) — Realistic"), function()
        PF.ClientConfig.bsmodSpam = false
        PF.RequestStartFight("melee", "realistic", ent)
    end):SetIcon("icon16/shield.png")
    meleeSub:AddOption(L("pf.menu.preset_melee_norm", "Melee (BSMod KillMoves) — Normal"), function()
        PF.ClientConfig.bsmodSpam = false
        PF.RequestStartFight("melee", "normal", ent)
    end):SetIcon("icon16/controller.png")

    -- 4. Quick Launch Presets: Gunfight x 3 Pacing Styles
    local gunSub, gunOpt = sub:AddSubMenu("Gunfight (Firearms AI)  ->  Start Fight")
    gunOpt:SetIcon("icon16/gun.png")
    gunSub:AddOption(L("pf.menu.preset_gun_cine", "Gunfight — Cinematic (Slow & Dramatic)"), function()
        PF.RequestStartFight("gunfight", "cinematic", ent)
    end):SetIcon("icon16/film.png")
    gunSub:AddOption(L("pf.menu.preset_gun_real", "Gunfight — Realistic (Tactical & Lethal)"), function()
        PF.RequestStartFight("gunfight", "realistic", ent)
    end):SetIcon("icon16/shield.png")
    gunSub:AddOption(L("pf.menu.preset_gun_norm", "Gunfight — Normal (Standard AI)"), function()
        PF.RequestStartFight("gunfight", "normal", ent)
    end):SetIcon("icon16/controller.png")

    sub:AddSpacer()

    -- 5. Combat Type Selector (2 Types: Melee BSMod / Gunfight)
    local typeSub, typeOpt = sub:AddSubMenu(L("pf.menu.combat_type", "Combat Mode") .. ": " .. (PF.CombatTypes[PF.ClientConfig.combatType].shortName))
    typeOpt:SetIcon("icon16/wrench.png")
    for _, ctId in ipairs(PF.CombatTypeOrder) do
        local ct = PF.CombatTypes[ctId]
        local prefix = (PF.ClientConfig.combatType == ctId) and "● " or "   "
        typeSub:AddOption(prefix .. ct.name, function()
            PF.ApplyStylePresetToConfig(ctId, nil)
        end):SetIcon(ct.icon)
    end

    -- 6. Procedural Fight Style Selector (3 Styles: Cinematic / Realistic / Normal)
    local styleSub, styleOpt = sub:AddSubMenu(L("pf.menu.fight_style", "Procedural Style") .. ": " .. (PF.FightStyles[PF.ClientConfig.fightStyle].name))
    styleOpt:SetIcon("icon16/film.png")
    for _, stId in ipairs(PF.FightStyleOrder) do
        local st = PF.FightStyles[stId]
        local prefix = (PF.ClientConfig.fightStyle == stId) and "● " or "   "
        styleSub:AddOption(prefix .. st.name .. " — " .. st.badge, function()
            PF.ApplyStylePresetToConfig(nil, stId)
        end):SetIcon(st.icon)
    end

    sub:AddSpacer()

    -- 7. Fighter Roster Management (2 or more characters)
    if IsValid(ent) then
        local inRoster = PF.IsInRoster(ent)
        if inRoster then
            sub:AddOption(L("pf.menu.remove_fighter", "Remove from Procedural Fight Roster"), function()
                PF.RemoveFromRoster(ent)
            end):SetIcon("icon16/user_delete.png")
        else
            sub:AddOption(L("pf.menu.add_fighter", "Add to Procedural Fight Roster"), function()
                PF.AddToRoster(ent)
            end):SetIcon("icon16/user_add.png")
        end
    end

    sub:AddOption(L("pf.menu.add_selected", "Add All Selected Characters to Fight"), function()
        PF.AddSelectedToRoster(ent)
    end):SetIcon("icon16/group_add.png")

    sub:AddOption("Add All Scene Ragdolls to Fight", function()
        PF.AddAllSceneRagdollsToRoster()
    end):SetIcon("icon16/group.png")

    if #PF.Roster > 0 then
        sub:AddOption(string.format("%s (%d Fighters)", L("pf.menu.clear_roster", "Clear Fighter Roster"), #PF.Roster), function()
            PF.Roster = {}
            if PF.RefreshStudioUI then PF.RefreshStudioUI() end
        end):SetIcon("icon16/cross.png")
    end
end

-- ============================================================================
-- REGISTER CONTEXT MENUS IN GM:FM AND GARRY'S MOD C-MENU
-- ============================================================================
if COMP then
    -- 1. GM:FM Object Right-Click Context Menu (Viewport & ASE Object List)
    COMP:AddMenu("object", function(menu, ent)
        local sub, opt = menu:AddSubMenu(L("pf.menu", "Procedural Fight"))
        opt:SetIcon("icon16/sport_boxing.png")
        PF.BuildContextMenuSubmenu(sub, ent)
    end, "ProceduralFight_ObjectMenu")

    -- 2. GM:FM Top Bar "Edit" Menu
    COMP:AddMenu("edit", function(menu)
        local sub, opt = menu:AddSubMenu(L("pf.menu", "Procedural Fight"))
        opt:SetIcon("icon16/sport_boxing.png")
        PF.BuildContextMenuSubmenu(sub, SPeditor.Client and SPeditor.Client.selected)
    end, "ProceduralFight_EditMenu")

    -- 3. GM:FM Top Bar & ASE "+" "Create" Menu
    COMP:AddMenu("create", function(menu)
        local sub, opt = menu:AddSubMenu(L("pf.menu", "Procedural Fight"))
        opt:SetIcon("icon16/sport_boxing.png")
        PF.BuildContextMenuSubmenu(sub, SPeditor.Client and SPeditor.Client.selected)
    end, "ProceduralFight_CreateMenu")

    -- 4. GM:FM "Windows" & "File" Menus
    COMP:AddMenu("windows", function(menu)
        menu:AddOption(L("pf.menu.open_studio", "Procedural Fight Studio..."), function()
            if PF.OpenStudioWindow then PF.OpenStudioWindow() end
        end):SetIcon("icon16/sport_boxing.png")
    end, "ProceduralFight_WindowsMenu")

    COMP:AddMenu("file", function(menu)
        menu:AddOption(L("pf.menu.open_studio", "Procedural Fight Studio..."), function()
            if PF.OpenStudioWindow then PF.OpenStudioWindow() end
        end):SetIcon("icon16/sport_boxing.png")
    end, "ProceduralFight_FileMenu")

    if COMP.AddStatus then
        COMP:AddStatus(function()
            if PF.ActiveState and PF.ActiveState.active then
                local ct = PF.CombatTypes[PF.ActiveState.combatType or "melee"]
                local st = PF.FightStyles[PF.ActiveState.fightStyle or "cinematic"]
                return string.format("REC Procedural Fight [%s • %s]", ct and ct.shortName or "Melee", st and st.name or "Cinematic")
            elseif #PF.Roster > 0 then
                return string.format("Procedural Fight Roster: %d", #PF.Roster)
            end
            return nil
        end)
    end
end

-- 5. Garry's Mod C-Menu Right-Click Entity Property ("Procedural Fight")
properties.Add("gmfm_procedural_fight", {
    MenuLabel = "Procedural Fight (GM:FM)",
    Order     = 150,
    MenuIcon  = "icon16/sport_boxing.png",

    Filter = function(self, ent, ply)
        if not IsValid(ent) then return false end
        if ent:GetClass() == "prop_ragdoll" or ent:GetClass() == "prop_dynamic" or ent:IsNPC() then
            return true
        end
        return false
    end,

    MenuOpen = function(self, option, ent, tr)
        local sub = option:AddSubMenu()
        PF.BuildContextMenuSubmenu(sub, ent)
    end,

    Action = function(self, ent)
        PF.AddToRoster(ent)
        if SPeditor and SPeditor.Client and not SPeditor.Client.active and SPeditor.Client.SendToggle then
            SPeditor.Client.SendToggle(true)
        end
        timer.Simple(0.1, function()
            if PF.OpenStudioWindow then
                PF.OpenStudioWindow()
            end
        end)
    end,
})

-- 6. Garry's Mod C-Menu Top Bar Icon ("Procedural Fight")
list.Set("DesktopWindows", "GMFM_ProceduralFight", {
    title     = "Procedural Fight",
    icon      = "icon64/tool.png",
    width     = 100,
    height    = 100,
    onewindow = false,
    init      = function(icon, window)
        if IsValid(window) then window:Remove() end
        if SPeditor and SPeditor.Client and not SPeditor.Client.active and SPeditor.Client.SendToggle then
            SPeditor.Client.SendToggle(true)
        end
        timer.Simple(0.1, function()
            if PF.OpenStudioWindow then PF.OpenStudioWindow() end
        end)
    end
})

concommand.Add("gmfm_procfight", function()
    if SPeditor and SPeditor.Client and not SPeditor.Client.active and SPeditor.Client.SendToggle then
        SPeditor.Client.SendToggle(true)
    end
    timer.Simple(0.1, function()
        if PF.OpenStudioWindow then PF.OpenStudioWindow() end
    end)
end)

-- ============================================================================
-- NETWORK RECEIVERS (STATE & EVENT BANNERS)
-- ============================================================================
net.Receive("SPeditor_PF_State", function()
    local isActive = net.ReadBool()
    if not isActive then
        PF.ActiveState = { active = false, fighters = {} }
        if PF.RefreshStudioUI then PF.RefreshStudioUI() end
        return
    end

    local combatType  = net.ReadString()
    local fightStyle  = net.ReadString()
    local startTime   = net.ReadFloat()
    local maxDuration = net.ReadFloat()
    local count       = net.ReadUInt(8)
    local fighters    = {}

    for i = 1, count do
        fighters[i] = {
            uid   = net.ReadInt(32),
            name  = net.ReadString(),
            team  = net.ReadUInt(4),
            hp    = net.ReadInt(16),
            maxHP = net.ReadInt(16),
            dead  = net.ReadBool(),
            pos   = net.ReadVector(),
        }
    end

    PF.ActiveState = {
        active      = true,
        combatType  = combatType,
        fightStyle  = fightStyle,
        startTime   = startTime,
        maxDuration = maxDuration,
        fighters    = fighters,
    }
    if PF.RefreshStudioUI then PF.RefreshStudioUI() end
end)

net.Receive("SPeditor_PF_Event", function()
    local evType = net.ReadString()
    local data   = util.JSONToTable(net.ReadString() or "{}") or {}

    if evType == "killmove" then
        PF.ActiveBanner = {
            title     = "KILLMOVE!  " .. tostring(data.name or "Finisher"),
            sub       = string.format("%s  >>>  %s", tostring(data.attacker or "Fighter 1"), tostring(data.victim or "Fighter 2")),
            color     = Color(245, 95, 45),
            untilTime = RealTime() + math.max(2.2, tonumber(data.duration) or 2.0),
        }
        surface.PlaySound("ambient/machines/thumper_hit.wav")
    elseif evType == "ko" then
        PF.ActiveBanner = {
            title     = "KNOCKOUT / ELIMINATED!",
            sub       = string.format("%s defeated %s", tostring(data.attacker or "Fighter"), tostring(data.victim or "Fighter")),
            color     = Color(240, 180, 50),
            untilTime = RealTime() + 2.0,
        }
    elseif evType == "started" then
        local stName = PF.FightStyles[data.fightStyle] and PF.FightStyles[data.fightStyle].badge or "FIGHT"
        local ctName = PF.CombatTypes[data.combatType] and PF.CombatTypes[data.combatType].name or "Combat"
        PF.ActiveBanner = {
            title     = "PROCEDURAL FIGHT STARTED — " .. stName,
            sub       = string.format("%s  |  %d Combatants  |  Recording Keyframes to Timeline...", ctName, tonumber(data.fighters) or 2),
            color     = Color(80, 195, 250),
            untilTime = RealTime() + 2.5,
        }
    elseif evType == "baked" then
        PF.ActiveBanner = {
            title     = "PROCEDURAL FIGHT BAKED TO TIMELINE!",
            sub       = string.format("Recorded %d frames of AI choreography, bones, flexes & sounds.", tonumber(data.frames) or 0),
            color     = Color(90, 220, 125),
            untilTime = RealTime() + 3.2,
        }
        surface.PlaySound("buttons/button14.wav")
    elseif evType == "spawned_fighter" then
        timer.Simple(0.15, function()
            local ent = data.entIndex and Entity(tonumber(data.entIndex) or 0) or nil
            if not IsValid(ent) and SPeditor and SPeditor.Client and SPeditor.Client.Objects and data.uid then
                for _, obj in ipairs(SPeditor.Client.Objects()) do
                    if IsValid(obj) and obj:GetNW2Int("SPeditor_UID", 0) == data.uid then
                        ent = obj
                        break
                    end
                end
            end
            if IsValid(ent) then
                PF.AddToRoster(ent, data.team)
            end
        end)
    end
end)

-- ============================================================================
-- 3D VIEWPORT HELPERS & HUD OVERLAY
-- ============================================================================
hook.Add("GMFM_DrawHelpers3D", "GMFM_ProcFight_Draw3D", function()
    PF.CleanRoster()

    if PF.ActiveState and PF.ActiveState.active then
        local fighters = PF.ActiveState.fighters or {}
        for i, f in ipairs(fighters) do
            if not f.dead and f.pos then
                local teamCfg = PF.Teams[f.team or 0] or PF.Teams[0]
                render.SetColorMaterial()
                render.DrawWireframeSphere(f.pos + Vector(0, 0, 4), 18, 12, 12, teamCfg.color, true)
                for j = i + 1, #fighters do
                    local f2 = fighters[j]
                    if not f2.dead and f2.pos and (f.team == 0 or f.team ~= f2.team) then
                        render.DrawLine(f.pos + Vector(0, 0, 42), f2.pos + Vector(0, 0, 42), Color(255, 90, 60, 120), true)
                    end
                end
            end
        end
    elseif #PF.Roster > 0 then
        for i, r in ipairs(PF.Roster) do
            if IsValid(r.ent) then
                local pos = r.ent:GetPos()
                local teamCfg = PF.Teams[r.team or 0] or PF.Teams[0]
                render.SetColorMaterial()
                render.DrawWireframeSphere(pos + Vector(0, 0, 4), 16, 10, 10, teamCfg.color, true)
            end
        end
    end
end)

local function DrawProcFightOverlay(ix, iy, w, h)
    ix = ix or 0
    iy = iy or 0
    w  = w  or ScrW()
    h  = h  or ScrH()

    -- Draw Active Fight Status Bar & Fighter Health Badges
    if PF.ActiveState and PF.ActiveState.active then
        local st = PF.FightStyles[PF.ActiveState.fightStyle or "cinematic"] or PF.FightStyles.cinematic
        local ct = PF.CombatTypes[PF.ActiveState.combatType or "melee"] or PF.CombatTypes.melee
        local elapsed = math.max(0, CurTime() - (PF.ActiveState.startTime or CurTime()))
        local maxDur  = math.max(1, PF.ActiveState.maxDuration or 25)

        local boxW, boxH = 440, 56
        local bx, by = ix + math.floor((w - boxW) * 0.5), iy + 12
        draw.RoundedBox(6, bx, by, boxW, boxH, Color(18, 20, 26, 230))
        surface.SetDrawColor(st.color.r, st.color.g, st.color.b, 220)
        surface.DrawOutlinedRect(bx, by, boxW, boxH, 2)

        local pulse = math.abs(math.sin(RealTime() * 5))
        draw.RoundedBox(6, bx + 12, by + 12, 12, 12, Color(240, 60, 60, 160 + 95 * pulse))
        draw.SimpleText(
            string.format("REC PROCEDURAL FIGHT  •  %s  •  %s", string.upper(ct.shortName), st.badge),
            "SPeditor.Bold", bx + 32, by + 10, Color(245, 245, 250)
        )
        draw.SimpleText(
            string.format("Elapsed: %.1fs / %.0fs   |   Fighters: %d", elapsed, maxDur, #(PF.ActiveState.fighters or {})),
            "SPeditor.Small", bx + 32, by + 30, Color(185, 195, 210)
        )

        -- Progress bar
        local frac = math.Clamp(elapsed / maxDur, 0, 1)
        surface.SetDrawColor(35, 38, 46, 255)
        surface.DrawRect(bx + 12, by + boxH - 7, boxW - 24, 4)
        surface.SetDrawColor(st.color.r, st.color.g, st.color.b, 255)
        surface.DrawRect(bx + 12, by + boxH - 7, math.floor((boxW - 24) * frac), 4)
    end

    -- Draw KillMove / Combat Event Banner
    if PF.ActiveBanner and RealTime() < (PF.ActiveBanner.untilTime or 0) then
        local b = PF.ActiveBanner
        local bw, bh = 480, 54
        local bx, by = ix + math.floor((w - bw) * 0.5), iy + 76
        draw.RoundedBox(6, bx, by, bw, bh, Color(16, 18, 24, 235))
        surface.SetDrawColor(b.color.r, b.color.g, b.color.b, 240)
        surface.DrawOutlinedRect(bx, by, bw, bh, 2)
        draw.SimpleText(b.title or "", "SPeditor.Bold", bx + bw * 0.5, by + 11, b.color, TEXT_ALIGN_CENTER)
        draw.SimpleText(b.sub or "", "SPeditor.Small", bx + bw * 0.5, by + 31, Color(230, 235, 242), TEXT_ALIGN_CENTER)
    end
end

hook.Add("GMFM_ViewportOverlay", "GMFM_ProcFight_ViewportOverlay", function(view, ix, iy, iw, ih)
    DrawProcFightOverlay(ix, iy, iw, ih)
end)

hook.Add("HUDPaint", "GMFM_ProcFight_HUDPaint", function()
    if SPeditor and SPeditor.Client and SPeditor.Client.active then return end
    if (PF.ActiveState and PF.ActiveState.active) or (PF.ActiveBanner and RealTime() < (PF.ActiveBanner.untilTime or 0)) then
        DrawProcFightOverlay(0, 0, ScrW(), ScrH())
    end
end)
