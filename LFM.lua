-- LFM Addon for WoW 3.3.5 (Wrath of the Lich King)

local LFM = {}
_G["LFM"] = LFM

-- Default options
local DUNGEONS = {
    "Ahn'Kahet",
    "Auchenai Crypts",
    "Azjol-Nerub",
    "Blood Furnance",
    "Botanica",
    "Drak'Tharon",
    "Gundrak",
    "Halls of Lightning",
    "Halls of Stone",
    "Hellfire Ramparts",
    "Mana-Tombs",
    "Mechanar",
    "Nexus",
    "Oculus",
    "Old Hillsbrad Foothills",
    "Sethekk Halls",
    "Shadow Labyrinth",
    "Shattered Halls",
    "Slave Pens",
    "Steamvault",
    "The Arcatraz",
    "Underbog",
    "Utgarde Keep",
    "Utgarde Pinnacle",
    "Violet Hold"
}
table.sort(DUNGEONS)
local MODES = { "HC", "Mythic", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M11", "M12", "M13", "M14", "M15", "M16", "M17", "M18", "M19", "M20", "M21", "M22", "M23", "M24", "M25", "M26", "M27", "M28", "M29", "M30" }

-- Forward declarations
local mainFrame, minimapButton
local tankText, healText, ddText
local dungeonDropDown, modeDropDown, searchButton

-- Format search message according to selection rules
function LFM:FormatSearchMessage()
    local t = (LFM_DB and LFM_DB.tanks_count) or 0
    local h = (LFM_DB and LFM_DB.heals_count) or 0
    local d = (LFM_DB and LFM_DB.dds_count) or 0
    local dungeon = (LFM_DB and LFM_DB.selected_dungeon_raid) or ""
    local mode = (LFM_DB and LFM_DB.selected_mode) or ""

    local roles = {}

    if t > 0 then
        if t == 1 then
            table.insert(roles, "1 Tank")
        else
            table.insert(roles, t .. " Tanks")
        end
    end

    if h > 0 then
        if h == 1 then
            table.insert(roles, "1 Heal")
        else
            table.insert(roles, h .. " Heals")
        end
    end

    if d > 0 then
        if d == 1 then
            table.insert(roles, "1 DD")
        else
            table.insert(roles, d .. " DDs")
        end
    end

    local rolesText = ""
    if #roles == 1 then
        rolesText = roles[1]
    elseif #roles == 2 then
        rolesText = roles[1] .. " and " .. roles[2]
    elseif #roles == 3 then
        rolesText = roles[1] .. ", " .. roles[2] .. " and " .. roles[3]
    end

    return "LF " .. rolesText .. " for " .. dungeon .. " " .. mode
end

-- Check if user can click search button
function LFM:CanSearch()
    local t = (LFM_DB and LFM_DB.tanks_count) or 0
    local h = (LFM_DB and LFM_DB.heals_count) or 0
    local d = (LFM_DB and LFM_DB.dds_count) or 0
    local dungeon = LFM_DB and LFM_DB.selected_dungeon_raid
    local mode = LFM_DB and LFM_DB.selected_mode

    local totalRoles = t + h + d
    local hasDungeon = (dungeon ~= nil and dungeon ~= "")
    local hasMode = (mode ~= nil and mode ~= "")

    return (totalRoles >= 1) and hasDungeon and hasMode
end

-- Update search button enabled/disabled state
function LFM:UpdateSearchButton()
    if not searchButton then return end
    if LFM:CanSearch() then
        searchButton:Enable()
        if searchButton.icon then
            searchButton.icon:SetDesaturated(false)
            searchButton.icon:SetAlpha(1.0)
        end
    else
        searchButton:Disable()
        if searchButton.icon then
            searchButton.icon:SetDesaturated(true)
            searchButton.icon:SetAlpha(0.4)
        end
    end
end

-- Reset session data (wiped on login with character)
function LFM:ResetData()
    LFM_DB = LFM_DB or {}
    LFM_DB.tanks_count = 0
    LFM_DB.heals_count = 0
    LFM_DB.dds_count = 0
    LFM_DB.selected_dungeon_raid = ""
    LFM_DB.selected_mode = ""
    LFM_DB.minimap = LFM_DB.minimap or { minimapPos = 45 }

    if tankText then tankText:SetText("0") end
    if healText then healText:SetText("0") end
    if ddText then ddText:SetText("0") end

    if dungeonDropDown then
        UIDropDownMenu_SetSelectedValue(dungeonDropDown, nil)
        UIDropDownMenu_SetText(dungeonDropDown, "")
    end
    if modeDropDown then
        UIDropDownMenu_SetSelectedValue(modeDropDown, nil)
        UIDropDownMenu_SetText(modeDropDown, "")
    end

    LFM:UpdateSearchButton()
end

-- Minimap button position updater
local function UpdateMinimapButtonPosition()
    if not minimapButton then return end
    local pos = 45
    if LFM_DB and LFM_DB.minimap and LFM_DB.minimap.minimapPos then
        pos = LFM_DB.minimap.minimapPos
    end
    local angle = math.rad(pos)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Create Standalone Minimap Icon
local function CreateMinimapButton()
    if minimapButton then return end
    minimapButton = CreateFrame("Button", "LFM_MinimapButton", Minimap)
    minimapButton:SetWidth(31)
    minimapButton:SetHeight(31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(8)
    minimapButton:RegisterForClicks("AnyUp")

    local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
    overlay:SetWidth(53)
    overlay:SetHeight(53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)

    local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20)
    icon:SetHeight(20)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_PrayerOfHealing")
    icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    icon:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 7, -5)

    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    minimapButton:SetScript("OnClick", function()
        if mainFrame:IsShown() then
            mainFrame:Hide()
        else
            mainFrame:Show()
        end
    end)

    minimapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("LFM")
        GameTooltip:AddLine("Click to open/close LFM window.", 1, 1, 1)
        GameTooltip:Show()
    end)

    minimapButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Make minimap button draggable around minimap
    minimapButton:SetMovable(true)
    minimapButton:RegisterForDrag("LeftButton")
    minimapButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local mx, my = Minimap:GetCenter()
            local dx, dy = cx - mx, cy - my
            local angle = math.deg(math.atan2(dy, dx))
            if angle < 0 then angle = angle + 360 end
            LFM_DB = LFM_DB or {}
            LFM_DB.minimap = LFM_DB.minimap or {}
            LFM_DB.minimap.minimapPos = angle
            UpdateMinimapButtonPosition()
        end)
    end)

    minimapButton:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    UpdateMinimapButtonPosition()
end

-- Initialize Minimap Launcher via LibDBIcon or Standalone
local function InitMinimapIcon()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

    LFM_DB = LFM_DB or {}
    LFM_DB.minimap = LFM_DB.minimap or { minimapPos = 45 }

    if LDB and LDBIcon then
        local LDBObj = LDB:NewDataObject("LFM", {
            type = "launcher",
            label = "LFM",
            icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
            OnClick = function()
                if mainFrame:IsShown() then
                    mainFrame:Hide()
                else
                    mainFrame:Show()
                end
            end,
            OnTooltipShow = function(tooltip)
                if not tooltip or not tooltip.AddLine then return end
                tooltip:AddLine("LFM")
                tooltip:AddLine("|cffffff00Click to open/close LFM window.|r")
            end,
        })
        LDBIcon:Register("LFM", LDBObj, LFM_DB.minimap)
    else
        CreateMinimapButton()
    end
end

-- Create Counter Control (Box + Up/Down arrows)
local function CreateCounterControl(parent, labelText, x, y, getValue, setValue)
    -- Display Box
    local box = CreateFrame("Frame", nil, parent)
    box:SetWidth(36)
    box:SetHeight(32)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    box:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    -- Header Label anchored above the display box
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 4)
    label:SetText(labelText)

    local valueText = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    valueText:SetPoint("CENTER", box, "CENTER", 0, 0)
    valueText:SetText(tostring(getValue()))

    -- Up Arrow Button
    local upBtn = CreateFrame("Button", nil, parent, "UIPanelScrollUpButtonTemplate")
    upBtn:SetWidth(18)
    upBtn:SetHeight(16)
    upBtn:SetPoint("TOPLEFT", box, "TOPRIGHT", 2, 0)
    upBtn:SetScript("OnClick", function()
        local current = getValue()
        if current < 39 then
            setValue(current + 1)
            valueText:SetText(tostring(current + 1))
            LFM:UpdateSearchButton()
        end
    end)

    -- Down Arrow Button
    local downBtn = CreateFrame("Button", nil, parent, "UIPanelScrollDownButtonTemplate")
    downBtn:SetWidth(18)
    downBtn:SetHeight(16)
    downBtn:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 2, 0)
    downBtn:SetScript("OnClick", function()
        local current = getValue()
        if current > 0 then
            setValue(current - 1)
            valueText:SetText(tostring(current - 1))
            LFM:UpdateSearchButton()
        end
    end)

    return valueText
end

-- Create Main Window
local function CreateMainWindow()
    mainFrame = CreateFrame("Frame", "LFM_MainFrame", UIParent)
    mainFrame:SetWidth(620)
    mainFrame:SetHeight(130)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

    -- Re-evaluate search button state whenever mainFrame is shown
    mainFrame:SetScript("OnShow", function()
        LFM:UpdateSearchButton()
    end)

    -- Backdrop
    mainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Add to UISpecialFrames to allow closing with Escape
    tinsert(UISpecialFrames, "LFM_MainFrame")

    -- Title
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", mainFrame, "TOP", 0, -14)
    title:SetText("Looking For")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -6)

    -- Control positions
    local startY = -65

    -- 1. Tank Counter
    tankText = CreateCounterControl(mainFrame, "Tank", 20, startY,
        function() return (LFM_DB and LFM_DB.tanks_count) or 0 end,
        function(v) if LFM_DB then LFM_DB.tanks_count = v end end
    )

    -- 2. Heal Counter
    healText = CreateCounterControl(mainFrame, "Heal", 95, startY,
        function() return (LFM_DB and LFM_DB.heals_count) or 0 end,
        function(v) if LFM_DB then LFM_DB.heals_count = v end end
    )

    -- 3. DD Counter
    ddText = CreateCounterControl(mainFrame, "DD", 170, startY,
        function() return (LFM_DB and LFM_DB.dds_count) or 0 end,
        function(v) if LFM_DB then LFM_DB.dds_count = v end end
    )

    -- 4. Dungeon / Raid Dropdown
    dungeonDropDown = CreateFrame("Frame", "LFM_DungeonDropDown", mainFrame, "UIDropDownMenuTemplate")
    dungeonDropDown:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 230, startY)
    UIDropDownMenu_SetWidth(dungeonDropDown, 130)

    local dungeonLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonLabel:SetPoint("BOTTOMLEFT", dungeonDropDown, "TOPLEFT", 18, 4)
    dungeonLabel:SetText("Dungeon / Raid")

    UIDropDownMenu_Initialize(dungeonDropDown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, name in ipairs(DUNGEONS) do
            info.text = name
            info.value = name
            info.func = function(btn)
                if not LFM_DB then LFM_DB = {} end
                LFM_DB.selected_dungeon_raid = btn.value
                UIDropDownMenu_SetSelectedValue(dungeonDropDown, btn.value)
                UIDropDownMenu_SetText(dungeonDropDown, btn.value)
                LFM:UpdateSearchButton()
                CloseMenus()
            end
            info.checked = (LFM_DB and LFM_DB.selected_dungeon_raid == name)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- 5. Mode Dropdown
    modeDropDown = CreateFrame("Frame", "LFM_ModeDropDown", mainFrame, "UIDropDownMenuTemplate")
    modeDropDown:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 380, startY)
    UIDropDownMenu_SetWidth(modeDropDown, 85)

    local modeLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("BOTTOMLEFT", modeDropDown, "TOPLEFT", 18, 4)
    modeLabel:SetText("Mode")

    UIDropDownMenu_Initialize(modeDropDown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, mode in ipairs(MODES) do
            info.text = mode
            info.value = mode
            info.func = function(btn)
                if not LFM_DB then LFM_DB = {} end
                LFM_DB.selected_mode = btn.value
                UIDropDownMenu_SetSelectedValue(modeDropDown, btn.value)
                UIDropDownMenu_SetText(modeDropDown, btn.value)
                LFM:UpdateSearchButton()
                CloseMenus()
            end
            info.checked = (LFM_DB and LFM_DB.selected_mode == mode)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- 6. Search Icon Button (Standalone icon button without metallic button background)
    searchButton = CreateFrame("Button", "LFM_SearchButton", mainFrame)
    searchButton:SetWidth(32)
    searchButton:SetHeight(32)
    searchButton:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 515, startY)

    local searchIcon = searchButton:CreateTexture(nil, "ARTWORK")
    searchIcon:SetAllPoints(searchButton)
    searchIcon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
    searchIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    searchButton.icon = searchIcon

    searchButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    searchButton:SetScript("OnClick", function()
        if LFM:CanSearch() then
            local msg = LFM:FormatSearchMessage()
            SendChatMessage(msg, "SAY")
        end
    end)

    searchButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Search")
        if not LFM:CanSearch() then
            GameTooltip:AddLine("Select at least 1 role, a Dungeon/Raid, and a Mode.", 1, 0.2, 0.2, true)
        end
        GameTooltip:Show()
    end)

    searchButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Explicitly sync search button state after window creation
    LFM:UpdateSearchButton()

    -- Initially hidden until minimap icon or command opens it
    mainFrame:Hide()
end

-- Event Handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "LFM" then
        LFM:ResetData()
        CreateMainWindow()
        InitMinimapIcon()
    end
end)

-- Slash Command support (/lfm)
SLASH_LFM1 = "/lfm"
SlashCmdList["LFM"] = function()
    if mainFrame then
        if mainFrame:IsShown() then
            mainFrame:Hide()
        else
            mainFrame:Show()
        end
    end
end
