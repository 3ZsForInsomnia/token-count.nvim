--- Directory token counting and scanning utilities
local M = {}

local log = require("token-count.log")
local processor = require("token-count.cache.processor")

--- Calculate directory token count by summing its files
--- @param dir_path string Directory path
--- @param callback function Callback function(count, error)
function M.calculate_directory_tokens(dir_path, callback)
    local total_tokens = 0
    local files_processed = 0
    local files_to_process = {}
    
    -- Scan directory for processable files (non-recursive for performance)
    local handle = vim.loop.fs_scandir(dir_path)
    if not handle then
        callback(0, "Cannot scan directory")
        return
    end
    
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
        local full_path = dir_path .. "/" .. name
        if type == "file" and processor.should_process_file(full_path) then
            table.insert(files_to_process, full_path)
        end
        name, type = vim.loop.fs_scandir_next(handle)
    end
    
    if #files_to_process == 0 then
        callback(0, nil)
        return
    end
    
    -- Process each file and sum tokens
    for _, file_path in ipairs(files_to_process) do
        processor.process_file(file_path, function(success, result)
            files_processed = files_processed + 1
            
            if success and result.count then
                total_tokens = total_tokens + result.count
            end
            
            -- Check if all files are processed
            if files_processed == #files_to_process then
                callback(total_tokens, nil)
            end
        end)
    end
end

--- Add files from a directory to the processing queue
--- @param dir_path string Directory path to scan
--- @param recursive boolean|nil Whether to scan recursively
function M.queue_directory_files(dir_path, recursive)
    local instance = require("token-count.cache.instance").get_instance()
    
    -- Validate directory path
    if not dir_path or dir_path == "" then
        log.warn("Invalid directory path provided to queue_directory_files")
        return
    end

    local handle = vim.loop.fs_scandir(dir_path)
    if not handle then
        log.warn("Failed to scan directory: " .. dir_path)
        return
    end
    
    local files_queued = 0
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
        local full_path = dir_path .. "/" .. name
        
        if type == "file" and processor.should_process_file(full_path) then
            -- Check if we need to process this file
            local cached = instance.cache[full_path]
            local now = vim.loop.hrtime() / 1000000
            
            if not cached or (now - cached.timestamp) > instance.config.cache_ttl then
                -- Avoid duplicates in queue
                local already_queued = false
                for _, queued_path in ipairs(instance.process_queue) do
                    if queued_path == full_path then
                        already_queued = true
                        break
                    end
                end
                
                if not already_queued and not instance.processing[full_path] then
                    table.insert(instance.process_queue, full_path)
                    files_queued = files_queued + 1
                end
            end
        elseif type == "directory" and recursive and not name:match("^%.") then
            -- Recursively scan subdirectories (but not hidden ones)
            M.queue_directory_files(full_path, recursive)
        end
        
        name, type = vim.loop.fs_scandir_next(handle)
    end
    
    if files_queued > 0 then
        log.info(string.format("Queued %d files from directory: %s", files_queued, dir_path))
    end
end

return M