-- LFM Addon for WoW 3.3.5 (Wrath of the Lich King)

local LFM = {}
_G["LFM"] = LFM

-- Default options: Map object with uiName and apiName
local DUNGEONS = {
    { uiName = "Ahn'Kahet", apiName = "Ahn'kahet: The Old Kingdom" },
    { uiName = "Azjol-Nerub", apiName = "Azjol-Nerub" },
    { uiName = "Arcatraz", apiName = "The Arcatraz" },
    { uiName = "Mechanar", apiName = "The Mechanar" },
    { uiName = "Botanica", apiName = "The Botanica" },
    { uiName = "Auchenai Crypts", apiName = "Auchenai Crypts" },
    { uiName = "Mana-Tombs", apiName = "Mana-Tombs" },
    { uiName = "Sethekk Halls", apiName = "Sethekk Halls" },
    { uiName = "Shadow Labyrinth", apiName = "Shadow Labyrinth" },
    { uiName = "Blood Furnance", apiName = "Hellfire Citadel: The Blood Furnace" },
    { uiName = "Hellfire Ramparts", apiName = "Hellfire Citadel: Ramparts" },
    { uiName = "Shattered Halls", apiName = "The Shattered Halls" },
    { uiName = "Drak'Tharon", apiName = "Drak'Tharon Keep" },
    { uiName = "Gundrak", apiName = "Gundrak" },
    { uiName = "Halls of Lightning", apiName = "Halls of Lightning" },
    { uiName = "Halls of Stone", apiName = "Halls of Stone" },
    { uiName = "Nexus", apiName = "The Nexus" },
    { uiName = "Oculus", apiName = "The Oculus" },
    { uiName = "Slave Pens", apiName = "The Slave Pens" },
    { uiName = "Steamvault", apiName = "The Steamvault" },
    { uiName = "Underbog", apiName = "The Underbog" },
    { uiName = "Utgarde Keep", apiName = "Utgarde Keep" },
    { uiName = "Utgarde Pinnacle", apiName = "Utgarde Pinnacle" },
    { uiName = "Violet Hold", apiName = "The Violet Hold" },
    { uiName = "Stonecore", apiName = "The Stonecore" },
    { uiName = "Tol Vir", apiName = "Lost City of the Tol'vir" },
}

local MODES = { "HC", "Mythic", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M11", "M12", "M13", "M14", "M15", "M16", "M17", "M18", "M19", "M20", "M21", "M22", "M23", "M24", "M25", "M26", "M27", "M28", "M29", "M30" }

-- Forward declarations
local mainFrame, minimapButton
local tankText, healText, ddText, stDpsText
local dungeonDropDown, modeDropDown
local roundRobinCB, allNeedCB, portReadyCB, worldButton, guildButton

-- Helper to format ST DPS numeric value to string ("1K+", "1.5K+", "30K+", or "")
function LFM:FormatSTDps(val)
    if not val or val < 1.0 then return "" end
    if val == math.floor(val) then
        return string.format("%dK+", val)
    else
        return string.format("%.1fK+", val)
    end
end

-- Helper to find DUNGEONS entry by uiName or object
function LFM:GetDungeonEntry(dungeon)
    if type(dungeon) == "table" then return dungeon end
    if type(dungeon) == "string" and dungeon ~= "" then
        for _, entry in ipairs(DUNGEONS) do
            if entry.uiName == dungeon then
                return entry
            end
        end
    end
    return nil
end

-- Debug Print function for local chat frame testing (call manually or when enabled)
function LFM:DebugPrintLockInfo()
    if not DEFAULT_CHAT_FRAME then return end
    local RESET = "|r"
    local GREEN = "|cff00ff00"
    local YELLOW = "|cffffd100"
    local RED = "|cffff3333"

    DEFAULT_CHAT_FRAME:AddMessage(GREEN .. "=== LFM Debug Info ===" .. RESET)

    -- 1. Game modes list
    local modesStr = table.concat(MODES, ", ")
    DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "Available Game Modes: " .. RESET .. modesStr)

    -- 2. All instances from API
    local num = GetNumSavedInstances()
    DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "Saved Instances from API (" .. num .. " total):" .. RESET)

    local lockedList = {}
    if num == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("  (No saved instances returned by GetNumSavedInstances)")
    else
        for i = 1, num do
            local name, id, reset, difficulty, isLocked, extended, _, isRaid, maxPlayers, difficultyName = GetSavedInstanceInfo(i)
            local lockStatus = isLocked and (RED .. "LOCKED" .. RESET) or (GREEN .. "UNLOCKED" .. RESET)
            DEFAULT_CHAT_FRAME:AddMessage("  [" .. i .. "] Name: '" .. tostring(name) .. "' | Lock: " .. lockStatus .. " | Diff: " .. tostring(difficulty) .. " (" .. tostring(difficultyName) .. ") | ID: " .. tostring(id))
            if isLocked and name then
                table.insert(lockedList, tostring(name) .. " (" .. tostring(difficultyName or difficulty) .. ")")
            end
        end
    end

    -- 3. Locked dungeons summary
    DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "Dungeons with active ID (Locked):" .. RESET)
    if #lockedList == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("  None")
    else
        for _, lockedInfo in ipairs(lockedList) do
            DEFAULT_CHAT_FRAME:AddMessage("  - " .. lockedInfo)
        end
    end

    -- 4. Matching results with LFM DUNGEONS dropdown list
    DEFAULT_CHAT_FRAME:AddMessage(YELLOW .. "Matches found in LFM DUNGEONS list:" .. RESET)
    local matchCount = 0
    local currentMode = (LFM_DB and LFM_DB.selected_mode ~= "") and LFM_DB.selected_mode or nil
    for _, entry in ipairs(DUNGEONS) do
        if currentMode then
            if LFM:IsLockedForDungeonAndMode(entry, currentMode) then
                matchCount = matchCount + 1
                DEFAULT_CHAT_FRAME:AddMessage("  " .. RED .. "[LOCKED MATCH (" .. currentMode .. ")] " .. RESET .. entry.uiName .. " (API Name: '" .. tostring(entry.apiName) .. "')")
            end
        else
            for i = 1, GetNumSavedInstances() do
                local name, _, _, _, isLocked, _, _, _, _, difficultyName = GetSavedInstanceInfo(i)
                if isLocked and name then
                    local entryUi = entry.uiName
                    local entryApi = entry.apiName
                    local cleanName = string.lower(name):gsub("^the%s+", ""):gsub("[%s%p]", "")
                    local targetApiClean = string.lower(entryApi):gsub("[%s%p]", "")
                    local targetUiClean = string.lower(entryUi):gsub("^the%s+", ""):gsub("[%s%p]", "")
                    if cleanName == targetApiClean or cleanName:find(targetUiClean, 1, true) or targetUiClean:find(cleanName, 1, true) then
                        matchCount = matchCount + 1
                        DEFAULT_CHAT_FRAME:AddMessage("  " .. YELLOW .. "[SAVED ID] " .. RESET .. entryUi .. " -> API: '" .. tostring(name) .. "' | Diff: '" .. tostring(difficultyName) .. "'")
                    end
                end
            end
        end
    end
    if matchCount == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("  No matches found")
    end

    DEFAULT_CHAT_FRAME:AddMessage(GREEN .. "========================" .. RESET)
end

-- Check if player has an active saved ID (lock) for a specific dungeon and mode combination
function LFM:IsLockedForDungeonAndMode(dungeon, mode)
    if not dungeon or dungeon == "" or not mode or mode == "" then
        return false
    end

    local modeLower = string.lower(mode)

    -- Saved IDs (locks) ONLY exist for Heroic/HC and base Mythic. M2..M30 have no locks!
    local isHC = (modeLower == "hc" or modeLower == "heroic")
    local isMythicBase = (modeLower == "mythic")

    if not (isHC or isMythicBase) then
        return false
    end

    local entry = LFM:GetDungeonEntry(dungeon)
    local uiName = entry and entry.uiName or (type(dungeon) == "string" and dungeon or "")
    local apiName = entry and entry.apiName or uiName
    if uiName == "" then return false end

    local targetApiClean = string.lower(apiName):gsub("[%s%p]", "")
    local targetUiClean = string.lower(uiName):gsub("^the%s+", ""):gsub("[%s%p]", "")

    local num = GetNumSavedInstances()
    for i = 1, num do
        local name, _, _, difficulty, isLocked, _, _, _, _, difficultyName = GetSavedInstanceInfo(i)
        if isLocked and name then
            local cleanName = string.lower(name):gsub("^the%s+", ""):gsub("[%s%p]", "")
            if cleanName == targetApiClean or cleanName:find(targetUiClean, 1, true) or targetUiClean:find(cleanName, 1, true) then
                local diffLower = string.lower(difficultyName or "")
                local modeMatches = false

                if isHC then
                    modeMatches = diffLower:find("heroic") or diffLower:find("hc") or (difficulty == 2)
                elseif isMythicBase then
                    modeMatches = diffLower:find("mythic") and not diffLower:find("heroic")
                end

                if modeMatches then
                    return true
                end
            end
        end
    end
    return false
end

-- Check if dungeon is locked for the currently selected mode
function LFM:IsDungeonLocked(dungeon)
    local mode = LFM_DB and LFM_DB.selected_mode
    if not mode or mode == "" then
        return false
    end
    return LFM:IsLockedForDungeonAndMode(dungeon, mode)
end

-- Check if mode is locked for the currently selected dungeon
function LFM:IsModeLocked(dungeon, mode)
    return LFM:IsLockedForDungeonAndMode(dungeon, mode)
end

-- Refresh display text of dropdowns to reflect lock status
function LFM:RefreshDropdownText()
    local dungeon = LFM_DB and LFM_DB.selected_dungeon_raid
    local mode = LFM_DB and LFM_DB.selected_mode

    if dungeonDropDown and dungeon and dungeon ~= "" then
        local isLocked = LFM:IsLockedForDungeonAndMode(dungeon, mode)
        local text = isLocked and ("|cffff3333" .. dungeon .. "|r") or dungeon
        UIDropDownMenu_SetText(dungeonDropDown, text)
    end

    if modeDropDown and mode and mode ~= "" then
        local isLocked = LFM:IsLockedForDungeonAndMode(dungeon, mode)
        local text = isLocked and ("|cffff3333" .. mode .. "|r") or mode
        UIDropDownMenu_SetText(modeDropDown, text)
    end
end

-- Format search message according to selection rules
function LFM:FormatSearchMessage()
    local t = (LFM_DB and LFM_DB.tanks_count) or 0
    local h = (LFM_DB and LFM_DB.heals_count) or 0
    local d = (LFM_DB and LFM_DB.dds_count) or 0
    local dungeon = (LFM_DB and LFM_DB.selected_dungeon_raid) or ""
    local mode = (LFM_DB and LFM_DB.selected_mode) or ""
    local stDpsStr = LFM:FormatSTDps(LFM_DB and LFM_DB.st_dps)
    local runesRoll = LFM_DB and LFM_DB.runes_roll
    local portReady = LFM_DB and LFM_DB.port_ready

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
        local ddStr = ""
        if d == 1 then
            ddStr = "1 DD"
        else
            ddStr = d .. " DDs"
        end

        -- Append ST DPS if at least 1 DD is selected AND ST DPS is non-empty
        if stDpsStr ~= "" then
            ddStr = ddStr .. " (" .. stDpsStr .. " ST)"
        end

        table.insert(roles, ddStr)
    end

    local rolesText = ""
    if #roles == 1 then
        rolesText = roles[1]
    elseif #roles == 2 then
        rolesText = roles[1] .. " and " .. roles[2]
    elseif #roles == 3 then
        rolesText = roles[1] .. ", " .. roles[2] .. " and " .. roles[3]
    end

    local msg = "LF " .. rolesText .. " for " .. dungeon .. " " .. mode

    -- Append Runes Roll if selected AND mode is HC or base Mythic
    if runesRoll and runesRoll ~= "" and mode ~= "" then
        local modeLower = string.lower(mode)
        local isHC = (modeLower == "hc" or modeLower == "heroic")
        local isMythicBase = (modeLower == "mythic")
        if isHC or isMythicBase then
            msg = msg .. ", on Runes we will use '" .. runesRoll .. "'"
        end
    end

    -- Append Port Ready if selected
    if portReady then
        msg = msg .. ", port ready"
    end

    return msg
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

    if not (totalRoles >= 1 and hasDungeon and hasMode) then
        return false
    end

    -- Disable search if player is locked for this specific dungeon and mode combination
    if LFM:IsLockedForDungeonAndMode(dungeon, mode) then
        return false
    end

    return true
end

-- Update action buttons enabled/disabled state & position based on guild membership
function LFM:UpdateSearchButton()
    local canSearch = LFM:CanSearch()
    local inGuild = IsInGuild()

    if guildButton then
        if inGuild then
            guildButton:Show()
            guildButton:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 320, -222)
            if worldButton then
                worldButton:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 210, -222)
            end
        else
            guildButton:Hide()
            if worldButton then
                worldButton:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 265, -222)
            end
        end
    end

    if worldButton then
        worldButton:EnableMouse(true)
        if canSearch then
            worldButton:Enable()
        else
            worldButton:Disable()
        end
    end

    if guildButton then
        guildButton:EnableMouse(true)
        if canSearch then
            guildButton:Enable()
        else
            guildButton:Disable()
        end
    end
end

-- Reset session data (wiped on login with character, but preserves selected_mode)
function LFM:ResetData()
    LFM_DB = LFM_DB or {}
    LFM_DB.tanks_count = 0
    LFM_DB.heals_count = 0
    LFM_DB.dds_count = 0
    LFM_DB.selected_dungeon_raid = ""
    LFM_DB.st_dps = 0
    LFM_DB.runes_roll = nil
    LFM_DB.port_ready = false
    LFM_DB.selected_mode = LFM_DB.selected_mode or ""
    LFM_DB.minimap = LFM_DB.minimap or { minimapPos = 45 }

    if tankText then tankText:SetText("0") end
    if healText then healText:SetText("0") end
    if ddText then ddText:SetText("0") end
    if stDpsText then stDpsText:SetText("") end

    if roundRobinCB then roundRobinCB:SetChecked(false) end
    if allNeedCB then allNeedCB:SetChecked(false) end
    if portReadyCB then portReadyCB:SetChecked(false) end

    if dungeonDropDown then
        UIDropDownMenu_SetSelectedValue(dungeonDropDown, nil)
        UIDropDownMenu_SetText(dungeonDropDown, "")
    end

    if modeDropDown then
        if LFM_DB.selected_mode ~= "" then
            UIDropDownMenu_SetSelectedValue(modeDropDown, LFM_DB.selected_mode)
            UIDropDownMenu_SetText(modeDropDown, LFM_DB.selected_mode)
        else
            UIDropDownMenu_SetSelectedValue(modeDropDown, nil)
            UIDropDownMenu_SetText(modeDropDown, "")
        end
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
        GameTooltip:AddLine("You can also type |cffffd100/lfm|r to toggle this window.", 0.8, 0.8, 0.8, true)
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
                tooltip:AddLine("You can also type |cffffd100/lfm|r to toggle this window.", 0.8, 0.8, 0.8, true)
            end,
        })
        LDBIcon:Register("LFM", LDBObj, LFM_DB.minimap)
    else
        CreateMinimapButton()
    end
end

-- Create Counter Control (Box + Up/Down arrows)
local function CreateCounterControl(parent, labelText, x, y, getValue, setValue, boxWidth)
    local width = boxWidth or 36
    -- Display Box
    local box = CreateFrame("Frame", nil, parent)
    box:SetWidth(width)
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

    -- Header Label centered above the display box + arrows control group
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("BOTTOM", box, "TOP", 10, 4)
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
        if type(current) == "number" then
            if current < 39 then
                setValue(current + 1)
                valueText:SetText(tostring(current + 1))
                LFM:UpdateSearchButton()
            end
        end
    end)

    -- Down Arrow Button
    local downBtn = CreateFrame("Button", nil, parent, "UIPanelScrollDownButtonTemplate")
    downBtn:SetWidth(18)
    downBtn:SetHeight(16)
    downBtn:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 2, 0)
    downBtn:SetScript("OnClick", function()
        local current = getValue()
        if type(current) == "number" then
            if current > 0 then
                setValue(current - 1)
                valueText:SetText(tostring(current - 1))
                LFM:UpdateSearchButton()
            end
        end
    end)

    return valueText
end

-- Setup Tooltips for World and Guild action buttons
local function SetupActionButtonTooltip(btn, channelName)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Send to " .. channelName, 1, 1, 1)

        local t = (LFM_DB and LFM_DB.tanks_count) or 0
        local h = (LFM_DB and LFM_DB.heals_count) or 0
        local d = (LFM_DB and LFM_DB.dds_count) or 0
        local dungeon = LFM_DB and LFM_DB.selected_dungeon_raid
        local mode = LFM_DB and LFM_DB.selected_mode

        local totalRoles = t + h + d
        local hasDungeon = (dungeon ~= nil and dungeon ~= "")
        local hasMode = (mode ~= nil and mode ~= "")

        if not (totalRoles >= 1 and hasDungeon and hasMode) then
            GameTooltip:AddLine("Select at least 1 role, a Dungeon, and a Mode.", 1, 0.2, 0.2, true)
        elseif LFM:IsLockedForDungeonAndMode(dungeon, mode) then
            GameTooltip:AddLine("You already have an active ID (Lock) for " .. dungeon .. " on " .. mode .. "!", 1, 0.2, 0.2, true)
        else
            GameTooltip:AddLine("Click to post LFM message to " .. channelName .. " channel.", 0.2, 1, 0.2, true)
        end

        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Create Main Window
local function CreateMainWindow()
    mainFrame = CreateFrame("Frame", "LFM_MainFrame", UIParent)
    mainFrame:SetWidth(620)
    mainFrame:SetHeight(270)
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

    -- Re-evaluate search button state, dropdown locks & print debug info whenever mainFrame is shown
    mainFrame:SetScript("OnShow", function()
        RequestRaidInfo()
        LFM:UpdateSearchButton()
        LFM:RefreshDropdownText()
        -- LFM:DebugPrintLockInfo() -- Debug print disabled
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

    -- SECTION 1: Looking For
    local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", mainFrame, "TOP", 0, -12)
    title:SetText("Looking For")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -6, -6)

    local startY = -52

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

    -- 4. Mode Dropdown
    modeDropDown = CreateFrame("Frame", "LFM_ModeDropDown", mainFrame, "UIDropDownMenuTemplate")
    modeDropDown:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 240, startY)
    UIDropDownMenu_SetWidth(modeDropDown, 85)

    local modeLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("BOTTOM", modeDropDown, "TOP", 10, 4)
    modeLabel:SetText("Mode")

    UIDropDownMenu_Initialize(modeDropDown, function(self, level)
        RequestRaidInfo()
        local selectedDungeon = LFM_DB and LFM_DB.selected_dungeon_raid
        local info = UIDropDownMenu_CreateInfo()
        for _, mode in ipairs(MODES) do
            local isLocked = LFM:IsLockedForDungeonAndMode(selectedDungeon, mode)
            info.text = isLocked and ("|cffff3333" .. mode .. "|r") or mode
            info.value = mode
            info.func = function(btn)
                if not LFM_DB then LFM_DB = {} end
                LFM_DB.selected_mode = btn.value
                UIDropDownMenu_SetSelectedValue(modeDropDown, btn.value)
                local currentDungeon = LFM_DB and LFM_DB.selected_dungeon_raid
                local text = LFM:IsLockedForDungeonAndMode(currentDungeon, btn.value) and ("|cffff3333" .. btn.value .. "|r") or btn.value
                UIDropDownMenu_SetText(modeDropDown, text)
                LFM:RefreshDropdownText()
                LFM:UpdateSearchButton()
                CloseMenus()
            end
            info.checked = (LFM_DB and LFM_DB.selected_mode == mode)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- 5. Dungeon / Raid Dropdown
    dungeonDropDown = CreateFrame("Frame", "LFM_DungeonDropDown", mainFrame, "UIDropDownMenuTemplate")
    dungeonDropDown:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 370, startY)
    UIDropDownMenu_SetWidth(dungeonDropDown, 140)

    local dungeonLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonLabel:SetPoint("BOTTOM", dungeonDropDown, "TOP", 10, 4)
    dungeonLabel:SetText("Dungeon / Raid")

    UIDropDownMenu_Initialize(dungeonDropDown, function(self, level)
        RequestRaidInfo()
        local selectedMode = LFM_DB and LFM_DB.selected_mode
        local info = UIDropDownMenu_CreateInfo()
        for _, entry in ipairs(DUNGEONS) do
            local name = entry.uiName
            local isLocked = LFM:IsLockedForDungeonAndMode(name, selectedMode)
            info.text = isLocked and ("|cffff3333" .. name .. "|r") or name
            info.value = name
            info.func = function(btn)
                if not LFM_DB then LFM_DB = {} end
                LFM_DB.selected_dungeon_raid = btn.value
                UIDropDownMenu_SetSelectedValue(dungeonDropDown, btn.value)
                local currentMode = LFM_DB and LFM_DB.selected_mode
                local text = LFM:IsLockedForDungeonAndMode(btn.value, currentMode) and ("|cffff3333" .. btn.value .. "|r") or btn.value
                UIDropDownMenu_SetText(dungeonDropDown, text)
                LFM:RefreshDropdownText()
                LFM:UpdateSearchButton()
                CloseMenus()
            end
            info.checked = (LFM_DB and LFM_DB.selected_dungeon_raid == name)
            UIDropDownMenu_AddButton(info, level)
        end
    end)


    -- SECTION 2: Optional
    local optionalTitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    optionalTitle:SetPoint("TOP", mainFrame, "TOP", 0, -98)
    optionalTitle:SetText("Optional")

    local optY = -146

    -- Minimum required ST DPS Counter
    local stBox = CreateFrame("Frame", nil, mainFrame)
    stBox:SetWidth(60)
    stBox:SetHeight(32)
    stBox:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 75, optY)
    stBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    stBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    stBox:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    local stLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stLabel:SetPoint("BOTTOM", stBox, "TOP", 10, 4)
    stLabel:SetText("Minimum required ST DPS")

    stDpsText = stBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    stDpsText:SetPoint("CENTER", stBox, "CENTER", 0, 0)
    stDpsText:SetText(LFM:FormatSTDps(LFM_DB and LFM_DB.st_dps))

    local stUpBtn = CreateFrame("Button", nil, mainFrame, "UIPanelScrollUpButtonTemplate")
    stUpBtn:SetWidth(18)
    stUpBtn:SetHeight(16)
    stUpBtn:SetPoint("TOPLEFT", stBox, "TOPRIGHT", 2, 0)
    stUpBtn:SetScript("OnClick", function()
        local current = LFM_DB and LFM_DB.st_dps or 0
        if current < 1.0 then
            LFM_DB.st_dps = 1.0
        elseif current < 30.0 then
            LFM_DB.st_dps = current + 0.5
        end
        stDpsText:SetText(LFM:FormatSTDps(LFM_DB.st_dps))
        LFM:UpdateSearchButton()
    end)

    local stDownBtn = CreateFrame("Button", nil, mainFrame, "UIPanelScrollDownButtonTemplate")
    stDownBtn:SetWidth(18)
    stDownBtn:SetHeight(16)
    stDownBtn:SetPoint("BOTTOMLEFT", stBox, "BOTTOMRIGHT", 2, 0)
    stDownBtn:SetScript("OnClick", function()
        local current = LFM_DB and LFM_DB.st_dps or 0
        if current > 1.0 then
            LFM_DB.st_dps = current - 0.5
        elseif current == 1.0 then
            LFM_DB.st_dps = 0
        end
        stDpsText:SetText(LFM:FormatSTDps(LFM_DB and LFM_DB.st_dps))
        LFM:UpdateSearchButton()
    end)

    -- Runes Roll Checkboxes
    roundRobinCB = CreateFrame("CheckButton", "LFM_RoundRobinCB", mainFrame, "UICheckButtonTemplate")
    roundRobinCB:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 245, optY + 2)
    _G[roundRobinCB:GetName() .. "Text"]:SetText("Round Robin")

    allNeedCB = CreateFrame("CheckButton", "LFM_AllNeedCB", mainFrame, "UICheckButtonTemplate")
    allNeedCB:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 345, optY + 2)
    _G[allNeedCB:GetName() .. "Text"]:SetText("All NEED")

    local runesLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    runesLabel:SetPoint("BOTTOM", mainFrame, "TOPLEFT", 330, optY + 4)
    runesLabel:SetText("Runes roll")

    roundRobinCB:SetScript("OnClick", function(self)
        if self:GetChecked() then
            LFM_DB.runes_roll = "Round Robin"
            allNeedCB:SetChecked(false)
        else
            LFM_DB.runes_roll = nil
        end
        LFM:UpdateSearchButton()
    end)

    allNeedCB:SetScript("OnClick", function(self)
        if self:GetChecked() then
            LFM_DB.runes_roll = "All NEED"
            roundRobinCB:SetChecked(false)
        else
            LFM_DB.runes_roll = nil
        end
        LFM:UpdateSearchButton()
    end)

    -- Port Ready Checkbox
    portReadyCB = CreateFrame("CheckButton", "LFM_PortReadyCB", mainFrame, "UICheckButtonTemplate")
    portReadyCB:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 480, optY + 2)

    local portReadyLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    portReadyLabel:SetPoint("BOTTOM", portReadyCB, "TOP", 0, 4)
    portReadyLabel:SetText("Port ready")

    portReadyCB:SetScript("OnClick", function(self)
        if not LFM_DB then LFM_DB = {} end
        LFM_DB.port_ready = self:GetChecked() and true or false
        LFM:UpdateSearchButton()
    end)


    -- SECTION 3: In
    local inTitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    inTitle:SetPoint("TOP", mainFrame, "TOP", 0, -192)
    inTitle:SetText("In")

    -- World Button
    worldButton = CreateFrame("Button", "LFM_WorldButton", mainFrame, "UIPanelButtonTemplate")
    worldButton:SetWidth(90)
    worldButton:SetHeight(28)
    worldButton:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 210, -222)
    worldButton:SetText("World")

    worldButton:SetScript("OnClick", function()
        if LFM:CanSearch() then
            local msg = LFM:FormatSearchMessage()
            local channelID = GetChannelName("World")
            if channelID then
                SendChatMessage(msg, "CHANNEL", nil, channelID)
            end
        end
    end)
    SetupActionButtonTooltip(worldButton, "World")

    -- Guild Button
    guildButton = CreateFrame("Button", "LFM_GuildButton", mainFrame, "UIPanelButtonTemplate")
    guildButton:SetWidth(90)
    guildButton:SetHeight(28)
    guildButton:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 320, -222)
    guildButton:SetText("Guild")

    guildButton:SetScript("OnClick", function()
        if LFM:CanSearch() then
            local msg = LFM:FormatSearchMessage()
            SendChatMessage(msg, "GUILD")
        end
    end)
    SetupActionButtonTooltip(guildButton, "Guild")


    -- Explicitly sync search button state after window creation
    LFM:UpdateSearchButton()

    -- Initially hidden until minimap icon or command opens it
    mainFrame:Hide()
end

-- Event Handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("UPDATE_INSTANCE_INFO")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "LFM" then
        LFM:ResetData()
        CreateMainWindow()
        InitMinimapIcon()
        RequestRaidInfo()
    elseif event == "UPDATE_INSTANCE_INFO" then
        LFM:RefreshDropdownText()
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
