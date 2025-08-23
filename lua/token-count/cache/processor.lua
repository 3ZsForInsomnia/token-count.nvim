--- File processing and validation utilities
local M = {}

local log = require("token-count.log")

function M.should_process_file(file_path)
    -- Skip if file path is empty or nil
    if not file_path or file_path == "" then
        return false
    end

    -- Quick filename checks before expensive file system operations
    local filename = file_path:match("([^/]+)$") or ""
    if filename:match("^%.") or filename:match("%.lock$") or filename:match("%.tmp$") then
        return false
    end

    -- Check file extension first (fastest check)
    local ext = file_path:match("%.([^%.]+)$")
    if not ext then
        return false
    end
    
    local valid_extensions = {
        -- Programming languages
        lua = true, py = true, js = true, ts = true, java = true, c = true, cpp = true, 
        rs = true, go = true, rb = true, php = true, swift = true, kt = true, scala = true,
        clj = true, hs = true, vim = true, sh = true, zsh = true, fish = true, ps1 = true,
        -- Web technologies  
        html = true, css = true, scss = true, sass = true, less = true, vue = true, 
        svelte = true, jsx = true, tsx = true, json = true, xml = true, yaml = true, 
        yml = true, toml = true,
        -- Documentation and text
        md = true, txt = true, rst = true, org = true, tex = true, latex = true,
        -- Configuration files
        conf = true, config = true, ini = true, cfg = true, properties = true,
        -- Data formats
        csv = true, tsv = true, sql = true, graphql = true, proto = true,
        -- Other
        log = true, diff = true, patch = true,
    }
    
    if not valid_extensions[ext:lower()] then
        return false
    end

    -- Only do file system checks for files with valid extensions
    local stat = vim.loop.fs_stat(file_path)
    if not stat or stat.type ~= "file" then
        return false
    end
    
    -- Skip binary files and very large files (>1MB)
    if stat.size > 1024 * 1024 then
        return false
    end

    return true
end

--- Format token count for display
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

function M.process_file(file_path, callback)
    local instance = require("token-count.cache.instance").get_instance()
    
    if instance.processing[file_path] then
        callback(false, "Already processing")
        return
    end
    
    instance.processing[file_path] = true
    
    -- Use libuv for truly async file reading to prevent any blocking
    vim.loop.fs_open(file_path, "r", 438, function(err, fd)
        if err or not fd then
            instance.processing[file_path] = nil
            callback(false, "Cannot open file: " .. (err or "unknown error"))
            return
        end
        
        vim.loop.fs_fstat(fd, function(stat_err, stat)
            if stat_err or not stat then
                vim.loop.fs_close(fd, function() end)
                instance.processing[file_path] = nil
                callback(false, "Cannot stat file: " .. (stat_err or "unknown error"))
                return
            end
            
            -- Skip large files to prevent memory issues
            if stat.size > 1024 * 1024 then -- 1MB limit
                vim.loop.fs_close(fd, function() end)
                instance.processing[file_path] = nil
                callback(false, "File too large")
                return
            end
            
            vim.loop.fs_read(fd, stat.size, 0, function(read_err, content)
                vim.loop.fs_close(fd, function() end)
                
                if read_err or not content then
                    instance.processing[file_path] = nil
                    callback(false, "Cannot read file content: " .. (read_err or "unknown error"))
                    return
                end
                
                if content == "" then
                    instance.processing[file_path] = nil
                    instance.cache[file_path] = {
                        count = 0,
                        formatted = "0",
                        timestamp = vim.loop.hrtime() / 1000000,
                        status = "ready",
                        type = "file"
                    }
                    callback(true, {count = 0, formatted = "0"})
                    return
                end
        
                -- Process content on next tick to prevent blocking
                vim.schedule(function()
                    M._process_content(file_path, content, callback)
                end)
            end)
        end)
    end)
end

--- Process file content (separated for better async flow)
--- @param file_path string File path
--- @param content string File content  
--- @param callback function Callback function
function M._process_content(file_path, content, callback)
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Get model and provider
    local models_ok, models = pcall(require, "token-count.models.utils")
    local config_module_ok, config_module = pcall(require, "token-count.config")
        
    if not (models_ok and config_module_ok) then
        instance.processing[file_path] = nil
        callback(false, "Missing dependencies")
        return
    end
        
    local current_config = config_module.get()
    local model_config = models.get_model(current_config.model)
    if not model_config then
        instance.processing[file_path] = nil
        callback(false, "Invalid model config")
        return
    end
        
    local provider = models.get_provider_handler(model_config.provider)
    if not provider then
        instance.processing[file_path] = nil
        callback(false, "Invalid provider")
        return
    end
        
    -- Count tokens asynchronously
    provider.count_tokens_async(content, model_config.encoding, function(count, error)
        instance.processing[file_path] = nil
            
        if count then
            local formatted = M.format_token_count(count)
            instance.cache[file_path] = {
                count = count,
                formatted = formatted,
                timestamp = vim.loop.hrtime() / 1000000,
                status = "ready",
                type = "file"
            }
            callback(true, {count = count, formatted = formatted})
        else
            callback(false, error or "Unknown error")
        end
    end)
end

return M