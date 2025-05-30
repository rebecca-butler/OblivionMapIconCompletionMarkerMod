-- This file is part of MapIconCompletionMarkerMod.

print("MapIconCompletionMarkerMod: script loaded")

-- Includes
local json = require("json")
local MapIconCompletionEnums = require("enums")
local HookManager = require("hook_manager")
local MapIconCompletionConfig = require("config")

-- State tracking
local wasInWorldMap = false
local wasShiftDown = false
local pollingLoopHandle = nil
local hoveredIcon = nil
local loaded = false
local OnFadeToGameBeginEventReceived_Hook = nil

-- A list of the keys for all icons that have been toggled off
local toggledIconKeys = {}

-- The directory where the toggled icon list is saved
local saveFileDir = "ue4ss/Mods/MapIconCompletionMarkerMod/"

-- The cached map icons and materials
local cachedMapIconsByKey = {}
local cachedMaterialsByKey = {}

-- The player subsystem, used for input polling
local navInput = FindFirstOf("VUINavigationPlayerSubsystem")

--- Checks if the given UObject is valid
local function IsValidObject(obj)
    return obj and obj:IsValid()
end

--- Delays execution of the given callback by a number of seconds
local function Delay(seconds, callback)
    local startTime = os.clock()
    LoopAsync(50, function()
        if os.clock() - startTime >= seconds then
            callback()
            return true
        end
        return false
    end)
end

--- Gets the file path where the toggled icon list is saved
local function GetJsonFilePath()
    print("[MapIconCompletionMarkerMod] [DEBUG] GetJsonFilePath")
    local subsystem = FindFirstOf("VAltarUISubsystem")
    if not IsValidObject(subsystem) then
        print("[MapIconCompletionMarkerMod] [ERROR] No save menu item found")
        return nil
    end

    local playerName = subsystem:GetPlayerNameTextFromLastLoadedSave()
    local path = saveFileDir .. playerName:ToString() .. "_toggled_icons.json"
    return path
end

--- Retrieves the saved list of toggled icons from the json file
local function LoadToggledIcons()
    print("[MapIconCompletionMarkerMod] [DEBUG] LoadToggledIcons")
    local path = GetJsonFilePath()
    local file = io.open(GetJsonFilePath(), "r")
    if not file then
        print("[MapIconCompletionMarkerMod] Toggled icon file not found, creating new one: " .. path)
        local newFile = io.open(path, "w")
        if newFile then
            newFile:write("{}")
            newFile:close()
        else
            print("[MapIconCompletionMarkerMod] [ERROR] Failed to create file: " .. path)
        end
        return
    end

    local contents = file:read("*a")
    file:close()

    -- Ignore the file contents if empty
    if not contents or contents:match("^%s*$") then return end

    local success, data = pcall(json.decode, contents)
    if success and type(data) == "table" then
        toggledIconKeys = data
    end

    -- print("[MapIconCompletionMarkerMod] [DEBUG] Loaded toggled icons:")
    -- for iconKey, _ in pairs(toggledIconKeys) do
    --     print("[MapIconCompletionMarkerMod]  - " .. iconKey)
    -- end
end

--- Saves current list of toggled icons to json
local function SaveToggledIcons()
    print("[MapIconCompletionMarkerMod] [DEBUG] SaveToggledIcons")
    local file = io.open(GetJsonFilePath(), "w")
    if not file then return end

    local contents = json.encode(toggledIconKeys)
    file:write(contents)
    file:close()
end

--- Caches materials into a table indexed by their key
local function GetMaterial(materialPath)
    print("[MapIconCompletionMarkerMod] [DEBUG] GetMaterial")
    if not cachedMaterialsByKey[materialPath] then
        local material = StaticFindObject(materialPath)
        if not material then
            print("[MapIconCompletionMarkerMod] [ERROR] Material not found: " .. tostring(materialPath))
        end
        cachedMaterialsByKey[materialPath] = material
    end
    return cachedMaterialsByKey[materialPath]
end

--- Caches map icons into a table indexed by their key
local function CacheMapIcons()
    print("[MapIconCompletionMarkerMod] [DEBUG] CacheMapIcons")
    cachedMapIconsByKey = {}
    local mapIcons = FindAllOf("WBP_Modern_MapIcon_C")
    for _, mapIcon in ipairs(mapIcons) do
        if IsValidObject(mapIcon) then
            local key = mapIcon.Properties.Key:ToString()
            if key ~= "None" then
                cachedMapIconsByKey[key] = mapIcon
                -- print("[MapIconCompletionMarkerMod] [DEBUG] Cached icon " .. key)
            end
        end
    end
end

--- Hook into map icon hovered event
local function HookIconHovered()
    print("[MapIconCompletionMarkerMod] [DEBUG] HookIconHovered")
    HookManager.Register("IconHovered", "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconHovered", function(_, params)
        local mapIcon = params[1]
        if IsValidObject(mapIcon) then
            hoveredIcon = mapIcon
        end
    end)
end

--- Hook into map icon unhovered event
local function HookIconUnhovered()
    print("[MapIconCompletionMarkerMod] [DEBUG] HookIconUnhovered")
    HookManager.Register("IconUnhovered", "/Game/UI/Original/GameMenuLayer/Map/WBP_Modern_MapWidget.WBP_Modern_MapWidget_C:OnIconUnhovered", function(_, params)
        hoveredIcon = nil
    end)
end

--- Hook into engine event to load icon states when game starts
local function HookFadeToGameBegin()
    print("[MapIconCompletionMarkerMod] [DEBUG] HookFadeToGameBegin")
    if loaded then return end
    HookManager.Register("FadeToGameBegin", "/Script/Altar.VLevelChangeData:OnFadeToGameBeginEventReceived", function(context)
        print("[MapIconCompletionMarkerMod] [DEBUG] FadeToGameBegin triggered!")
        -- LoadToggledIcons()
        print("[MapIconCompletionMarkerMod] [DEBUG] Loaded icons")
        -- HookIconHovered()
        print("[MapIconCompletionMarkerMod] [DEBUG] Hooked HookIconHovered")
        -- HookIconUnhovered()
        print("[MapIconCompletionMarkerMod] [DEBUG] Hooked HookIconUnhovered")
        loaded = true
        -- HookManager.Unregister("FadeToGameBegin")
        print("[MapIconCompletionMarkerMod] [DEBUG] Unregistered FadeToGameBegin")
    end)
end

--- Toggles the map icon's material between "on" and "off" state
local function ToggleIconState(mapIcon)
    print("[MapIconCompletionMarkerMod] [DEBUG] ToggleIconState")
    if not IsValidObject(mapIcon) then return end

    local mapIconKey = mapIcon.Properties.Key:ToString()
    local mapIconType = mapIcon.Properties.Type

    local newMaterialPath
    if toggledIconKeys[mapIconKey] then
        -- The icon is toggled off, set it back to on
        newMaterialPath = MapIconCompletionEnums.iconMaterialsOn[mapIconType]
        -- print("[MapIconCompletionMarkerMod] [DEBUG] User toggled icon on: " .. mapIconKey)
    else
        -- The icon is on, toggle it off
        newMaterialPath = MapIconCompletionEnums.iconMaterialsOff[mapIconType]
        -- print("[MapIconCompletionMarkerMod] [DEBUG] User toggled icon off: " .. mapIconKey)
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
        print("[MapIconCompletionMarkerMod] [ERROR] Material not found for type: " .. tostring(mapIconType))
    end
end

--- Starts polling for user input (Shift + Hover)
local function StartInputPollingLoop()
    print("[MapIconCompletionMarkerMod] [DEBUG] StartInputPollingLoop")
    if pollingLoopHandle then return end

    pollingLoopHandle = LoopAsync(30, function()
        local success, err = pcall(function()
            if not IsValidObject(navInput) then
                navInput = FindFirstOf("VUINavigationPlayerSubsystem")
                if not IsValidObject(navInput) then return end
            end

            local shiftDown = navInput:IsShiftKeyDown()
            if shiftDown and not wasShiftDown and hoveredIcon then
                ToggleIconState(hoveredIcon)
            end
            wasShiftDown = shiftDown
        end)
        
        return false
    end)
end

--- Stops polling for user input
local function StopInputPollingLoop()
    print("[MapIconCompletionMarkerMod] [DEBUG] StopInputPollingLoop")
    if pollingLoopHandle then
        pollingLoopHandle:Cancel()
        pollingLoopHandle = nil
    end
    wasShiftDown = false
end

--- Determines whether the player is currently viewing the world map
local function IsOnWorldMapPage()
    print("[MapIconCompletionMarkerMod] [DEBUG] Inside IsOnWorldMapPage")
    local playerMenu = FindFirstOf("VLegacyPlayerMenu")
    if not IsValidObject(playerMenu) then return false end
    print("[MapIconCompletionMarkerMod] [DEBUG] Got valid VLegacyPlayerMenu")

    local playerMenuViewModel = playerMenu:GetViewModelRef()
    if not IsValidObject(playerMenuViewModel) then return false end
    print("[MapIconCompletionMarkerMod] [DEBUG] Got valid playerMenuViewModel")

    if not playerMenuViewModel:IsVisible() then return false end
    print("[MapIconCompletionMarkerMod] [DEBUG] Got visible playerMenuViewModel")

    -- Check if the player is on the map page
    local currentPage = playerMenuViewModel:GetCurrentPage()
    if not IsValidObject(VMapMenuViewModel) then return false end
    print("[MapIconCompletionMarkerMod] [DEBUG] Got valid currentPage")

    if currentPage ~= MapIconCompletionEnums.ELegacyPlayerMenuPage.Map then return false end
    print("[MapIconCompletionMarkerMod] [DEBUG] Player is on map page")

    -- Check if the player is on the world map page
    local VMapMenuViewModel = FindFirstOf("VMapMenuViewModel")
    if not IsValidObject(VMapMenuViewModel) then return false end
    print("[MapIconCompletionMarkerMod] [DEBUG] Got valid VMapMenuViewModel")

    return VMapMenuViewModel.CurrentPage == MapIconCompletionEnums.ELegacyMapMenuPage.WorldMap
end

--- Updates the material of all cached icons based on toggled state
local function ApplyToggledIcons()
    print("[MapIconCompletionMarkerMod] [DEBUG] ApplyToggledIcons")
    local keysPending = {}
    local count = 0
    for key, _ in pairs(toggledIconKeys) do
        count = count + 1
        local mapIcon = cachedMapIconsByKey[key]

        if not IsValidObject(mapIcon) then
            -- print("[MapIconCompletionMarkerMod] [WARN] Cache miss for icon key: " .. key)
            table.insert(keysPending, key)
        else
            local mapIconType = mapIcon.Properties.Type
            local materialPath = MapIconCompletionEnums.iconMaterialsOff[mapIconType]
            local material = GetMaterial(materialPath)
            if material then
                mapIcon.Icon:SetBrushFromMaterial(material)
                mapIcon.Icon:InvalidateLayoutAndVolatility()
                -- print("[MapIconCompletionMarkerMod] [DEBUG] Applied off material to " .. key)
            else
                print("[MapIconCompletionMarkerMod] [ERROR] Material not found for type: " .. tostring(mapIconType))
                table.insert(keysPending, key)
            end
        end
    end

    -- Retry once after a short delay if any icons were missing
    if #keysPending > 0 then
        Delay(MapIconCompletionConfig.delaySeconds, function()
            if not IsOnWorldMapPage() then return end
            CacheMapIcons()
            for _, key in ipairs(keysPending) do
                local mapIcon = cachedMapIconsByKey[key]
                if IsValidObject(mapIcon) then
                    local mapIconType = mapIcon.Properties.Type
                    local materialPath = MapIconCompletionEnums.iconMaterialsOff[mapIconType]
                    local material = StaticFindObject(materialPath, nil)
                    if material then
                        mapIcon.Icon:SetBrushFromMaterial(material)
                        print("[MapIconCompletionMarkerMod] [DEBUG] (Retry) Applied off material to " .. key)
                    else
                        print("[MapIconCompletionMarkerMod] [ERROR] (Retry) Material not found for type: " .. tostring(mapIconType))
                    end
                else
                    print("[MapIconCompletionMarkerMod] [ERROR] Still missing map icon with key: " .. key)
                end
            end
        end)
    end
end

HookFadeToGameBegin()

-- Main map page watcher loop
LoopAsync(200, function()
    print("[MapIconCompletionMarkerMod] [DEBUG] start main loop")
    local isInWorldMap = IsOnWorldMapPage()
    -- print("[MapIconCompletionMarkerMod] [DEBUG] inside main loop 2")
    -- print("[MapIconCompletionMarkerMod] [DEBUG] isInWorldMap is: " .. tostring(isInWorldMap))
    if isInWorldMap and not wasInWorldMap then
        print("[MapIconCompletionMarkerMod] [DEBUG] Player is on world map page")
        Delay(MapIconCompletionConfig.delaySeconds, function()
            if IsOnWorldMapPage() then
                cachedMapIconsByKey = {}
                cachedMaterialsByKey = {}
                CacheMapIcons()
                ApplyToggledIcons()
                StartInputPollingLoop()
            end
        end)
    end
    print("[MapIconCompletionMarkerMod] [DEBUG] inside main loop 3")

    if not isInWorldMap and wasInWorldMap then
        print("[MapIconCompletionMarkerMod] [DEBUG] stop polling loop")
        StopInputPollingLoop()
    end

    print("[MapIconCompletionMarkerMod] [DEBUG] inside main loop 4")

    wasInWorldMap = isInWorldMap
    print("[MapIconCompletionMarkerMod] [DEBUG] inside main loop 5")
    return false
end)