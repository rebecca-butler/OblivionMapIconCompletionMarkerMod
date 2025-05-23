-- MapIconCompletionMarkerMod: Main script
-- This mod adds clickable completion markers to icons on the world map.

print("MapIconCompletionMarkerMod: script loaded")

local json = require("json")
local Enums = require("enums")
local HookManager = require("hook_manager")

-- Track state across ticks
local wasInWorldMap = false
local wasShiftDown = false

-- A list of keys for all icons that have been toggled off
local toggledIconKeys = {}
local saveFilePath = "Mods/MapIconCompletionMarkerMod/toggled_icons.json"

-- The currently hovered map icon
local hoveredIcon = nil

-- Poll user input
local pollingLoopHandle = nil
local navInput = FindFirstOf("VUINavigationPlayerSubsystem")

-- Cached map icons
local cachedMapIconsByKey = {}

--- Checks if the given UObject is valid
local function IsValidObject(obj)
    return obj and obj:IsValid()
end

function Delay(seconds, callback)
    local startTime = os.clock()
    LoopAsync(50, function()
        if os.clock() - startTime >= seconds then
            callback()
            return true
        end
        return false
    end)
end

--- Retrieves saved list of toggled icons from json
local function LoadToggledIcons()
    print("[DEBUG] Loading icons")
    local file = io.open(saveFilePath, "r")
    if not file then
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
    end

    print("[DEBUG] Loaded toggled icons:")
    for iconKey, _ in pairs(toggledIconKeys) do
        print(" - " .. iconKey)
    end
end

local function CacheMapIcons()
    cachedMapIconsByKey = {}
    local mapIcons = FindAllOf("WBP_Modern_MapIcon_C")
    for _, mapIcon in ipairs(mapIcons) do
        if IsValidObject(mapIcon) then
            local key = mapIcon.Properties.Key:ToString()
            cachedMapIconsByKey[key] = mapIcon
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
            LoadToggledIcons()
        end
    )
end)

--- Saves current list of toggled icons to json
local function SaveToggledIcons()
    local file = io.open(saveFilePath, "w")
    if not file then
        return
    end

    local contents = json.encode(toggledIconKeys)
    file:write(contents)
    file:close()
end

-- Hook into IconHovered event
local function HookIconHovered()
    HookManager.Register("IconHovered", "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconHovered", function(_, params)
        local mapIcon = params[1]
        local key = mapIcon.Properties.Key:ToString()
        hoveredIcon = mapIcon
    end)
end

-- Hook into IconUnhovered event
local function HookIconUnhovered()
    HookManager.Register("IconUnhovered", "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconUnhovered", function(_, params)
        local mapIcon = params[1]
        local key = mapIcon.Properties.Key:ToString()
        hoveredIcon = nil
    end)
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

-- Starts polling for user input
local function StartInputPollingLoop()
    if pollingLoopHandle then return end

    pollingLoopHandle = LoopAsync(50, function()
        if not IsValidObject(navInput) then
            navInput = FindFirstOf("VUINavigationPlayerSubsystem")
            if not IsValidObject(navInput) then
                return false
            end
        end

        -- Poll Shift key
        local shiftDown = navInput:IsShiftKeyDown()
        if shiftDown and not wasShiftDown and hoveredIcon then
            ToggleIconState(hoveredIcon)
        end
        wasShiftDown = shiftDown

        return false
    end)
end

-- Stops polling for user input
local function StopInputPollingLoop()
    if pollingLoopHandle then
        pollingLoopHandle:Cancel()
        pollingLoopHandle = nil
    end

    wasShiftDown = false
end

--- Update the map icons with the current toggled state
local function ApplyToggledIcons()
    for key, _ in pairs(toggledIconKeys) do
        local mapIcon = cachedMapIconsByKey[key]
        if mapIcon then
            print("[DEBUG] Found match with cached map icon")
            local mapIconType = mapIcon.Properties.Type
            local materialPath = Enums.iconMaterialsOff[mapIconType]
            local material = StaticFindObject(materialPath, nil)
            if material then
                print("[DEBUG] Setting off material for type: " .. tostring(mapIconType))
                mapIcon.Icon:SetBrushFromMaterial(material)
            else
                print("[CRITICAL] Could not load material from path: " .. materialPath)
            end
        else
            print("[ERROR] Failed to find match with cached map icon")
        end
    end
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


-- Main map page watcher loop
LoopAsync(200, function()
    local isInWorldMap = false
    if IsOnMapPage() then
        local VMapMenuViewModel = FindFirstOf("VMapMenuViewModel")
        if IsValidObject(VMapMenuViewModel) then
            isInWorldMap = VMapMenuViewModel.CurrentPage == Enums.ELegacyMapMenuPage.WorldMap
        end
    end

    if isInWorldMap and not wasInWorldMap then
        print("[DEBUG] Player entered world map page")
        CacheMapIcons()

        -- Apply the icons twice to get around external icon update events
        ApplyToggledIcons()
        Delay(0.1, function()
            ApplyToggledIcons()
        end)

        HookIconHovered()
        HookIconUnhovered()
        StartInputPollingLoop()
    end

    if not isInWorldMap and wasInWorldMap then
        print("[DEBUG] Player left world map page")
        StopInputPollingLoop()
    end

    wasInWorldMap = isInWorldMap

    return false
end)