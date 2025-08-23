--- Setup and initialization for cache system
local M = {}

local instance_manager = require("token-count.cache.instance")
local directory = require("token-count.cache.directory")
local timer = require("token-count.cache.timer")

--- Setup the cache manager (singleton)
--- @param user_config table|nil User configuration
function M.setup(user_config)
    local inst = instance_manager.get_instance()
    
    if user_config then
        inst.config = vim.tbl_deep_extend("force", inst.config, user_config)
    end
    
    timer.start_timer()
    
    M._setup_autocommands()
    M._queue_initial_directory()
end

--- Set up autocommands for directory change detection
function M._setup_autocommands()
    local augroup = vim.api.nvim_create_augroup("TokenCountCacheUnified", { clear = true })
    
    vim.api.nvim_create_autocmd("DirChanged", {
        group = augroup,
        callback = function()
            local cwd = vim.fn.getcwd()
            directory.queue_directory_files(cwd, false) -- Non-recursive by default
        end,
        desc = "Queue directory files for token counting when directory changes",
    })
end

--- Queue initial directory files
function M._queue_initial_directory()
    vim.schedule(function()
        local cwd = vim.fn.getcwd()
        directory.queue_directory_files(cwd, false)
    end)
end

return M