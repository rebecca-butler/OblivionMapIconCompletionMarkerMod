-- MapIconCompletionMarkerMod: Main script
-- This mod adds clickable completion markers to icons on the world map.

print("MapIconCompletionMarkerMod: script loaded")

-- Load shared configuration and enums
local Config = require("config")
local Enums = require("enums")

-- Hook handles for cleanup
OnFadeToGameBeginEventReceived_Hook = nil

-- Track state across ticks
local wasOnMapPage = false
local lastMapPage = nil

-- A list of keys for all icons that have been toggled off
local toggledIconKeys = {}

-- The currently hovered map icon
local hoveredIcon = nil

--- Checks if the given UObject is valid
local function IsValidObject(obj)
    return obj and obj:IsValid()
end

--- Toggles the map icon's material between "on" and "off" state
local function ToggleIconState(mapIcon)
    print("[DEBUG] Starting ToggleIconState")

    if not IsValidObject(mapIcon) then
        print("[ERROR] Invalid mapIcon passed to ToggleIconState")
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

    print("[DEBUG] Toggling icon material to: " .. newMaterialPath)
    local newMaterial = StaticFindObject(newMaterialPath, nil)
    mapIcon.Icon:SetBrushFromMaterial(newMaterial)
end

-- local function HookShiftKey()
--     local functionPath = "/Script/Altar.VEnhancedAltarPlayerController:ShiftKeyInput_Pressed"

--     local function OnShiftPressed_Hook(UObject, UFunctionParams)
--         print("[DEBUG] Shift key pressed!")
--         local keyName = UFunctionParams[1].Key:ToString()
--         if keyName == "LeftShift" or keyName == "RightShift" then
--             print("[DEBUG] Shift key pressed!")
--             if hoveredIcon ~= nil then
--                 ToggleIconState(hoveredIcon)
--             end
--         end
--     end

--     RegisterHook(functionPath, OnShiftPressed_Hook)
-- end

local function HookIconHovered()
    local functionPath = "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconHovered"

    local function OnIconHovered_Hook(UObject, UFunctionParams)
        local mapIcon = UFunctionParams[1]
        local key = mapIcon.Properties.Key:ToString()
        print("[DEBUG] Hovered icon key: " .. key)
        hoveredIcon = mapIcon
    end

    RegisterHook(functionPath, OnIconHovered_Hook)
end

local function HookIconUnhovered()
    local functionPath = "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconUnhovered"

    local function OnIconUnhovered_Hook(UObject, UFunctionParams)
        local mapIcon = UFunctionParams[1]
        local key = mapIcon.Properties.Key:ToString()
        print("[DEBUG] Unhovered icon key: " .. key)
        hoveredIcon = nil
    end

    RegisterHook(functionPath, OnIconUnhovered_Hook)
end

--- Sets up a hook to trigger logic when game begins
NotifyOnNewObject("/Script/Altar.AltarCommonGameViewportClient", function(viewPort)
    if not IsValidObject(viewPort) then
        return
    end

    if OnFadeToGameBeginEventReceived_Hook then
        UnregisterHook(OnFadeToGameBeginEventReceived_Hook)
        OnFadeToGameBeginEventReceived_Hook = nil
    end

    OnFadeToGameBeginEventReceived_Hook = RegisterHook(
        "/Script/Altar.VLevelChangeData:OnFadeToGameBeginEventReceived",
        function(context)
            if not IsValidObject(viewPort) then
                return
            end
        end
    )
end)

--- Determines whether the player is currently viewing the world map
local function IsOnMapPage()
    local playerMenu = FindFirstOf("VLegacyPlayerMenu")
    if not IsValidObject(playerMenu) then
        return false
    end

    local playerMenuViewModel = playerMenu:GetViewModelRef()
    if not IsValidObject(playerMenuViewModel) then
        print("[DEBUG] playerMenuViewModel not found")
        return false
    end

    if not playerMenuViewModel:IsVisible() then
        return false
    end

    local currentPage = playerMenuViewModel:GetCurrentPage()
    return currentPage == Enums.ELegacyPlayerMenuPage.Map
end

--- Main polling loop: checks if the player is on the world map every 200ms
LoopAsync(200, function()
    local isOnMapPage = IsOnMapPage()

    if not isOnMapPage then
        if wasOnMapPage then end
        wasOnMapPage = false
        lastMapPage = nil
        return false
    end

    if not wasOnMapPage then
    end

    local VMapMenuViewModel = FindFirstOf("VMapMenuViewModel")
    if not IsValidObject(VMapMenuViewModel) then
        wasOnMapPage = isOnMapPage
        return false
    end

    local currentPage = VMapMenuViewModel.CurrentPage

    if lastMapPage ~= Enums.ELegacyMapMenuPage.WorldMap and currentPage == Enums.ELegacyMapMenuPage.WorldMap then
        print("[DEBUG] Player switched to World Map")
        HookIconHovered()
        HookIconUnhovered()
    end

    lastMapPage = currentPage
    wasOnMapPage = isOnMapPage

    return false
end)

local wasShiftDown = false

-- Poll shift key globally every 50ms
LoopAsync(50, function()
    local navInput = FindFirstOf("VUINavigationPlayerSubsystem")
    if navInput and navInput:IsShiftKeyDown() then
        print("[DEBUG] Shift key pressed")
        if not wasShiftDown then
            if hoveredIcon ~= nil then
                print("[DEBUG] Shift key pressed AND icon is hovered")
                ToggleIconState(hoveredIcon)
            end
        end
        wasShiftDown = true
    else
        wasShiftDown = false
    end
    return false
end)