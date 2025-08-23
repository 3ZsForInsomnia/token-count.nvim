--- Management and utility functions for cache
local M = {}

local instance_manager = require("token-count.cache.instance")
local directory = require("token-count.cache.directory")
local timer = require("token-count.cache.timer")
local notifications = require("token-count.cache.notifications")

--- Queue files from a directory for processing (public API)
--- @param dir_path string Directory path to scan
--- @param recursive boolean|nil Whether to scan recursively
function M.queue_directory_files(dir_path, recursive)
    directory.queue_directory_files(dir_path, recursive)
end

--- Register callback for cache updates
--- @param callback function Callback function(path, path_type)
function M.register_update_callback(callback)
    notifications.register_update_callback(callback)
end

--- Clear the cache
function M.clear_cache()
    local inst = instance_manager.get_instance()
    inst.cache = {}
    inst.processing = {}
    inst.process_queue = {}
    require("token-count.log").info("Cleared unified token count cache")
end

--- Get cache statistics
--- @return table stats Cache statistics
function M.get_stats()
    local inst = instance_manager.get_instance()
    local file_count = 0
    local dir_count = 0
    
    for _, cached in pairs(inst.cache) do
        if cached.type == "file" then
            file_count = file_count + 1
        elseif cached.type == "directory" then
            dir_count = dir_count + 1
        end
    end
    
    return {
        cached_files = file_count,
        cached_directories = dir_count,
        processing_items = vim.tbl_count(inst.processing),
        queued_items = #inst.process_queue,
        timer_active = inst.timer ~= nil,
        config = vim.deepcopy(inst.config),
    }
end

--- Update configuration
--- @param new_config table New configuration options
function M.update_config(new_config)
    local inst = instance_manager.get_instance()
    local old_interval = inst.config.interval
    inst.config = vim.tbl_deep_extend("force", inst.config, new_config)
    
    -- Restart timer if interval changed
    if inst.config.interval ~= old_interval and inst.timer then
        timer.start_timer()
    end
end

--- Get current configuration
--- @return table config Current configuration
function M.get_config()
    local inst = instance_manager.get_instance()
    return vim.deepcopy(inst.config)
end

--- Cleanup on plugin unload
function M.cleanup()
    timer.stop_timer()
    instance_manager.reset_instance()
end

return M