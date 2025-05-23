-- MapIconCompletionMarkerMod: Main script
-- This mod adds clickable completion markers to icons on the world map.

print("MapIconCompletionMarkerMod: script loaded")

local json = require("json")
local Enums = require("enums")
local HookManager = require("hook_manager")

-- Track map state across ticks
local wasOnMapPage = false

-- A list of keys for all icons that have been toggled off
local toggledIconKeys = {}
local saveFilePath = "Mods/MapIconCompletionMarkerMod/toggled_icons.json"

-- The currently hovered map icon
local hoveredIcon = nil

-- Poll user input
local pollingLoopHandle = nil
local navInput = FindFirstOf("VUINavigationPlayerSubsystem")

--- Checks if the given UObject is valid
local function IsValidObject(obj)
    return obj and obj:IsValid()
end

local function SaveToggledIcons()
    local file = io.open(saveFilePath, "w")
    if not file then
        return
    end

    local contents = json.encode(toggledIconKeys)
    file:write(contents)
    file:close()
    print("[DEBUG] Saved toggled icons to file.")
end

local function LoadToggledIcons()
    local file = io.open(saveFilePath, "r")
    if not file then
        print("[INFO] No save file found. Starting fresh.")
        return
    end

    local contents = file:read("*a")
    file:close()

    if not contents or contents:match("^%s*$") then
        return
    end

    local success, data = pcall(json.decode, contents)
    if success and type(data) == "table" then
        toggledIconKeys = data
        print("[DEBUG] Loaded toggled icons from file.")
    else
        print("[ERROR] Failed to parse save file: " .. tostring(data))
    end

    local mapIcons = FindAllOf("WBP_Modern_MapIcon_C")
    for _, mapIcon in ipairs(mapIcons) do
        if IsValidObject(mapIcon) then
            local key = mapIcon.Properties.Key:ToString()
            if toggledIconKeys[key] then
                local mapIconType = mapIcon.Properties.Type
                local offMaterialPath = Enums.iconMaterialsOff[mapIconType]
                local offMaterial = StaticFindObject(offMaterialPath, nil)
                mapIcon.Icon:SetBrushFromMaterial(offMaterial)
            end
        end
    end
end

--- Toggles the map icon's material between "on" and "off" state
local function ToggleIconState(mapIcon)
    if not IsValidObject(mapIcon) then
        return
    end

    local mapIconKey = mapIcon.Properties.Key:ToString()
    local mapIconType = mapIcon.Properties.Type

    local newMaterialPath
    if toggledIconKeys[mapIconKey] then
        -- The icon is toggled off, set it back to on
        newMaterialPath = Enums.iconMaterialsOn[mapIconType]
        toggledIconKeys[mapIconKey] = nil
    else
        -- The icon is on, toggle it off
        newMaterialPath = Enums.iconMaterialsOff[mapIconType]
        toggledIconKeys[mapIconKey] = true
    end

    local newMaterial = StaticFindObject(newMaterialPath, nil)
    mapIcon.Icon:SetBrushFromMaterial(newMaterial)
    print("[DEBUG] Set icon material to: " .. newMaterialPath)

    SaveToggledIcons()
end

-- Hook into IconHovered event
local function HookIconHovered()
    HookManager.Register("IconHovered", "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconHovered", function(_, params)
        local mapIcon = params[1]
        local key = mapIcon.Properties.Key:ToString()
        print("[DEBUG] Hovered icon key: " .. key)
        hoveredIcon = mapIcon
    end)
end

-- Hook into IconUnhovered event
local function HookIconUnhovered()
    HookManager.Register("IconUnhovered", "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconUnhovered", function(_, params)
        local mapIcon = params[1]
        local key = mapIcon.Properties.Key:ToString()
        print("[DEBUG] Unhovered icon key: " .. key)
        hoveredIcon = nil
    end)
end

--- Determines whether the player is currently viewing the world map
local function IsOnMapPage()
    local playerMenu = FindFirstOf("VLegacyPlayerMenu")
    if not IsValidObject(playerMenu) then
        return false
    end

    local playerMenuViewModel = playerMenu:GetViewModelRef()
    if not IsValidObject(playerMenuViewModel) then
        return false
    end

    if not playerMenuViewModel:IsVisible() then
        return false
    end

    local currentPage = playerMenuViewModel:GetCurrentPage()
    return currentPage == Enums.ELegacyPlayerMenuPage.Map
end

-- Start polling for user input
local function StartInputPollingLoop()
    if pollingLoopHandle then return end

    print("[DEBUG] Starting input polling loop")

    local wasShiftDown = false
    local wasDPadUpDown = false

    pollingLoopHandle = LoopAsync(50, function()
        if not IsValidObject(navInput) then
            navInput = FindFirstOf("VUINavigationPlayerSubsystem")
            if not IsValidObject(navInput) then
                return false
            end
        end

        -- Poll Shift key
        if navInput:IsShiftKeyDown() then
            if not wasShiftDown and hoveredIcon then
                ToggleIconState(hoveredIcon)
            end
            wasShiftDown = true
        else
            wasShiftDown = false
        end

        return false
    end)
end

-- Stop polling for user input
local function StopInputPollingLoop()
    if pollingLoopHandle then
        pollingLoopHandle:Cancel()
        pollingLoopHandle = nil
        wasShiftDown = false
        wasDPadUpDown = false
    end
end

-- Main map page watcher loop
LoopAsync(200, function()
    local isOnMapPage = IsOnMapPage()

    if isOnMapPage and not wasOnMapPage then
        print("[DEBUG] Player entered map page")
        LoadToggledIcons()
        HookIconHovered()
        HookIconUnhovered()
        StartInputPollingLoop()
    elseif not isOnMapPage and wasOnMapPage then
        print("[DEBUG] Player left map page")
        StopInputPollingLoop()
    end

    wasOnMapPage = isOnMapPage

    return false
end)