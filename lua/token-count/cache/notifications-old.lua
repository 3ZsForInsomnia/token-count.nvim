--- Notification system for cache updates
local M = {}

--- Notify UI components of cache updates
--- @param path string Path that was updated
--- @param path_type string Type of path ("file" or "directory")
function M.notify_cache_updated(path, path_type)
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Trigger neotree refresh if visible
    vim.schedule(function()
        local neo_tree_ok, manager = pcall(require, "neo-tree.sources.manager")
        if neo_tree_ok then
            local state = manager.get_state("filesystem")
            if state and state.winid and vim.api.nvim_win_is_valid(state.winid) then
                manager.refresh("filesystem")
            end
        end
    end)
    
    -- Trigger custom callbacks
    for _, callback in ipairs(instance.update_callbacks) do
        pcall(callback, path, path_type)
    end
end

--- Register callback for cache updates
--- @param callback function Callback function(path, path_type)
function M.register_update_callback(callback)
    local instance = require("token-count.cache.instance").get_instance()
    table.insert(instance.update_callbacks, callback)
end

return M