--- Enhanced timer with better background processing and UI responsiveness
local M = {}

local log = require("token-count.log")

-- Performance tuning constants
local PERFORMANCE_CONFIG = {
    MIN_PROCESSING_INTERVAL = 2000,    -- Minimum 2s between processing cycles
    ADAPTIVE_INTERVAL_MAX = 10000,     -- Max interval when system is busy
    QUEUE_SIZE_THRESHOLD = 20,         -- Switch to slower processing above this
    UI_RESPONSIVENESS_CHECK = 500,     -- Check UI responsiveness every 500ms
    IDLE_DETECTION_TIME = 5000,        -- Consider system idle after 5s
    MAX_QUEUE_PROCESSING_TIME = 100,   -- Max time to spend processing queue per cycle (ms)
}

-- State tracking for adaptive processing
local processing_state = {
    last_ui_activity = 0,
    consecutive_empty_cycles = 0,
    processing_time_samples = {},
    current_interval = PERFORMANCE_CONFIG.MIN_PROCESSING_INTERVAL,
    ui_responsive = true,
}

--- Detect if UI is currently busy/unresponsive
--- @return boolean responsive Whether UI appears responsive
local function is_ui_responsive()
    -- Simple heuristic: check if we're in insert mode or visual mode
    local mode = vim.fn.mode()
    if mode == "i" or mode == "v" or mode == "V" or mode == "\22" then
        processing_state.last_ui_activity = vim.loop.hrtime() / 1000000
        return false
    end
    
    -- Check if user recently interacted with UI
    local now = vim.loop.hrtime() / 1000000
    local time_since_activity = now - processing_state.last_ui_activity
    
    return time_since_activity > PERFORMANCE_CONFIG.IDLE_DETECTION_TIME
end

--- Adaptive interval calculation based on system state
--- @param queue_size number Current queue size
--- @return number interval Adaptive processing interval
local function calculate_adaptive_interval(queue_size)
    local base_interval = PERFORMANCE_CONFIG.MIN_PROCESSING_INTERVAL
    
    -- Slow down if queue is large (system might be overwhelmed)
    if queue_size > PERFORMANCE_CONFIG.QUEUE_SIZE_THRESHOLD then
        base_interval = math.min(
            base_interval * 2, 
            PERFORMANCE_CONFIG.ADAPTIVE_INTERVAL_MAX
        )
    end
    
    -- Slow down if UI appears busy
    if not processing_state.ui_responsive then
        base_interval = base_interval * 1.5
    end
    
    -- Speed up if we've had many empty cycles (system is idle)
    if processing_state.consecutive_empty_cycles > 3 then
        base_interval = math.max(base_interval * 0.8, PERFORMANCE_CONFIG.MIN_PROCESSING_INTERVAL)
    end
    
    processing_state.current_interval = base_interval
    return base_interval
end

--- Ensure background timer is started (lazy initialization)
local function ensure_timer_started()
    local instance = require("token-count.cache.instance").get_instance()
    
    if not instance.timer_started and instance.config.lazy_start then
        instance.timer_started = true
        M.start_timer()
    end
end

--- Process queue with time-based limits to prevent UI blocking
function M.process_queue_batch()
    ensure_timer_started()
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Check UI responsiveness first
    processing_state.ui_responsive = is_ui_responsive()
    
    -- Skip processing if UI is busy
    if not processing_state.ui_responsive then
        log.info("Skipping cache processing - UI is busy")
        return
    end
    
    -- Throttle processing to prevent excessive calls
    local now = vim.loop.hrtime() / 1000000
    if instance.last_batch_time and (now - instance.last_batch_time) < processing_state.current_interval then
        return
    end
    
    local queue_size = #instance.process_queue
    if queue_size == 0 then
        processing_state.consecutive_empty_cycles = processing_state.consecutive_empty_cycles + 1
        return
    end
    
    processing_state.consecutive_empty_cycles = 0
    instance.last_batch_time = now
    
    -- Time-boxed processing
    local start_time = vim.loop.hrtime() / 1000000
    local max_processing_time = PERFORMANCE_CONFIG.MAX_QUEUE_PROCESSING_TIME
    local processed_count = 0
    
    -- Only log when queue is substantial to reduce log spam
    if queue_size > 10 then
        log.info(string.format("Processing cache queue: %d files remaining", queue_size))
    end
    
    -- Process files until time limit or queue empty
    while #instance.process_queue > 0 do
        local current_time = vim.loop.hrtime() / 1000000
        if (current_time - start_time) > max_processing_time then
            break -- Time limit reached
        end
        
        local file_path = table.remove(instance.process_queue, 1)
        if file_path then
            local processor = require("token-count.cache.processor_enhanced")
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
            processed_count = processed_count + 1
        end
        
        -- Check if UI became busy during processing
        if not is_ui_responsive() then
            log.info("Stopping cache processing - UI became busy")
            break
        end
    end
    
    -- Update adaptive interval based on processing results
    local processing_time = vim.loop.hrtime() / 1000000 - start_time
    table.insert(processing_state.processing_time_samples, processing_time)
    
    -- Keep only recent samples
    if #processing_state.processing_time_samples > 10 then
        table.remove(processing_state.processing_time_samples, 1)
    end
    
    -- Log performance info occasionally
    if processed_count > 0 and queue_size > 5 then
        log.info(string.format("Processed %d files in %.1fms, %d remaining", 
            processed_count, processing_time, #instance.process_queue))
    end
end

--- Start timer with adaptive intervals
function M.start_timer()
    local instance = require("token-count.cache.instance").get_instance()
    
    if instance.timer then
        instance.timer:stop()
        instance.timer:close()
    end
    
    -- Process queue immediately if we have items to process
    if #instance.process_queue > 0 then
        vim.schedule(function()
            M.process_queue_batch()
        end)
    end
    
    -- Start adaptive timer
    instance.timer = vim.loop.new_timer()
    
    -- Use a shorter initial interval, then adapt
    local initial_interval = math.min(instance.config.interval, PERFORMANCE_CONFIG.MIN_PROCESSING_INTERVAL)
    
    instance.timer:start(initial_interval, 0, function()
        vim.schedule(function()
            -- Calculate adaptive interval
            local queue_size = #instance.process_queue
            local adaptive_interval = calculate_adaptive_interval(queue_size)
            
            -- Process the queue
            M.process_queue_batch()
            
            -- Restart timer with new interval if needed
            if adaptive_interval ~= processing_state.current_interval then
                M.start_timer()
            else
                -- Continue with same interval
                instance.timer:start(adaptive_interval, 0, function()
                    vim.schedule(function()
                        M.process_queue_batch()
                    end)
                end)
            end
        end)
    end)
    
    log.info(string.format(
        "Started adaptive cache timer (initial: %dms, queue: %d items)", 
        initial_interval, 
        #instance.process_queue
    ))
end

--- Stop the background timer
function M.stop_timer()
    local instance = require("token-count.cache.instance").get_instance()
    
    if instance.timer then
        instance.timer:stop()
        instance.timer:close()
        instance.timer = nil
    end
    
    -- Reset processing state
    processing_state.consecutive_empty_cycles = 0
    processing_state.processing_time_samples = {}
    processing_state.current_interval = PERFORMANCE_CONFIG.MIN_PROCESSING_INTERVAL
    
    log.info("Stopped adaptive cache timer")
end

--- Add debounced processing for high-priority requests with smarter throttling
function M.debounced_immediate_processing(path)
    ensure_timer_started()
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Check if UI is responsive before adding immediate processing
    if not is_ui_responsive() then
        -- Just add to queue, don't process immediately
        return
    end
    
    local debounce_key = "request_" .. path
    if not instance.debounce_timers then
        instance.debounce_timers = {}
    end
    
    if instance.debounce_timers[debounce_key] then
        instance.debounce_timers[debounce_key]:stop()
        instance.debounce_timers[debounce_key]:close()
    end
    
    -- Use longer debounce if system seems busy
    local debounce_time = processing_state.ui_responsive and 
        (instance.config.request_debounce or 250) or 
        (instance.config.request_debounce or 250) * 2
    
    instance.debounce_timers[debounce_key] = vim.loop.new_timer()
    instance.debounce_timers[debounce_key]:start(debounce_time, 0, function()
        vim.schedule(function()
            -- Double-check UI responsiveness before processing
            if is_ui_responsive() and #instance.process_queue > 0 and not instance.processing[path] then
                M.process_queue_batch()
            end
            instance.debounce_timers[debounce_key]:close()
            instance.debounce_timers[debounce_key] = nil
        end)
    end)
end

return M