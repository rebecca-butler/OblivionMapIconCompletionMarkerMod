local HookManager = {}

HookManager.activeHooks = {}

-- Register a hook and remember the callback IDs
function HookManager.Register(key, functionPath, callback)
    -- Unregister existing hook under this key
    HookManager.Unregister(key)

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
        UnregisterHook(hookData.path, hookData.pre or 0, hookData.post or 0)
        HookManager.activeHooks[key] = nil
    end
end

-- Optional: Unregister all hooks at once
function HookManager.UnregisterAll()
    for key, _ in pairs(HookManager.activeHooks) do
        HookManager.Unregister(key)
    end
end

return HookManager