-- ============================================================================
-- GM:FM Procedural Fight Scene — Studio Window UI & Timeline Toolbar Button
-- ============================================================================
if SERVER then return end

GMFM_ProcFight = GMFM_ProcFight or {}
local PF = GMFM_ProcFight

local function L(key, fallback)
    if SPeditor and SPeditor.L then
        local v = SPeditor.L(key)
        if v and v ~= key then return v end
    end
    return fallback or key
end

function PF.RefreshStudioUI()
    if IsValid(PF.StudioFrame) and isfunction(PF.StudioFrame.RebuildRoster) then
        PF.StudioFrame:RebuildRoster()
    end
    if IsValid(PF.StudioFrame) and isfunction(PF.StudioFrame.SyncControls) then
        PF.StudioFrame:SyncControls()
    end
end

-- ============================================================================
-- OPEN PROCEDURAL FIGHT STUDIO WINDOW
-- ============================================================================
function PF.OpenStudioWindow()
    local UI   = SPeditor and SPeditor.UI
    local Dock = SPeditor and SPeditor.Dock
    if not UI or not Dock then return end

    -- Auto-populate roster from current selection or scene if empty
    PF.CleanRoster()
    if #PF.Roster < 2 then
        PF.AddSelectedToRoster()
    end
    if #PF.Roster < 2 then
        PF.AddAllSceneRagdollsToRoster()
    end

    local old = Dock.ByKey and Dock.ByKey("procfight_studio") or PF.StudioFrame
    if IsValid(old) then
        old:Remove()
    end

    local fw, fh = math.min(640, ScrW() - 60), math.min(740, ScrH() - 80)
    local win, body = Dock.Create({
        key      = "procfight_studio",
        id       = "procfight_studio",
        title    = L("pf.ui.title", "GM:FM Procedural Fight Studio"),
        w        = fw,
        h        = fh,
        x        = math.floor((ScrW() - fw) * 0.5),
        y        = math.max(34, math.floor((ScrH() - fh) * 0.5)),
        dockable = false,
        icon     = "icon16/sport_boxing.png",
    })
    if not IsValid(win) or not IsValid(body) then return end

    win.minW, win.minH = UI.S(520), UI.S(480)
    local baseRemove = win.OnRemove
    win.OnRemove = function(s)
        if baseRemove then baseRemove(s) end
        if Dock.pages then Dock.pages.procfight_studio = nil end
    end

    PF.StudioFrame = win
    local COL = UI.PAL or {}
    local colText    = COL.TEXT   or Color(214, 214, 214)
    local colTextHi  = Color(242, 244, 248)
    local colTextDim = COL.DIM    or Color(150, 150, 152)
    local colBorder  = COL.BORDER or Color(34, 32, 33)

    -- ========================================================================
    -- ACTION FOOTER (DOCKED AT BOTTOM FIRST SO FILL SCROLL TAKES REMAINDER)
    -- ========================================================================
    local footer = vgui.Create("DPanel", body)
    footer:Dock(BOTTOM)
    footer:SetTall(UI.S(48))
    footer:DockMargin(8, 4, 8, 8)
    footer.Paint = function() end

    local btnMain = vgui.Create("DButton", footer)
    btnMain:SetText("")
    btnMain:SetCursor("hand")

    local btnKillMoveNow = vgui.Create("DButton", footer)
    btnKillMoveNow:SetText("")
    btnKillMoveNow:SetCursor("hand")

    function btnMain:Paint(w, h)
        local isRunning = (PF.ActiveState and PF.ActiveState.active)
        local hov = self:IsHovered()
        local bg = isRunning
            and (hov and Color(220, 65, 65, 255) or Color(185, 48, 48, 255))
            or  (hov and Color(60, 175, 95, 255)  or Color(46, 145, 76, 255))
        draw.RoundedBox(4, 0, 0, w, h, bg)
        surface.SetDrawColor(255, 255, 255, 40)
        surface.DrawOutlinedRect(0, 0, w, h)

        local label = isRunning
            and L("pf.ui.stop_btn", "■  STOP FIGHT & BAKE KEYFRAMES TO TIMELINE")
            or  string.format("▶  %s  (%s • %s)",
                    L("pf.ui.start_btn", "START PROCEDURAL FIGHT"),
                    string.upper(PF.CombatTypes[PF.ClientConfig.combatType].shortName),
                    string.upper(PF.FightStyles[PF.ClientConfig.fightStyle].name)
                )
        draw.SimpleText(label, "SPeditor.Bold", w * 0.5, h * 0.5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    function btnMain:DoClick()
        if PF.ActiveState and PF.ActiveState.active then
            PF.RequestStopFight(true)
        else
            PF.RequestStartFight()
        end
    end

    function btnKillMoveNow:Paint(w, h)
        local isRunning = (PF.ActiveState and PF.ActiveState.active)
        local hov = self:IsHovered()
        local bg = isRunning
            and (hov and Color(240, 130, 45, 255) or Color(205, 105, 35, 255))
            or  (hov and Color(85, 70, 50, 230)   or Color(62, 54, 45, 210))
        draw.RoundedBox(4, 0, 0, w, h, bg)
        surface.SetDrawColor(255, 255, 255, isRunning and 45 or 25)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText(
            "⚡ KILLMOVE!",
            "SPeditor.Bold",
            w * 0.5, h * 0.5,
            Color(255, 235, 210),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end

    function btnKillMoveNow:DoClick()
        if PF.ActiveState and PF.ActiveState.active then
            PF.RequestForceKillMove("")
        else
            PF.RequestStartFight("melee", "cinematic")
            timer.Simple(0.8, function()
                if PF.ActiveState and PF.ActiveState.active then
                    PF.RequestForceKillMove("")
                end
            end)
        end
    end

    function footer:PerformLayout(w, h)
        local kmW = UI.S(136)
        btnMain:SetPos(0, 0)
        btnMain:SetSize(w - kmW - 6, h)
        btnKillMoveNow:SetPos(w - kmW, 0)
        btnKillMoveNow:SetSize(kmW, h)
    end

    -- ========================================================================
    -- MAIN SCROLL BODY
    -- ========================================================================
    local scroll = vgui.Create("DScrollPanel", body)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 6, 8, 4)
    if UI.StyleScroll then UI.StyleScroll(scroll) end

    local function AddSectionHeader(text, accentColor)
        local p = vgui.Create("DPanel", scroll)
        p:Dock(TOP)
        p:SetTall(UI.S(24))
        p:DockMargin(0, 6, 0, 4)
        function p:Paint(w, h)
            surface.SetDrawColor(COL.HEADER or Color(71, 69, 70))
            surface.DrawRect(0, 0, w, h)
            local ac = accentColor or COL.ORANGE or Color(233, 145, 45)
            surface.SetDrawColor(ac.r, ac.g, ac.b, 255)
            surface.DrawRect(0, 0, 4, h)
            draw.SimpleText(text, "SPeditor.Bold", 10, h * 0.5, colTextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return p
    end

    -- ========================================================================
    -- 1. COMBAT TYPE SELECTOR (Melee BSMod vs Gunfight)
    -- ========================================================================
    AddSectionHeader(L("pf.ui.combat_header", "1. Combat Type (Melee BSMod KillMoves vs Gunfight)"), Color(235, 110, 50))

    local typeRow = vgui.Create("DPanel", scroll)
    typeRow:Dock(TOP)
    typeRow:SetTall(UI.S(68))
    typeRow:DockMargin(0, 0, 0, 4)
    typeRow.Paint = function() end

    local typeBtns = {}
    for _, ctId in ipairs(PF.CombatTypeOrder) do
        local ct = PF.CombatTypes[ctId]
        local b = vgui.Create("DButton", typeRow)
        b:SetText("")
        b:SetCursor("hand")
        typeBtns[ctId] = b

        function b:Paint(w, h)
            local active = (PF.ClientConfig.combatType == ctId)
            local hov = self:IsHovered()
            local bg = active and Color(46, 52, 64, 255) or (hov and Color(64, 62, 66, 255) or (COL.ROW_B or Color(53, 51, 52)))
            draw.RoundedBox(4, 0, 0, w, h, bg)

            local borderCol = active and ct.color or colBorder
            surface.SetDrawColor(borderCol.r, borderCol.g, borderCol.b, active and 255 or 180)
            surface.DrawOutlinedRect(0, 0, w, h, active and 2 or 1)

            if active then
                surface.SetDrawColor(ct.color.r, ct.color.g, ct.color.b, 255)
                surface.DrawRect(0, 0, 4, h)
            end

            draw.SimpleText(ct.name, "SPeditor.Bold", 12, UI.S(10), active and ct.color or colTextHi)
            draw.SimpleText(
                ctId == "melee"
                    and "Hand-to-hand & melee weapons + Random BSMod KillMoves"
                    or  "Firearm shootouts with cover, strafing, tracers & reloads",
                "SPeditor.Small", 12, UI.S(29), colText
            )
            local bsBadge = (ctId == "melee")
                and (PF.IsBSModInstalled() and "✓ BSMod Detected + 8 Built-in KillMoves" or "✓ 8 Built-in BSMod-Style KillMoves Ready")
                or  "✓ Supports SMG1, AR2, Shotgun, Pistol, .357, Crossbow"
            draw.SimpleText(bsBadge, "SPeditor.Small", 12, UI.S(46), active and Color(130, 220, 150) or colTextDim)
        end

        function b:DoClick()
            PF.ApplyStylePresetToConfig(ctId, nil)
            surface.PlaySound("ui/buttonclick.wav")
        end
    end

    function typeRow:PerformLayout(w, h)
        local half = math.floor((w - 6) * 0.5)
        if IsValid(typeBtns["melee"]) then
            typeBtns["melee"]:SetPos(0, 0)
            typeBtns["melee"]:SetSize(half, h)
        end
        if IsValid(typeBtns["gunfight"]) then
            typeBtns["gunfight"]:SetPos(half + 6, 0)
            typeBtns["gunfight"]:SetSize(w - half - 6, h)
        end
    end

    -- ========================================================================
    -- 2. PROCEDURAL FIGHT STYLE SELECTOR (Cinematic / Realistic / Normal)
    -- ========================================================================
    AddSectionHeader(L("pf.ui.style_header", "2. Procedural Fight Style (Cinematic / Realistic / Normal)"), Color(245, 185, 55))

    local styleRow = vgui.Create("DPanel", scroll)
    styleRow:Dock(TOP)
    styleRow:SetTall(UI.S(76))
    styleRow:DockMargin(0, 0, 0, 4)
    styleRow.Paint = function() end

    local styleBtns = {}
    for _, stId in ipairs(PF.FightStyleOrder) do
        local st = PF.FightStyles[stId]
        local b = vgui.Create("DButton", styleRow)
        b:SetText("")
        b:SetCursor("hand")
        styleBtns[stId] = b

        function b:Paint(w, h)
            local active = (PF.ClientConfig.fightStyle == stId)
            local hov = self:IsHovered()
            local bg = active and Color(46, 52, 64, 255) or (hov and Color(64, 62, 66, 255) or (COL.ROW_B or Color(53, 51, 52)))
            draw.RoundedBox(4, 0, 0, w, h, bg)

            surface.SetDrawColor(st.color.r, st.color.g, st.color.b, active and 255 or 110)
            surface.DrawOutlinedRect(0, 0, w, h, active and 2 or 1)

            if active then
                surface.SetDrawColor(st.color.r, st.color.g, st.color.b, 255)
                surface.DrawRect(0, 0, w, 3)
            end

            draw.SimpleText(st.name, "SPeditor.Bold", 10, UI.S(8), active and st.color or colTextHi)
            draw.SimpleText(st.badge, "SPeditor.Small", 10, UI.S(25), active and colTextHi or colTextDim)

            local descLine1, descLine2
            if stId == "cinematic" then
                descLine1 = "Slow-Mo + Choreographed"
                descLine2 = "Hit-Stop & Dynamic Cam"
            elseif stId == "realistic" then
                descLine1 = "1.0x Speed + High Damage"
                descLine2 = "Tactical & Ragdoll Deaths"
            else
                descLine1 = "Standard GMod AI Speed"
                descLine2 = "Balanced Arcade Combat"
            end
            draw.SimpleText(descLine1, "SPeditor.Small", 10, UI.S(42), colText)
            draw.SimpleText(descLine2, "SPeditor.Small", 10, UI.S(56), colTextDim)
        end

        function b:DoClick()
            PF.ApplyStylePresetToConfig(nil, stId)
            surface.PlaySound("ui/buttonclick.wav")
        end
    end

    function styleRow:PerformLayout(w, h)
        local gap = 6
        local cw = math.floor((w - gap * 2) / 3)
        for i, stId in ipairs(PF.FightStyleOrder) do
            local btn = styleBtns[stId]
            if IsValid(btn) then
                local x = (i - 1) * (cw + gap)
                local bw = (i == 3) and (w - x) or cw
                btn:SetPos(x, 0)
                btn:SetSize(bw, h)
            end
        end
    end

    -- ========================================================================
    -- 3. FIGHTERS ROSTER (2 OR MORE CHARACTERS)
    -- ========================================================================
    AddSectionHeader(L("pf.ui.roster", "3. Fighters Roster (2 or more characters — Teams or Free-For-All)"), Color(80, 175, 250))

    local rosterToolbar = vgui.Create("DPanel", scroll)
    rosterToolbar:Dock(TOP)
    rosterToolbar:SetTall(UI.S(28))
    rosterToolbar:DockMargin(0, 0, 0, 4)
    rosterToolbar.Paint = function() end

    local btnAddSel = UI.Button(rosterToolbar, L("pf.ui.add_sel", "+ Add Selected"), "icon16/group_add.png", function()
        PF.AddSelectedToRoster()
    end)
    btnAddSel:Dock(LEFT)
    btnAddSel:SetWide(UI.S(130))
    btnAddSel:DockMargin(0, 2, 4, 2)

    local btnAddScene = UI.Button(rosterToolbar, L("pf.ui.add_all_scene", "+ Add Scene Ragdolls"), "icon16/group.png", function()
        PF.AddAllSceneRagdollsToRoster()
    end)
    btnAddScene:Dock(LEFT)
    btnAddScene:SetWide(UI.S(155))
    btnAddScene:DockMargin(0, 2, 4, 2)

    local btnSpawn = UI.Button(rosterToolbar, L("pf.ui.spawn_npc", "+ Spawn Fighter..."), "icon16/user_add.png", function()
        local m = UI.Menu and UI.Menu() or DermaMenu()
        for idx, tpl in ipairs(PF.FighterTemplates) do
            local teamInfo = PF.Teams[tpl.team or 1]
            m:AddOption(string.format("%s  [%s]", tpl.name, teamInfo and teamInfo.name or "Team 1"), function()
                PF.RequestSpawnFighter(idx, tpl.team or 1)
            end):SetIcon("icon16/user_add.png")
        end
        m:Open()
    end)
    btnSpawn:Dock(LEFT)
    btnSpawn:SetWide(UI.S(140))
    btnSpawn:DockMargin(0, 2, 4, 2)

    local btnAllFFA = UI.Button(rosterToolbar, "Free-For-All", nil, function()
        for _, r in ipairs(PF.Roster) do r.team = 0 end
        PF.RefreshStudioUI()
    end)
    btnAllFFA:Dock(LEFT)
    btnAllFFA:SetWide(UI.S(95))
    btnAllFFA:DockMargin(0, 2, 4, 2)

    local btnClear = UI.Button(rosterToolbar, L("pf.ui.clear", "Clear"), "icon16/cross.png", function()
        PF.Roster = {}
        PF.RefreshStudioUI()
    end)
    btnClear:Dock(RIGHT)
    btnClear:SetWide(UI.S(72))
    btnClear:DockMargin(4, 2, 0, 2)

    local rosterContainer = vgui.Create("DPanel", scroll)
    rosterContainer:Dock(TOP)
    rosterContainer:SetTall(UI.S(132))
    rosterContainer:DockMargin(0, 0, 0, 6)
    function rosterContainer:Paint(w, h)
        surface.SetDrawColor(COL.LIST_BG or Color(48, 47, 48))
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colBorder)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    local rosterScroll = vgui.Create("DScrollPanel", rosterContainer)
    rosterScroll:Dock(FILL)
    rosterScroll:DockMargin(4, 4, 4, 4)
    if UI.StyleScroll then UI.StyleScroll(rosterScroll) end

    function win:RebuildRoster()
        if not IsValid(rosterScroll) then return end
        rosterScroll:Clear()
        PF.CleanRoster()

        if #PF.Roster == 0 then
            local empty = vgui.Create("DPanel", rosterScroll)
            empty:Dock(TOP)
            empty:SetTall(UI.S(110))
            function empty:Paint(w, h)
                draw.SimpleText("No fighters in roster yet (will auto-select or spawn on Start).", "SPeditor.Bold", w * 0.5, h * 0.38, colText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText("Select 2+ characters and click '+ Add Selected', or click '+ Spawn Fighter...'", "SPeditor.Small", w * 0.5, h * 0.62, colTextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            return
        end

        for i, r in ipairs(PF.Roster) do
            local row = vgui.Create("DPanel", rosterScroll)
            row:Dock(TOP)
            row:SetTall(UI.S(30))
            row:DockMargin(0, 0, 0, 3)

            local teamCfg = PF.Teams[r.team or 0] or PF.Teams[0]
            function row:Paint(w, h)
                surface.SetDrawColor((i % 2 == 0) and (COL.ROW_A or Color(61, 59, 60)) or (COL.ROW_B or Color(53, 51, 52)))
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(teamCfg.color.r, teamCfg.color.g, teamCfg.color.b, 255)
                surface.DrawRect(0, 0, 4, h)
                draw.SimpleText(string.format("#%d  %s", i, r.name or "Fighter"), "SPeditor.Bold", 12, h * 0.5, colTextHi, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            local btnDel = UI.Button(row, "✕", nil, function()
                table.remove(PF.Roster, i)
                win:RebuildRoster()
            end)
            btnDel:Dock(RIGHT)
            btnDel:SetWide(UI.S(26))
            btnDel:DockMargin(4, 3, 4, 3)

            -- Individual Weapon Override Selector
            local wepLabel = (r.weapon and r.weapon ~= "") and string.gsub(r.weapon, "^weapon_", "") or "Default Wep"
            local wepBtn = UI.Button(row, wepLabel, nil, function()
                local m = UI.Menu and UI.Menu() or DermaMenu()
                m:AddOption("Use Mode Default Weapon", function()
                    r.weapon = ""
                    win:RebuildRoster()
                end)
                m:AddSpacer()
                for _, wp in ipairs(PF.WeaponPresets) do
                    m:AddOption(wp.name, function()
                        r.weapon = wp.id
                        win:RebuildRoster()
                    end)
                end
                m:Open()
            end)
            wepBtn:Dock(RIGHT)
            wepBtn:SetWide(UI.S(105))
            wepBtn:DockMargin(4, 3, 0, 3)

            -- Team Selector Button
            local teamBtn = UI.Button(row, teamCfg.name, nil, function()
                local m = UI.Menu and UI.Menu() or DermaMenu()
                for tId = 0, 4 do
                    local tc = PF.Teams[tId]
                    m:AddOption(tc.name, function()
                        r.team = tId
                        win:RebuildRoster()
                    end)
                end
                m:Open()
            end)
            teamBtn:Dock(RIGHT)
            teamBtn:SetWide(UI.S(120))
            teamBtn:DockMargin(4, 3, 0, 3)
        end
    end

    -- ========================================================================
    -- 4. CHOREOGRAPHY, KILLMOVES & CINEMATIC SETTINGS
    -- ========================================================================
    AddSectionHeader(L("pf.ui.settings_header", "4. Choreography, BSMod KillMoves & Cinematic Camera Settings"), Color(120, 215, 145))

    local settingsPanel = vgui.Create("DPanel", scroll)
    settingsPanel:Dock(TOP)
    settingsPanel:SetTall(UI.S(254))
    settingsPanel:DockMargin(0, 0, 0, 6)
    function settingsPanel:Paint(w, h)
        surface.SetDrawColor(COL.LIST_BG or Color(48, 47, 48))
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colBorder)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    local slKillMove = UI.Slider(
        settingsPanel,
        L("pf.ui.killmove_chance", "Random KillMove Chance (%) [Melee BSMod]"),
        0, 100, 0,
        PF.ClientConfig.killMoveChance or 65,
        function(v) PF.ClientConfig.killMoveChance = v end
    )

    local slTimeScale = UI.Slider(
        settingsPanel,
        L("pf.ui.cinematic_speed", "Live Simulation Speed (Time Scale)"),
        0.25, 1.00, 2,
        PF.ClientConfig.timeScale or 0.85,
        function(v) PF.ClientConfig.timeScale = v end
    )

    local slBakeStretch = UI.Slider(
        settingsPanel,
        L("pf.ui.time_stretch", "Timeline Bake Stretch (Slower Playback in GM:FM)"),
        0.50, 2.50, 2,
        PF.ClientConfig.bakeTimeStretch or 1.35,
        function(v) PF.ClientConfig.bakeTimeStretch = v end
    )

    local slDuration = UI.Slider(
        settingsPanel,
        L("pf.ui.duration", "Max Fight Duration (seconds)"),
        5, 90, 0,
        PF.ClientConfig.maxDuration or 25,
        function(v) PF.ClientConfig.maxDuration = v end
    )

    local slStep = UI.Slider(
        settingsPanel,
        L("pf.ui.step", "Keyframe Sample Step (frames, 1 = smoothest)"),
        1, 5, 0,
        PF.ClientConfig.step or 1,
        function(v) PF.ClientConfig.step = math.Round(v) end
    )

    local chkBSModSpam = UI.Check(settingsPanel, L("pf.ui.bsmod_spam", "🔥 EXTRA: BSMod Attack Spam Mode (Punch & Kick Barrage)"), PF.ClientConfig.bsmodSpam, function(v)
        PF.ClientConfig.bsmodSpam = v
    end)
    local chkAutoCam = UI.Check(settingsPanel, L("pf.ui.auto_director", "Auto-Director Camera & Dynamic Timeline Cuts"), PF.ClientConfig.autoDirectorCam, function(v)
        PF.ClientConfig.autoDirectorCam = v
    end)
    local chkMidKill = UI.Check(settingsPanel, L("pf.ui.killmove_midfight", "Allow Non-Lethal / Mid-Fight KillMoves"), PF.ClientConfig.midFightKillMove, function(v)
        PF.ClientConfig.midFightKillMove = v
    end)
    local chkWeapons = UI.Check(settingsPanel, L("pf.ui.record_weapons", "Record Weapons, Muzzle Flashes & Blood Effects"), PF.ClientConfig.recordWeapons, function(v)
        PF.ClientConfig.recordWeapons = v
        PF.ClientConfig.recordEffects = v
    end)
    local chkSounds = UI.Check(settingsPanel, L("pf.ui.record_sounds", "Record Combat Sounds & Facial Expressions"), PF.ClientConfig.recordSounds, function(v)
        PF.ClientConfig.recordSounds = v
        PF.ClientConfig.recordFlex   = v
    end)

    function win:SyncControls()
        if IsValid(slKillMove) and slKillMove.SetValue then slKillMove:SetValue(PF.ClientConfig.killMoveChance or 65) end
        if IsValid(slTimeScale) and slTimeScale.SetValue then slTimeScale:SetValue(PF.ClientConfig.timeScale or 0.85) end
        if IsValid(slBakeStretch) and slBakeStretch.SetValue then slBakeStretch:SetValue(PF.ClientConfig.bakeTimeStretch or 1.35) end
        if IsValid(slDuration) and slDuration.SetValue then slDuration:SetValue(PF.ClientConfig.maxDuration or 25) end
        if IsValid(slStep) and slStep.SetValue then slStep:SetValue(PF.ClientConfig.step or 1) end
        if IsValid(chkBSModSpam) and chkBSModSpam.SetValue then chkBSModSpam:SetValue(PF.ClientConfig.bsmodSpam and 1 or 0) end
        if IsValid(chkAutoCam) and chkAutoCam.SetValue then chkAutoCam:SetValue(PF.ClientConfig.autoDirectorCam and 1 or 0) end
        if IsValid(chkMidKill) and chkMidKill.SetValue then chkMidKill:SetValue(PF.ClientConfig.midFightKillMove and 1 or 0) end
        if IsValid(chkWeapons) and chkWeapons.SetValue then chkWeapons:SetValue(PF.ClientConfig.recordWeapons and 1 or 0) end
        if IsValid(chkSounds)  and chkSounds.SetValue  then chkSounds:SetValue(PF.ClientConfig.recordSounds and 1 or 0) end
    end

    win:RebuildRoster()
    win:SyncControls()
    return win
end

-- ============================================================================
-- INJECT "PROCEDURAL FIGHT" ICON BUTTON INTO GM:FM TIMELINE TOOLBAR
-- ============================================================================
local function TryInjectTimelineButton()
    local Dock = SPeditor and SPeditor.Dock
    local UI   = SPeditor and SPeditor.UI
    if not Dock or not Dock.pages or not UI or not UI.IconButton then return end

    local pg = Dock.pages["sa_timeline"]
    local panel = pg and pg.panel
    if not IsValid(panel) then return end
    if IsValid(panel.PF_QuickBtn) then return end

    -- Find the top toolbar inside sa_timeline page
    local children = panel:GetChildren()
    local bar = children and children[1]
    if not IsValid(bar) then return end

    local bFight = UI.IconButton(
        bar,
        "icon16/sport_boxing.png",
        "Procedural Fight (Melee BSMod KillMoves / Gunfight)",
        function()
            local m = UI.Menu and UI.Menu() or DermaMenu()
            PF.BuildContextMenuSubmenu(m, SPeditor.Client and SPeditor.Client.selected)
            m:Open()
        end,
        function()
            return (PF.ActiveState and PF.ActiveState.active) or IsValid(PF.StudioFrame)
        end
    )
    panel.PF_QuickBtn = bFight
end

hook.Add("SPeditor_StateChanged", "GMFM_ProcFight_InjectTimelineBtn", function(active)
    if active then
        timer.Simple(0.15, TryInjectTimelineButton)
    end
end)

hook.Add("Think", "GMFM_ProcFight_EnsureTimelineBtn", function()
    if SPeditor and SPeditor.Client and SPeditor.Client.active then
        local Dock = SPeditor.Dock
        local pg = Dock and Dock.pages and Dock.pages["sa_timeline"]
        if pg and IsValid(pg.panel) and not IsValid(pg.panel.PF_QuickBtn) then
            TryInjectTimelineButton()
        end
    end
end)
