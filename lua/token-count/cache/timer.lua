--- Timer and queue management for background processing
local M = {}

local log = require("token-count.log")
local processor = require("token-count.cache.processor")

--- Process files from the queue
function M.process_queue_batch()
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Throttle processing to prevent excessive calls
    local now = vim.loop.hrtime() / 1000000
    if instance.last_batch_time and (now - instance.last_batch_time) < 1000 then -- 1 second throttle
        return
    end
    instance.last_batch_time = now
    
    local batch_size = math.min(instance.config.max_files_per_batch, #instance.process_queue)
    if batch_size == 0 then
        return
    end
    
    log.info(string.format("Processing batch of %d files", batch_size))
    
    for i = 1, batch_size do
        local file_path = table.remove(instance.process_queue, 1)
        if file_path then
            processor.process_file(file_path, function(success, result)
                if success then
                    log.info(string.format("Cached tokens for %s: %s", file_path, result.formatted))
                    
                    -- Notify UI components of update
                    local notifications = require("token-count.cache.notifications")
                    notifications.notify_cache_updated(file_path, "file")
                else
                    log.warn(string.format("Failed to process %s: %s", file_path, result or "unknown error"))
                end
            end)
        end
    end
end

--- Start the background timer
function M.start_timer()
    local instance = require("token-count.cache.instance").get_instance()
    
    if instance.timer then
        instance.timer:stop()
        instance.timer:close()
    end
    
    -- Process queue immediately on startup
    vim.schedule(function()
        M.process_queue_batch()
    end)
    
    instance.timer = vim.loop.new_timer()
    instance.timer:start(100, instance.config.interval, function()
        vim.schedule(function()
            M.process_queue_batch()
        end)
    end)
    
    log.info(string.format("Started background token counting timer (interval: %dms)", instance.config.interval))
end

--- Stop the background timer
function M.stop_timer()
    local instance = require("token-count.cache.instance").get_instance()
    
    if instance.timer then
        instance.timer:stop()
        instance.timer:close()
        instance.timer = nil
    end
    log.info("Stopped background token counting timer")
end

--- Add debounced processing for high-priority requests
--- @param path string File path to process
function M.debounced_immediate_processing(path)
    local instance = require("token-count.cache.instance").get_instance()
    
    local debounce_key = "request_" .. path
    if not instance.debounce_timers then
        instance.debounce_timers = {}
    end
    
    if instance.debounce_timers[debounce_key] then
        instance.debounce_timers[debounce_key]:stop()
        instance.debounce_timers[debounce_key]:close()
    end
    
    instance.debounce_timers[debounce_key] = vim.loop.new_timer()
    instance.debounce_timers[debounce_key]:start(instance.config.request_debounce or 100, 0, function()
        vim.schedule(function()
            if #instance.process_queue > 0 and not instance.processing[path] then
                M.process_queue_batch()
            end
            instance.debounce_timers[debounce_key]:close()
            instance.debounce_timers[debounce_key] = nil
        end)
    end)
end

return M