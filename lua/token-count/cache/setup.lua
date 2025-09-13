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
		-- No longer doing proactive directory scanning
		-- Files are processed on-demand when requested by integrations
	end)
end

function M._setup_autocommands()
   	-- No longer using DirChanged events for proactive scanning
   	-- Files are processed reactively when requested by integrations
end

function M._queue_initial_directory()
   	-- No longer doing initial directory queuing
   	-- Files are processed on-demand when requested
end

return M