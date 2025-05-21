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
local focusedIcon = nil

--- Checks if the given UObject is valid
local function IsValidObject(obj)
    return obj and obj:IsValid()
end

--- Toggles the map icon's material between "on" and "off" state
local function ToggleIconState(mapIcon)
    if not IsValidObject(mapIcon) then
        print("[ERROR] Invalid mapIcon passed to ToggleIconState")
        return
    end

    local iconImage = mapIcon.Icon
    if not iconImage then 
        print("[ERROR] mapIcon.Icon is nil")
        return 
    end

    local props = mapIcon.Properties
    if not props then
        print("[ERROR] mapIcon.Properties is nil")
        return
    end

    local type = props.Type
    local pathOn = Enums.iconMaterialsOn[type]
    local pathOff = Enums.iconMaterialsOff[type]

    if not pathOn or not pathOff then
        print("[ERROR] No materials defined for icon type: " .. tostring(type))
        return
    end

    local brush = iconImage.Brush
    if not brush then
        print("[ERROR] iconImage.Brush is nil")
        return
    end

    local resource = brush.ResourceObject
    local currentMat = resource and resource:GetPathName()

    local newMatPath = (currentMat == pathOn) and pathOff or pathOn
    local newMat = StaticFindObject(newMatPath, nil)

    if newMat then
        iconImage:SetBrushFromMaterial(newMat)
        print("[DEBUG] Toggled icon material to: " .. newMatPath)
    else
        print("[ERROR] Could not find material: " .. newMatPath)
    end
end


-- Track focus on icons
local function HookIconFocus(icon)
     local delegatePath = "/Game/UI/Original/GameMenuLayer/Map/Prefabs/WBP_Modern_MapIcon.WBP_Modern_MapIcon_C:OnIconHovered__DelegateSignature"

    -- Register hook on this specific icon instance's delegate
    RegisterHook(delegatePath, function(context)
        print("Icon hover!")
        local args = context:GetArguments()
        local hoveredIcon = args[1]
        focusedIcon = hoveredIcon
        print("[DEBUG] Hovered icon set to: " .. (hoveredIcon and hoveredIcon:GetFullName() or "nil"))
    end)

    local unhoveredPath = "/Game/UI/Original/GameMenuLayer/Map/Prefabs/WBP_Modern_MapIcon.WBP_Modern_MapIcon_C:OnIconUnhovered__DelegateSignature"
    RegisterHook(unhoveredPath, function(context)
        print("Icon unhover!")
        focusedIcon = nil
        print("[DEBUG] Icon unhovered, focusedIcon cleared")
    end)
end

-- Hook the map widget input
local function HookMapWidgetInputs()
    local mapWidget = FindFirstOf("WBP_Modern_MapWidget_C")
    if not IsValidObject(mapWidget) then
        print("[WARN] mapWidget not found")
        return
    end

    local mouseDownFn = "/Script/UMG.UserWidget:OnKeyDown"
    RegisterHook(mouseDownFn, function(ctx)
        print("Key down!")
        local self = ctx:get():GetSelf()
        local args = ctx:get():GetArgs()
        local mouse_event = args[2]

        local button = mouse_event:GetEffectingButton():ToString()
        if button == "RightMouseButton" and focusedIcon then
            ToggleIconState(focusedIcon)
            return FEventReply.Handled()
        end
    end)

    local keyDownFn = "/Script/UMG.UserWidget:OnMouseButtonDown"
    RegisterHook(keyDownFn, function(ctx)
        print("Mouse button down!")
        local self = ctx:get():GetSelf()
        local args = ctx:get():GetArgs()
        local key_event = args[2]

        local key = key_event:GetKey():ToString()
        if key == "Gamepad_FaceButton_Top" and focusedIcon then
            ToggleIconState(focusedIcon)
            return FEventReply.Handled()
        end
    end)
end

--- Finds and initializes all map icons on the World Map page
local function GetMapIcons()
    print("[DEBUG] Initializing map icons...")
    local mapIcons = FindAllOf("WBP_Modern_MapIcon_C")
    if not mapIcons or #mapIcons == 0 then
        print("[WARN] No WBP_Modern_MapIcon_C instances found")
        return
    end

    for _, mapIcon in ipairs(mapIcons) do
        if IsValidObject(mapIcon) then
            print("[DEBUG] Found valid map icon, hooking")
            HookIconFocus(mapIcon)
        else
            print("[WARN] Found invalid map icon, skipping")
        end
    end
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
        if wasOnMapPage then
            print("[DEBUG] Player exited map menu")
        end
        wasOnMapPage = false
        lastMapPage = nil
        return false
    end

    if not wasOnMapPage then
        print("[DEBUG] Player entered map menu")
    end

    local VMapMenuViewModel = FindFirstOf("VMapMenuViewModel")
    if not IsValidObject(VMapMenuViewModel) then
        print("[WARN] VMapMenuViewModel not found")
        wasOnMapPage = isOnMapPage
        return false
    end

    local currentPage = VMapMenuViewModel.CurrentPage

    if lastMapPage ~= Enums.ELegacyMapMenuPage.WorldMap and currentPage == Enums.ELegacyMapMenuPage.WorldMap then
        print("[DEBUG] Player switched to World Map")
        GetMapIcons()
        HookMapWidgetInputs()
    end

    lastMapPage = currentPage
    wasOnMapPage = isOnMapPage

    return false
end)