--- Public API functions for cache operations
local M = {}

local instance_manager = require("token-count.cache.instance")
local processor = require("token-count.cache.processor")
local directory = require("token-count.cache.directory")
local timer = require("token-count.cache.timer")
local notifications = require("token-count.cache.notifications")

--- Get token count for a file or directory (unified API)
--- @param path string Path to the file or directory
--- @param path_type string|nil "file" or "directory", auto-detected if nil
--- @return string|nil token_display Formatted token count, placeholder, or nil
function M.get_token_count(path, path_type)
    local inst = instance_manager.get_instance()
    
    -- Auto-detect path type if not specified
    if not path_type then
        local stat = vim.loop.fs_stat(path)
        if not stat then
            return nil
        end
        path_type = stat.type
    end
    
    -- Use appropriate cache TTL based on type
    local cache_ttl = path_type == "directory" and inst.config.directory_cache_ttl or inst.config.cache_ttl
    
    local cached = inst.cache[path]
    local now = vim.loop.hrtime() / 1000000
    
    -- Return cached value if valid
    if cached and cached.type == path_type and (now - cached.timestamp) < cache_ttl then
        return cached.formatted
    end
    
    -- Handle different path types
    if path_type == "file" and inst.config.enable_file_caching then
        return M._handle_file_request(inst, path)
    elseif path_type == "directory" and inst.config.enable_directory_caching then
        return M._handle_directory_request(inst, path)
    end
    
    -- Return expired cache if available
    return cached and cached.formatted
end

--- Handle file token count request
--- @param inst table Cache instance
--- @param path string File path
--- @return string placeholder or cached value
function M._handle_file_request(inst, path)
    -- If not cached and not being processed, queue it
    if not inst.processing[path] and processor.should_process_file(path) then
        -- Add to queue if not already there
        local already_queued = false
        for _, queued_path in ipairs(inst.process_queue) do
            if queued_path == path then
                already_queued = true
                break
            end
        end
        
        if not already_queued then
            table.insert(inst.process_queue, 1, path) -- Add to front for priority
            timer.debounced_immediate_processing(path)
        end
        
        return inst.config.placeholder_text
    end
    
    -- Return placeholder if processing
    if inst.processing[path] then
        return inst.config.placeholder_text
    end
    
    return nil
end

--- Handle directory token count request
--- @param inst table Cache instance
--- @param path string Directory path
--- @return string placeholder or cached value
function M._handle_directory_request(inst, path)
    -- Handle directory caching
    if not inst.processing[path] then
        inst.processing[path] = true
        
        directory.calculate_directory_tokens(path, function(total_tokens, error)
            inst.processing[path] = nil
            
            if not error and total_tokens then
                local formatted = processor.format_token_count(total_tokens)
                inst.cache[path] = {
                    count = total_tokens,
                    formatted = formatted,
                    timestamp = vim.loop.hrtime() / 1000000,
                    status = "ready",
                    type = "directory"
                }
                
                -- Trigger UI refresh
                notifications.notify_cache_updated(path, "directory")
            end
        end)
        
        return inst.config.placeholder_text
    end
    
    -- Return placeholder if processing
    if inst.processing[path] then
        return inst.config.placeholder_text
    end
    
    return nil
end

--- Get token count for a file (backward compatibility)
--- @param file_path string Path to the file
--- @return string|nil token_display Formatted token count, placeholder, or nil
function M.get_file_token_count(file_path)
    return M.get_token_count(file_path, "file")
end

--- Get token count for a directory
--- @param dir_path string Path to the directory
--- @return string|nil token_display Formatted token count, placeholder, or nil
function M.get_directory_token_count(dir_path)
    return M.get_token_count(dir_path, "directory")
end

--- Force immediate processing of a file or directory
--- @param path string Path to the file or directory
--- @param callback function|nil Callback function(result)
function M.process_immediate(path, callback)
    local stat = vim.loop.fs_stat(path)
    if not stat then
        if callback then callback(nil) end
        return
    end
    
    if stat.type == "file" then
        if not processor.should_process_file(path) then
            if callback then callback(nil) end
            return
        end
        
        processor.process_file(path, function(success, result)
            if callback then
                callback(success and result or nil)
            end
        end)
    elseif stat.type == "directory" then
        directory.calculate_directory_tokens(path, function(total_tokens, error)
            if callback then
                callback(not error and {count = total_tokens, formatted = processor.format_token_count(total_tokens)} or nil)
            end
        end)
    end
end

--- Invalidate cache for specific file and optionally reprocess
--- @param file_path string Path to invalidate
--- @param reprocess boolean|nil Whether to immediately reprocess
function M.invalidate_file(file_path, reprocess)
    local inst = instance_manager.get_instance()
    
    -- Remove from cache
    inst.cache[file_path] = nil
    
    if reprocess and processor.should_process_file(file_path) then
        M._queue_invalidated_file(inst, file_path)
    end
end

--- Queue invalidated file for reprocessing
--- @param inst table Cache instance
--- @param file_path string File path to reprocess
function M._queue_invalidated_file(inst, file_path)
    -- Add to front of queue
    local already_queued = false
    for _, queued_path in ipairs(inst.process_queue) do
        if queued_path == file_path then
            already_queued = true
            break
        end
    end
    
    if not already_queued and not inst.processing[file_path] then
        table.insert(inst.process_queue, 1, file_path)
        
        -- Debounced processing
        local debounce_key = "invalidate_" .. file_path
        if not inst.debounce_timers then
            inst.debounce_timers = {}
        end
        
        if inst.debounce_timers[debounce_key] then
            inst.debounce_timers[debounce_key]:stop()
            inst.debounce_timers[debounce_key]:close()
        end
        
        inst.debounce_timers[debounce_key] = vim.loop.new_timer()
        inst.debounce_timers[debounce_key]:start(inst.config.request_debounce or 100, 0, function()
            vim.schedule(function()
                timer.process_queue_batch()
                inst.debounce_timers[debounce_key]:close()
                inst.debounce_timers[debounce_key] = nil
            end)
        end)
    end
end

return M