local M = {}

local log = require("token-count.log")

 local processing_stats = { active_jobs = 0, last_yield = 0 }
 
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

function M.should_process_file(file_path, skip_size_check)
    -- Original file validation checks
    if not file_path or file_path == "" then
        return false, "empty_path"
    end

    -- Check ignore patterns
    local config = require("token-count.config").get()
    for _, pattern in ipairs(config.ignore_patterns or {}) do
        if file_path:match(pattern) then
            return false, "ignored_pattern"
        end
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
        "lua", "py", "js", "ts", "tsx", "jsx", "java", "c", "cpp", "go", "rs", "rb", "php", 
        "swift", "kt", "scala", "clj", "hs", "vim", "sh", "zsh", "fish", "ps1",
        "html", "css", "scss", "sass", "less", "vue", "svelte", "json", "xml", "yaml", "yml", "toml",
        "md", "txt", "rst", "org", "tex", "conf", "ini", "cfg", "csv", "sql", "diff", "patch"
    }
    
    local ext_set = {}
    for _, valid_ext in ipairs(valid_extensions) do
        ext_set[valid_ext] = true
    end
    
    if not ext_set[ext:lower()] then
        return false, "invalid_extension"
    end

    local stat = vim.loop.fs_stat(file_path)
    if not stat or stat.type ~= "file" then
        return false, "not_file"
    end
    
    if not skip_size_check and stat.size > 512 * 1024 then
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

 --- Handle files that exceed size limit
 --- @param file_path string File path
 --- @param instance table Cache instance
 --- @param callback function Callback function
 function M._handle_oversized_file(file_path, instance, callback)
     -- Return "LARGE" for oversized files to make it more obvious
     local formatted = "LARGE"
     instance.cache[file_path] = {
         count = 999999, -- High count to indicate large file
         formatted = formatted,
         timestamp = vim.loop.hrtime() / 1000000,
         status = "oversized",
         type = "file"
     }
    
    log.info(string.format("File %s exceeds 512KB limit, showing as %s", file_path, formatted))
    callback(true, {count = 999999, formatted = formatted})
end
 
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
            -- Handle oversized files with "LARGE" display
            M._handle_oversized_file(file_path, instance, callback)
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
            
            -- Check size limits for all files (simplified approach)
            if stat.size > 512 * 1024 then
                vim.loop.fs_close(fd, function() end)
                callback(false, nil, "File too large")
                return
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
    -- Simplified - just call directly
    next_fn()
end

--- Process file content with background-friendly approach
--- @param file_path string File path
--- @param content string File content  
--- @param callback function Callback function
function M._process_content_background(file_path, content, callback)
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Get model and provider
    local models = require("token-count.models.utils")
    local config_module = require("token-count.config")
    local current_config = config_module.get()
    local model_config = models.get_model(current_config.model)
    
    if not model_config then
        callback(false, "Invalid model config")
        return
    end
    
    local provider = models.get_provider_handler(model_config.provider)
    if not provider then
        callback(false, "Provider not available")
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
            
            -- Trigger UI updates immediately
            local notifications = require("token-count.cache.notifications")
            notifications.notify_cache_updated(file_path, "file")
            
            -- Call any background callbacks waiting for this file
            if instance.background_callbacks and instance.background_callbacks[file_path] then
                for _, bg_callback in ipairs(instance.background_callbacks[file_path]) do
                    pcall(bg_callback, {count = count, formatted = formatted}, nil)
                end
                instance.background_callbacks[file_path] = nil
            end
            
            callback(true, {count = count, formatted = formatted})
        else
            log.warn(string.format("Provider failed for %s: %s", file_path, error or "unknown error"))
            
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
            
            -- Trigger UI updates for estimated results too
            local notifications = require("token-count.cache.notifications")
            notifications.notify_cache_updated(file_path, "file")
            
            -- Call any background callbacks with estimated result
            if instance.background_callbacks and instance.background_callbacks[file_path] then
                for _, bg_callback in ipairs(instance.background_callbacks[file_path]) do
                    pcall(bg_callback, {count = estimate, formatted = formatted .. "~"}, nil)
                end
                instance.background_callbacks[file_path] = nil
            end
            
            callback(true, {count = estimate, formatted = formatted .. "~"})
        end
    end)
end

return M
