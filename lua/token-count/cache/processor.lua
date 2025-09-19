--- Enhanced background processing with better resource management
local M = {}

local log = require("token-count.log")

-- Resource limits to prevent UI blocking
local RESOURCE_LIMITS = {
    MAX_CONCURRENT_JOBS = 3,        -- Max simultaneous processing jobs
    MAX_FILE_SIZE_BYTES = 1024 * 512,  -- 512KB max file size (was 1MB)
    PROCESSING_BATCH_SIZE = 1,      -- Process 1 file at a time (keep ultra-conservative)
    YIELD_FREQUENCY = 5,            -- Yield control every N operations
    MEMORY_CHECK_INTERVAL = 100,    -- Check memory usage every N files
    MAX_QUEUE_SIZE = 50,           -- Maximum number of files in queue
}

-- Global state for resource management
local processing_stats = {
    active_jobs = 0,
    processed_files = 0,
    last_memory_check = 0,
    last_yield = 0,
}

--- Check if file is in an active or visible buffer
--- @param file_path string File path to check
--- @return boolean is_active Whether file is in active/visible buffer
local function is_file_in_active_buffer(file_path)
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

--- Check if we should process this file based on resource constraints
--- @param file_path string File path to check
--- @return boolean should_process Whether to process this file
--- @return string? reason Reason if not processing
function M.should_process_file(file_path, skip_size_check)
    -- Original file validation checks
    if not file_path or file_path == "" then
        return false, "empty_path"
    end

    local filename = file_path:match("([^/]+)$") or ""
    if filename:match("^%.") or filename:match("%.lock$") or filename:match("%.tmp$") then
        return false, "skip_file_type"
    end

    local ext = file_path:match("%.([^%.]+)$")
    if not ext then
        return false, "no_extension"
    end
    
    local valid_extensions = {
        lua = true, py = true, js = true, ts = true, java = true, c = true, cpp = true, 
        rs = true, go = true, rb = true, php = true, swift = true, kt = true, scala = true,
        clj = true, hs = true, vim = true, sh = true, zsh = true, fish = true, ps1 = true,
        html = true, css = true, scss = true, sass = true, less = true, vue = true, 
        svelte = true, jsx = true, tsx = true, json = true, xml = true, yaml = true, 
        yml = true, toml = true,
        md = true, txt = true, rst = true, org = true, tex = true, latex = true,
        conf = true, config = true, ini = true, cfg = true, properties = true,
        csv = true, tsv = true, sql = true, graphql = true, proto = true,
        log = true, diff = true, patch = true,
    }
    
    if not valid_extensions[ext:lower()] then
        return false, "invalid_extension"
    end

    -- Resource constraint checks
    if processing_stats.active_jobs >= RESOURCE_LIMITS.MAX_CONCURRENT_JOBS then
        return false, "max_concurrent_jobs"
    end

    local stat = vim.loop.fs_stat(file_path)
    if not stat or stat.type ~= "file" then
        return false, "not_file"
    end
    
    -- Skip size check for active/visible buffers or if explicitly requested
    if not skip_size_check and stat.size > RESOURCE_LIMITS.MAX_FILE_SIZE_BYTES then
        return false, "file_too_large"
    end

    return true, nil
end

--- Format token count with conservative memory usage
--- @param count number Token count
--- @return string formatted Formatted display string
function M.format_token_count(count)
    if count >= 1000000 then
        return "HUGE"
    elseif count >= 10000 then
        if count >= 1000000 then
            return math.floor(count / 1000000) .. "M"
        elseif count >= 1000 then
            return math.floor(count / 1000) .. "k"
        end
    else
        if count >= 1000 then
            return string.format("%.1fk", count / 1000)
        end
    end
    return tostring(count)
end

--- Process file with enhanced background operation
--- @param file_path string File path to process
--- @param callback function Callback function
function M.process_file(file_path, callback)
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Check if already processing
    if instance.processing[file_path] then
        callback(false, "Already processing")
        return
    end
    
    -- Check if file is in active/visible buffer
    local is_active = false
    -- Safely check if file is active, defaulting to false if in fast event context
    local ok, result = pcall(is_file_in_active_buffer, file_path)
    if ok then
        is_active = result
    end
    
    -- Check resource constraints (skip size check for active buffers)
    local should_process, reason = M.should_process_file(file_path, is_active)
    if not should_process then
        if reason == "file_too_large" then
            -- Provide estimate for large files not in active buffers
            M._handle_large_file(file_path, callback)
            return
        else
            callback(false, "Skipped: " .. (reason or "unknown"))
            return
        end
    end
    
    -- Track active job
    processing_stats.active_jobs = processing_stats.active_jobs + 1
    instance.processing[file_path] = true
    
    -- Use more conservative async file reading, but allow larger files for active buffers
    M._read_file_chunked(file_path, is_active, function(success, content, error)
        processing_stats.active_jobs = processing_stats.active_jobs - 1
        instance.processing[file_path] = nil
        
        if not success then
            callback(false, error)
            return
        end
        
        if content == "" then
            M._cache_empty_file(file_path, instance)
            callback(true, {count = 0, formatted = "0"})
            return
        end
        
        -- Yield control more frequently during processing
        M._maybe_yield(function()
            M._process_content_background(file_path, content, callback)
        end)
    end)
end

--- Handle large files with estimation
--- @param file_path string File path
--- @param callback function Callback function
function M._handle_large_file(file_path, callback)
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Read just the first 1KB to estimate
    vim.loop.fs_open(file_path, "r", 438, function(err, fd)
        if err or not fd then
            callback(false, "Cannot open large file")
            return
        end
        
        vim.loop.fs_read(fd, 1024, 0, function(read_err, content)
            vim.loop.fs_close(fd, function() end)
            
            if read_err or not content then
                callback(false, "Cannot read large file sample")
                return
            end
            
            -- Estimate based on sample
            local errors = require("token-count.utils.errors")
            local estimate, method = errors.get_fallback_estimate(content)
            
            -- Scale estimate based on file size
            local stat = vim.loop.fs_stat(file_path)
            if stat then
                local scale_factor = stat.size / 1024
                estimate = math.floor(estimate * scale_factor)
            end
            
            local formatted = M.format_token_count(estimate)
            instance.cache[file_path] = {
                count = estimate,
                formatted = formatted .. "*", -- Add asterisk to indicate estimate
                timestamp = vim.loop.hrtime() / 1000000,
                status = "estimated",
                type = "file"
            }
            
            callback(true, {count = estimate, formatted = formatted .. "*"})
        end)
    end)
end

--- Read file in chunks to prevent memory issues
--- @param file_path string File path
--- @param is_active_buffer boolean Whether file is in active/visible buffer
--- @param callback function Callback function(success, content, error)
function M._read_file_chunked(file_path, is_active_buffer, callback)
    vim.loop.fs_open(file_path, "r", 438, function(err, fd)
        if err or not fd then
            callback(false, nil, "Cannot open file: " .. (err or "unknown error"))
            return
        end
        
        vim.loop.fs_fstat(fd, function(stat_err, stat)
            if stat_err or not stat then
                vim.loop.fs_close(fd, function() end)
                callback(false, nil, "Cannot stat file: " .. (stat_err or "unknown error"))
                return
            end
            
            -- Check size limits only for non-active buffers
            if not is_active_buffer and stat.size > RESOURCE_LIMITS.MAX_FILE_SIZE_BYTES then
                vim.loop.fs_close(fd, function() end)
                callback(false, nil, "File too large")
                return
            end
        
        -- For very large active buffer files (>10MB), warn but still process
        if is_active_buffer and stat.size > 10 * 1024 * 1024 then
            require("token-count.log").warn(string.format(
                "Processing very large active file: %s (%.1fMB)", 
                file_path, 
                stat.size / (1024 * 1024)
            ))
        end
            
            vim.loop.fs_read(fd, stat.size, 0, function(read_err, content)
                vim.loop.fs_close(fd, function() end)
                
                if read_err or not content then
                    callback(false, nil, "Cannot read file content: " .. (read_err or "unknown error"))
                    return
                end
                
                callback(true, content, nil)
            end)
        end)
    end)
end

--- Cache empty file result
--- @param file_path string File path
--- @param instance table Cache instance
function M._cache_empty_file(file_path, instance)
    instance.cache[file_path] = {
        count = 0,
        formatted = "0",
        timestamp = vim.loop.hrtime() / 1000000,
        status = "ready",
        type = "file"
    }
end

--- Maybe yield control to prevent UI blocking
--- @param next_fn function Function to call after yield
function M._maybe_yield(next_fn)
    processing_stats.last_yield = processing_stats.last_yield + 1
    
    if processing_stats.last_yield >= RESOURCE_LIMITS.YIELD_FREQUENCY then
        processing_stats.last_yield = 0
        -- Use vim.schedule to yield control back to UI
        vim.schedule(function()
            next_fn()
        end)
    else
        next_fn()
    end
end

--- Process file content with background-friendly approach
--- @param file_path string File path
--- @param content string File content  
--- @param callback function Callback function
function M._process_content_background(file_path, content, callback)
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Get model and provider with error handling
    local models_ok, models = pcall(require, "token-count.models.utils")
    local config_module_ok, config_module = pcall(require, "token-count.config")
        
    if not (models_ok and config_module_ok) then
        callback(false, "Missing dependencies")
        return
    end
        
    local current_config = config_module.get()
    local model_config = models.get_model(current_config.model)
    if not model_config then
        callback(false, "Invalid model config")
        return
    end
        
    local provider = models.get_provider_handler(model_config.provider)
    if not provider then
        -- Use fallback estimation instead of failing
        local errors = require("token-count.utils.errors")
        local estimate, method = errors.get_fallback_estimate(content)
        local formatted = M.format_token_count(estimate)
        
        instance.cache[file_path] = {
            count = estimate,
            formatted = formatted .. "~", -- Add tilde to indicate fallback
            timestamp = vim.loop.hrtime() / 1000000,
            status = "estimated",
            type = "file"
        }
        
        callback(true, {count = estimate, formatted = formatted .. "~"})
        return
    end
        
    -- Count tokens with provider
    provider.count_tokens_async(content, model_config.encoding, function(count, error)
        if count then
            local formatted = M.format_token_count(count)
            instance.cache[file_path] = {
                count = count,
                formatted = formatted,
                timestamp = vim.loop.hrtime() / 1000000,
                status = "ready",
                type = "file"
            }
            
            -- Call any background callbacks waiting for this file
            if instance.background_callbacks and instance.background_callbacks[file_path] then
                for _, bg_callback in ipairs(instance.background_callbacks[file_path]) do
                    pcall(bg_callback, {count = count, formatted = formatted}, nil)
                end
                instance.background_callbacks[file_path] = nil
            end
            
            callback(true, {count = count, formatted = formatted})
        else
            -- Use fallback estimation on provider error
            local errors = require("token-count.utils.errors")
            local estimate, method = errors.get_fallback_estimate(content)
            local formatted = M.format_token_count(estimate)
            
            instance.cache[file_path] = {
                count = estimate,
                formatted = formatted .. "~",
                timestamp = vim.loop.hrtime() / 1000000,
                status = "estimated",
                type = "file"
            }
            
            -- Call any background callbacks with estimated result
            if instance.background_callbacks and instance.background_callbacks[file_path] then
                for _, bg_callback in ipairs(instance.background_callbacks[file_path]) do
                    pcall(bg_callback, {count = estimate, formatted = formatted .. "~"}, nil)
                end
                instance.background_callbacks[file_path] = nil
            end
            
            log.warn(string.format("Provider failed for %s, using estimate: %s", file_path, error or "unknown error"))
            callback(true, {count = estimate, formatted = formatted .. "~"})
        end
    end)
end

return M