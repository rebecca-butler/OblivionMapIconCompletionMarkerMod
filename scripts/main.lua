-- MapIconCompletionMarkerMod: Main script
-- This mod script adds custom markers for Oblivion Gates to the world map
-- when the player navigates to the map in the in-game menu.

print("MapIconCompletionMarkerMod: script loaded")

-- Load required shared configuration and definitions
local Config = require("config")
local Enums = require("enums")

-- Hook handles for cleanup
OnFadeToGameBeginEventReceived_Hook = nil

-- Track state across ticks
local wasOnMapPage = false
local lastMapPage = nil

-- Utility function: checks if a UObject is valid
local function IsValidObject(obj)
    return obj and obj:IsValid()
end

local function ToggleMapIcon(mapIcon)
    local iconImage = mapIcon.Icon
    if not iconImage then return end

    local type = mapIcon.Properties.Type
    local pathOn = Enums.iconMaterialsOn[type]
    local pathOff = Enums.iconMaterialsOff[type]

    if not pathOn or not pathOff then
        print("No materials for icon type " .. tostring(type))
        return
    end

    local brush = iconImage.Brush
    local currentMat = brush and brush.ResourceObject and brush.ResourceObject:GetPathName()

    local newMatPath = pathOn
    if currentMat == pathOn then
        newMatPath = pathOff
    end

    local newMat = StaticFindObject(newMatPath, nil)
    if newMat then
        iconImage:SetBrushFromMaterial(newMat)
        print("Toggled icon to: " .. newMatPath)
    else
        print("Could not find material: " .. newMatPath)
    end
end

---@param icon userdata
local function BindOnIconClicked(icon)
    if not IsValidObject(icon) then return end

    icon.OnIconClicked:Clear()

    local function OnClicked(address)
        ToggleMapIcon(icon)
    end

    icon.OnIconClicked:Add(OnClicked)
end

local function InitMapIcons()
    local mapIcons = FindAllOf("WBP_Modern_MapIcon_C")
    for _, mapIcon in ipairs(mapIcons) do
        if IsValidObject(mapIcon) then
            BindOnIconClicked(mapIcon)
        end
    end
end

-- Registers a hook when the viewport (main game window) is initialized
NotifyOnNewObject("/Script/Altar.AltarCommonGameViewportClient", function(viewPort)
    -- Clean up previous hooks if they exist
    if OnFadeToGameBeginEventReceived_Hook then
        UnregisterHook(OnFadeToGameBeginEventReceived_Hook)
        OnFadeToGameBeginEventReceived_Hook = nil
    end

    -- Register a hook that triggers when the game begins
    OnFadeToGameBeginEventReceived_Hook = RegisterHook(
        "/Script/Altar.VLevelChangeData:OnFadeToGameBeginEventReceived",
        function(context)
            if not IsValidObject(viewPort) then
                return
            end
            GetOblivionGates()
        end
    )
end)

-- Determines if the player is currently on the world map page of the menu
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

-- Main polling loop: checks every 200ms to see if the map is open
-- and if the player has switched to the World Map tab
LoopAsync(200, function()
    local isOnMapPage = IsOnMapPage()

    -- If not on the map page, reset state and exit this loop iteration
    if not isOnMapPage then
        if wasOnMapPage then
            print("[DEBUG] Player has exited the map menu.")
        end
        wasOnMapPage = false
        lastMapPage = nil
        return false
    end

    -- If this is the first frame we've detected being on the map page
    if not wasOnMapPage then
        print("[DEBUG] Player has just opened the map menu.")
    end

    local VMapMenuViewModel = FindFirstOf("VMapMenuViewModel")
    if not IsValidObject(VMapMenuViewModel) then
        wasOnMapPage = isOnMapPage
        return false
    end

    local currentPage = VMapMenuViewModel.CurrentPage

    -- Detect when switching to the World Map tab and add markers
    if lastMapPage ~= Enums.ELegacyMapMenuPage.WorldMap and currentPage == Enums.ELegacyMapMenuPage.WorldMap then
        print("[DEBUG] Player has switched to the World Map.")
        InitMapIcons()
    end

    -- Update state for next loop iteration
    lastMapPage = currentPage
    wasOnMapPage = isOnMapPage

    return false
end)