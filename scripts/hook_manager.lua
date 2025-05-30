-- This file is part of MapIconCompletionMarkerMod.

local HookManager = {}
HookManager.activeHooks = {}

-- Register a hook and remember the callback IDs
local function HookManager.Register(key, functionPath, callback)
    HookManager.Unregister(key)
    local preId, postId = RegisterHook(functionPath, callback)
    HookManager.activeHooks[key] = {
        path = functionPath,
        pre = preId,
        post = postId
    }
end

-- Unregister the hook by key if it was registered
local function HookManager.Unregister(key)
    local hookData = HookManager.activeHooks[key]
    if hookData then
        UnregisterHook(hookData.path, hookData.pre or 0, hookData.post or 0)
        HookManager.activeHooks[key] = nil
    end
end

return HookManager