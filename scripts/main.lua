-- MapIconCompletionMarkerMod: Main script
-- This mod adds clickable completion markers to icons on the world map.

print("MapIconCompletionMarkerMod: script loaded")

-- Load shared configuration and enums
local Config = require("config")
local Enums = require("enums")

-- Hook handles for cleanup
OnIconHovered_Hook = nil
OnIconUnhovered_Hook = nil 

-- Track map state across ticks
local wasOnMapPage = false

-- A list of keys for all icons that have been toggled off
local toggledIconKeys = {}

-- The currently hovered map icon
local hoveredIcon = nil

-- Poll user input
local pollingLoopHandle = nil
local navInput = FindFirstOf("VUINavigationPlayerSubsystem")

--- Checks if the given UObject is valid
local function IsValidObject(obj)
    return obj and obj:IsValid()
end

--- Toggles the map icon's material between "on" and "off" state
local function ToggleIconState(mapIcon)
    print("[DEBUG] Starting ToggleIconState")

    if not IsValidObject(mapIcon) then
        return
    end

    local mapIconKey = mapIcon.Properties.Key:ToString()
    print("[DEBUG] mapIconKey: " .. mapIconKey)

    local mapIconType = mapIcon.Properties.Type
    print("[DEBUG] mapIconType: " .. tostring(mapIconType))

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
end

-- Hook into IconHovered event
local function HookIconHovered()
    local functionPath = "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconHovered"

    if OnIconHovered_Hook then
        UnregisterHook(OnIconHovered_Hook)
        OnIconHovered_Hook = nil
    end

    local function HandleIconHovered(UObject, UFunctionParams)
        local mapIcon = UFunctionParams[1]
        local key = mapIcon.Properties.Key:ToString()
        print("[DEBUG] Hovered icon key: " .. key)
        hoveredIcon = mapIcon
    end

    OnIconHovered_Hook = RegisterHook(functionPath, HandleIconHovered)
end

-- Hook into IconUnhovered event
local function HookIconUnhovered()
    local functionPath = "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconUnhovered"

    if OnIconUnhovered_Hook then
        UnregisterHook(OnIconUnhovered_Hook)
        OnIconUnhovered_Hook = nil
    end

    local function HandleIconUnhovered(UObject, UFunctionParams)
        local mapIcon = UFunctionParams[1]
        local key = mapIcon.Properties.Key:ToString()
        print("[DEBUG] Unhovered icon key: " .. key)
        hoveredIcon = nil
    end

    OnIconUnhovered_Hook = RegisterHook(functionPath, HandleIconUnhovered)
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
            print("[DEBUG] Shift key pressed")
            if not wasShiftDown and hoveredIcon then
                print("[DEBUG] Shift key pressed AND icon hovered")
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
        print("[DEBUG] Stopping input polling loop")
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