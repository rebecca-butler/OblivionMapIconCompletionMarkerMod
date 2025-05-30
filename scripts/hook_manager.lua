-- This file is part of MapIconCompletionMarkerMod.

local HookManager = {}
HookManager.activeHooks = {}

-- Register a hook and remember the callback IDs
function HookManager.Register(key, functionPath, callback)
    -- HookManager.Unregister(key)
    local preId, postId = RegisterHook(functionPath, callback)
    HookManager.activeHooks[key] = {
        path = functionPath,
        pre = preId,
        post = postId
    }
end

-- Unregister the hook by key if it was registered
function HookManager.Unregister(key)
    local hookData = HookManager.activeHooks[key]
    if hookData then
        print("[MapCompletionMarkerMod] Unregistering: " .. tostring(hookData.path) .. " pre-hook" .. tostring(hookData.pre) .. " post-hook" .. tostring(hookData.post))
        -- UnregisterHook() crashes after unregistering OnFadeToGameBeginEventReceived
        UnregisterHook(hookData.path, hookData.pre or 0, hookData.post or 0)
        print("[MapCompletionMarkerMod] Unregister complete")
        HookManager.activeHooks[key] = nil
    end
end

return HookManager