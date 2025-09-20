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
    
    -- Start background processing timer
    if inst.config.enable_file_caching or inst.config.enable_directory_caching then
		local timer = require("token-count.cache.timer")
		timer.start_timer()
	end
    
    -- Complete setup in next tick
    vim.schedule(function()
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