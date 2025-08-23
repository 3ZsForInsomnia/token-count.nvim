--- Cache instance singleton management
local M = {}

-- Singleton instance
local instance = nil

--- Initialize singleton instance
local function init_instance()
    if instance then
        return instance
    end
    
    instance = {
        -- Cache storage: path -> {count, formatted, timestamp, status, type}
        cache = {},
        
        -- Files/directories currently being processed
        processing = {},
        
        -- Timer for background updates
        timer = nil,
        
        -- Queue of paths to process
        process_queue = {},
        
        -- Configuration
        config = {
            interval = 30000, -- 30 seconds in milliseconds
            max_files_per_batch = 10, -- Process max 10 files per interval
            cache_ttl = 300000, -- 5 minutes cache TTL in milliseconds
            directory_cache_ttl = 600000, -- 10 minutes for directories
            placeholder_text = "⋯", -- Placeholder while counting
            enable_directory_caching = true,
            enable_file_caching = true,
            request_debounce = 100, -- 100ms debounce for immediate requests
        },
        
        -- Callbacks for UI updates
        update_callbacks = {},
        
        -- Throttling
        last_batch_time = 0,
        
        -- Debounce timers
        debounce_timers = {},
    }
    
    return instance
end

--- Get singleton instance
--- @return table instance The singleton cache manager instance
function M.get_instance()
    return instance or init_instance()
end

--- Reset instance (for testing)
function M.reset_instance()
    if instance and instance.timer then
        instance.timer:stop()
        instance.timer:close()
    end
    instance = nil
end

return M