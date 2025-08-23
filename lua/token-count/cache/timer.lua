local M = {}

local log = require("token-count.log")
local processor = require("token-count.cache.processor")

--- Ensure background timer is started (lazy initialization)
local function ensure_timer_started()
	local instance = require("token-count.cache.instance").get_instance()
	
	if not instance.timer_started and instance.config.lazy_start then
		instance.timer_started = true
		M.start_timer()
	end
end
function M.process_queue_batch()
	ensure_timer_started()
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Throttle processing to prevent excessive calls
    local now = vim.loop.hrtime() / 1000000
    if instance.last_batch_time and (now - instance.last_batch_time) < 1000 then -- 1 second throttle
        return
    end
    instance.last_batch_time = now
    
    -- Reduce batch size to prevent blocking
    -- Ultra-conservative batch size to prevent any UI blocking
    local batch_size = math.min(1, #instance.process_queue) -- Only 1 file at a time
    if batch_size == 0 then
        return
    end
    
    -- Only log when queue is substantial to reduce log spam
    if #instance.process_queue > 5 then
        log.info(string.format("Processing queue: %d files remaining", #instance.process_queue))
    end
    
    -- Process one file with minimal UI impact
    local file_path = table.remove(instance.process_queue, 1)
    if file_path then
        processor.process_file(file_path, function(success, result)
            if success then
                -- Defer UI notifications to prevent blocking
                vim.schedule(function()
                    local notifications = require("token-count.cache.notifications")
                    notifications.notify_cache_updated(file_path, "file")
                end)
            end
            -- Don't log individual file processing to reduce noise
        end)
    end
end

function M.start_timer()
    local instance = require("token-count.cache.instance").get_instance()
    
    if instance.timer then
        instance.timer:stop()
        instance.timer:close()
    end
    
   	-- Only process queue immediately if we have items to process
   	if #instance.process_queue > 0 then
   		vim.schedule(function()
   			M.process_queue_batch()
   		end)
   	end
    
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
function M.debounced_immediate_processing(path)
    ensure_timer_started()
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