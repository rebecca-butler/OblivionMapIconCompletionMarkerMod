-- This file is part of MapIconCompletionMarkerMod.

print("MapIconCompletionMarkerMod: script loaded")

-- Includes
local json = require("json")
local Enums = require("enums")
local HookManager = require("hook_manager")

-- State tracking
local wasInWorldMap = false
local wasShiftDown = false
local pollingLoopHandle = nil
local hoveredIcon = nil

-- A list of the keys for all icons that have been toggled off
local toggledIconKeys = {}

-- The json file path where the toggled icon list is saved
local saveFilePath = "ue4ss/Mods/MapIconCompletionMarkerMod/toggled_icons.json"

-- The cached map icons and materials
local cachedMapIconsByKey = {}
local cachedMaterialsByKey = {}

-- The player subsystem, used for input polling
local navInput = FindFirstOf("VUINavigationPlayerSubsystem")

local lastIconUdpdateTime = nil

--- Checks if the given UObject is valid
local function IsValidObject(obj)
    return obj and obj:IsValid()
end

--- Delays execution of the given callback by a number of seconds
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

--- Retrieves the saved list of toggled icons from the json file
local function LoadToggledIcons()
    local file = io.open(saveFilePath, "r")
    if not file then return end

    local contents = file:read("*a")
    file:close()

    -- Ignore the file contents if empty
    if not contents or contents:match("^%s*$") then return end

    local success, data = pcall(json.decode, contents)
    if success and type(data) == "table" then
        toggledIconKeys = data
    end

    -- print("[DEBUG] Loaded toggled icons:")
    for iconKey, _ in pairs(toggledIconKeys) do
        print(" - " .. iconKey)
    end
end

--- Saves current list of toggled icons to json
local function SaveToggledIcons()
    local file = io.open(saveFilePath, "w")
    if not file then return end

    local contents = json.encode(toggledIconKeys)
    file:write(contents)
    file:close()
end

--- Caches materials into a table indexed by their key
local function GetMaterial(materialPath)
    if not cachedMaterialsByKey[materialPath] then
        local material = StaticFindObject(materialPath)
        if not material then
            print("[ERROR] Material not found: " .. tostring(materialPath))
        end
        cachedMaterialsByKey[materialPath] = material
    end
    return cachedMaterialsByKey[materialPath]
end

--- Caches map icons into a table indexed by their key
local function CacheMapIcons()
    cachedMapIconsByKey = {}
    local mapIcons = FindAllOf("WBP_Modern_MapIcon_C")
    for _, mapIcon in ipairs(mapIcons) do
        if IsValidObject(mapIcon) then
            local key = mapIcon.Properties.Key:ToString()
            if key ~= "None" then
                cachedMapIconsByKey[key] = mapIcon
                -- print("[DEBUG] Cached icon " .. key)
            end
        end
    end
end

--- Hook into engine event to load icon states when game starts
NotifyOnNewObject("/Script/Altar.AltarCommonGameViewportClient", function(viewPort)
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
            if next(toggledIconKeys) == nil then
                LoadToggledIcons()
            end
        end
    )
end)

--- Hook into map icon hovered event
local function HookIconHovered()
    HookManager.Register("IconHovered", "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconHovered", function(_, params)
        local mapIcon = params[1]
        local key = mapIcon.Properties.Key:ToString()
        hoveredIcon = mapIcon
    end)
end

--- Hook into map icon unhovered event
local function HookIconUnhovered()
    HookManager.Register("IconUnhovered", "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconUnhovered", function(_, params)
        local mapIcon = params[1]
        local key = mapIcon.Properties.Key:ToString()
        hoveredIcon = nil
    end)
end

--- Toggles the map icon's material between "on" and "off" state
local function ToggleIconState(mapIcon)
    if not IsValidObject(mapIcon) then return end

    local mapIconKey = mapIcon.Properties.Key:ToString()
    local mapIconType = mapIcon.Properties.Type

    local newMaterialPath
    if toggledIconKeys[mapIconKey] then
        -- The icon is toggled off, set it back to on
        newMaterialPath = Enums.iconMaterialsOn[mapIconType]
        -- print("[DEBUG] User toggled icon on: " .. mapIconKey)
    else
        -- The icon is on, toggle it off
        newMaterialPath = Enums.iconMaterialsOff[mapIconType]
        -- print("[DEBUG] User toggled icon off: " .. mapIconKey)
    end

    local newMaterial = GetMaterial(newMaterialPath)
    if newMaterial then
        if toggledIconKeys[mapIconKey] then
            toggledIconKeys[mapIconKey] = nil
        else
            toggledIconKeys[mapIconKey] = true
        end

        mapIcon.Icon:SetBrushFromMaterial(newMaterial)
        SaveToggledIcons()
    else
        print("[ERROR] Material not found for type: " .. tostring(mapIconType))
    end
end

--- Starts polling for user input (Shift + Hover)
local function StartInputPollingLoop()
    if pollingLoopHandle then return end

    pollingLoopHandle = LoopAsync(30, function()
        if not IsValidObject(navInput) then
            navInput = FindFirstOf("VUINavigationPlayerSubsystem")
            if not IsValidObject(navInput) then return false end
        end

        local shiftDown = navInput:IsShiftKeyDown()
        if shiftDown and not wasShiftDown and hoveredIcon then
            ToggleIconState(hoveredIcon)
        end
        wasShiftDown = shiftDown

        return false
    end)
end

--- Stops polling for user input
local function StopInputPollingLoop()
    if pollingLoopHandle then
        pollingLoopHandle:Cancel()
        pollingLoopHandle = nil
    end
    cachedMapIconsByKey = {}
    cachedMaterialsByKey = {}
    wasShiftDown = false
end

--- Updates the material of all cached icons based on toggled state
local function ApplyToggledIcons()
    local keysPending = {}
    local count = 0
    for key, _ in pairs(toggledIconKeys) do
        count = count + 1
        local mapIcon = cachedMapIconsByKey[key]

        if not IsValidObject(mapIcon) then
            -- print("[WARN] Cache miss for icon key: " .. key)
            table.insert(keysPending, key)
        else
            local mapIconType = mapIcon.Properties.Type
            local materialPath = Enums.iconMaterialsOff[mapIconType]
            local material = GetMaterial(materialPath)
            if material then
                mapIcon.Icon:SetBrushFromMaterial(material)
                mapIcon.Icon:InvalidateLayoutAndVolatility()
                -- print("[DEBUG] Applied off material to " .. key)
            else
                print("[ERROR] Material not found for type: " .. tostring(mapIconType))
                table.insert(keysPending, key)
            end
        end
    end

    -- Retry once after a short delay if any icons were missing
    if #keysPending > 0 then
        Delay(0.5, function()
            CacheMapIcons()
            for _, key in ipairs(keysPending) do
                local mapIcon = cachedMapIconsByKey[key]
                if IsValidObject(mapIcon) then
                    local mapIconType = mapIcon.Properties.Type
                    local materialPath = Enums.iconMaterialsOff[mapIconType]
                    local material = StaticFindObject(materialPath, nil)
                    if material then
                        mapIcon.Icon:SetBrushFromMaterial(material)
                        print("[DEBUG] (Retry) Applied off material to " .. key)
                    else
                        print("[ERROR] (Retry) Material not found for type: " .. tostring(mapIconType))
                    end
                else
                    print("[ERROR] Still missing map icon with key: " .. key)
                end
            end
        end)
    end
end

--- Determines whether the player is currently viewing the world map
local function IsOnWorldMapPage()
    local playerMenu = FindFirstOf("VLegacyPlayerMenu")
    if not IsValidObject(playerMenu) then return false end

    local playerMenuViewModel = playerMenu:GetViewModelRef()
    if not IsValidObject(playerMenuViewModel) then return false end

    if not playerMenuViewModel:IsVisible() then return false end

    -- Check if the player is on the map page
    local currentPage = playerMenuViewModel:GetCurrentPage()
    if currentPage ~= Enums.ELegacyPlayerMenuPage.Map then return false end

    -- Check if the player is on the world map page
    local VMapMenuViewModel = FindFirstOf("VMapMenuViewModel")
    if IsValidObject(VMapMenuViewModel) then
        return VMapMenuViewModel.CurrentPage == Enums.ELegacyMapMenuPage.WorldMap
    end
end


-- Main map page watcher loop
LoopAsync(200, function()
    local isInWorldMap = IsOnWorldMapPage()
    if isInWorldMap and not wasInWorldMap then
        Delay(0.0, function()
            if IsOnWorldMapPage() then
                CacheMapIcons()
                ApplyToggledIcons()
                HookIconHovered()
                HookIconUnhovered()
                StartInputPollingLoop()
            end
        end)
    end

    if not isInWorldMap and wasInWorldMap then
        StopInputPollingLoop()
    end

    wasInWorldMap = isInWorldMap
    return false
end)