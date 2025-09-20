--- Public API functions for cache operations
local M = {}

local instance_manager = require("token-count.cache.instance")
local processor = require("token-count.cache.processor")
local directory = require("token-count.cache.directory")
local timer = require("token-count.cache.timer")
local notifications = require("token-count.cache.notifications")

--- Check if file is in an active or visible buffer
--- @param file_path string File path to check
--- @return boolean is_active Whether file is in active/visible buffer
function M._is_file_in_active_buffer(file_path)
    -- Get all loaded buffers
    local buffers = vim.api.nvim_list_bufs()
    
    for _, buf_id in ipairs(buffers) do
        if vim.api.nvim_buf_is_loaded(buf_id) then
            local buf_name = vim.api.nvim_buf_get_name(buf_id)
            if buf_name == file_path then
                -- Check if buffer is visible in any window
                local win_ids = vim.fn.win_findbuf(buf_id)
                if #win_ids > 0 then
                    return true
                end
                
                -- Also consider current buffer as active even if not visible
                if buf_id == vim.api.nvim_get_current_buf() then
                    return true
                end
            end
        end
    end
    
    return false
end

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
    
    -- For stale entries, return the old value but still queue reprocessing
    local is_stale = cached and cached.status == "stale"
    
    -- If we have a stale entry, return it immediately and queue reprocessing in background
    if is_stale then
        -- Just return the stale value - reprocessing is handled by invalidate_file
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
    -- Check if it's an active buffer to skip size limits
    local is_active = false
    -- Safely check if file is active, defaulting to false if in fast event context
    local ok, result = pcall(M._is_file_in_active_buffer, path)
    if ok then
        is_active = result
    end
    
    local should_process, _ = processor.should_process_file(path, is_active)
    
    if not inst.processing[path] and should_process then
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
    
    -- Mark cache entry as stale instead of removing it completely
    -- This allows lualine to continue showing the old value until new one is ready
    local cached = inst.cache[file_path]
    if cached then
        cached.status = "stale"
        cached.timestamp = 0 -- Force cache miss on TTL check
    end
    
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
        inst.debounce_timers[debounce_key]:start(inst.config.request_debounce or 250, 0, function()
            vim.schedule(function()
                timer.process_queue_batch()
                inst.debounce_timers[debounce_key]:close()
                inst.debounce_timers[debounce_key] = nil
            end)
        end)
    end
end

--- Update cache with known token count (for commands that already have the result)
--- @param file_path string Path to the file
--- @param token_count number Token count to cache
--- @param notify boolean|nil Whether to notify UI components (default: true)
function M.update_cache_with_count(file_path, token_count, notify)
    local inst = instance_manager.get_instance()
    
    if not file_path or file_path == "" or not token_count then
        return
    end
    
    local formatted = processor.format_token_count(token_count)
    inst.cache[file_path] = {
        count = token_count,
        formatted = formatted,
        timestamp = vim.loop.hrtime() / 1000000,
        status = "ready",
        type = "file"
    }
    
    -- Notify UI components of cache update
    if notify ~= false then
        notifications.notify_cache_updated(file_path, "file")
    end
    
    require("token-count.log").info(string.format("Updated cache for %s: %s tokens", file_path, formatted))
end

--- Count tokens for a file immediately (bypasses queue)
--- @param file_path string Path to the file
--- @param callback function Callback function(result, error)
function M.count_file_immediate(file_path, callback)
	if not processor.should_process_file(file_path) then
		callback(nil, "File not valid for processing")
		return
	end
	
	processor.process_file(file_path, function(success, result)
		if success and result then
			-- Update cache automatically
			M.update_cache_with_count(file_path, result.count, true)
			callback(result, nil)
		else
			callback(nil, result or "Processing failed")
		end
	end)
end

--- Count tokens for a file in background queue
--- @param file_path string Path to the file
--- @param callback function|nil Optional callback function(result, error)
function M.count_file_background(file_path, callback)
	local inst = instance_manager.get_instance()
	
	if not processor.should_process_file(file_path) then
		if callback then callback(nil, "File not valid for processing") end
		return
	end
	
	-- Check if already processing or queued
	if inst.processing[file_path] then
		if callback then callback(nil, "Already processing") end
		return
	end
	
	local already_queued = false
	for _, queued_path in ipairs(inst.process_queue) do
		if queued_path == file_path then
			already_queued = true
			break
		end
	end
	
	if not already_queued then
		table.insert(inst.process_queue, file_path)
		timer.debounced_immediate_processing(file_path)
	end
	
	-- Store callback for when processing completes
	if callback then
		if not inst.background_callbacks then
			inst.background_callbacks = {}
		end
		if not inst.background_callbacks[file_path] then
			inst.background_callbacks[file_path] = {}
		end
		table.insert(inst.background_callbacks[file_path], callback)
	end
end

return M