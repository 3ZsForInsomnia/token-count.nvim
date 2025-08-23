local M = {}

--- Lazy loading state
local _cache_setup_complete = false

--- Setup the cache manager (singleton)
--- @param user_config table|nil User configuration
function M.setup(user_config)
	-- Prevent double setup
	if _cache_setup_complete then
		return
	end
	_cache_setup_complete = true
	
    local instance_manager = require("token-count.cache.instance")
    local inst = instance_manager.get_instance()
    
    if user_config then
        inst.config = vim.tbl_deep_extend("force", inst.config, user_config)
    end
    
    -- Only start timer if caching is actually enabled
    if inst.config.enable_file_caching or inst.config.enable_directory_caching then
		-- Don't start timer immediately if lazy_start is enabled
		if not inst.config.lazy_start then
			local timer = require("token-count.cache.timer")
			timer.start_timer()
		end
	end
    
    -- Defer autocommands and directory queuing to avoid blocking startup
    vim.schedule(function()
		M._setup_autocommands()
		M._queue_initial_directory()
	end)
end

--- Set up autocommands for directory change detection
function M._setup_autocommands()
    local augroup = vim.api.nvim_create_augroup("TokenCountCacheUnified", { clear = true })
    
    vim.api.nvim_create_autocmd("DirChanged", {
        group = augroup,
        callback = function()
            local cwd = vim.fn.getcwd()
            -- Lazy load directory module
            local directory = require("token-count.cache.directory")
            directory.queue_directory_files(cwd, false) -- Non-recursive by default
        end,
        desc = "Queue directory files for token counting when directory changes",
    })
end

--- Queue initial directory files
function M._queue_initial_directory()
    -- Only queue if we have a valid working directory
    local cwd = vim.fn.getcwd()
    if cwd and cwd ~= "" then
		-- Lazy load directory module
		local directory = require("token-count.cache.directory")
		directory.queue_directory_files(cwd, false)
	end
end

return M