local M = {}

local instance = nil

-- Lazy load cleanup system to avoid circular dependencies
local function get_cleanup()
	local cleanup_ok, cleanup = pcall(require, "token-count.cleanup")
	return cleanup_ok and cleanup or nil
end
local function init_instance()
	if instance then
		return instance
	end

	instance = {
		-- Cache storage: path -> {count, formatted, timestamp, status, type}
		cache = {},

		-- Files/directories currently being processed
		processing = {},

		-- Timer for background updates
		timer = nil,

		-- Queue of paths to process
		process_queue = {},

		-- Files that have been requested by neo-tree (to avoid re-requesting)
		neo_tree_requested = {},

		-- Callbacks for background processing completion
		background_callbacks = {},

		-- Configuration
		config = {
			interval = 60000, -- 1 minute - only for TTL expiration now
			max_files_per_batch = 1, -- Always process 1 file at a time
			cache_ttl = 600000, -- 10 minutes cache TTL for non-buffer files
			directory_cache_ttl = 600000, -- 10 minutes for directories
			placeholder_text = "⋯", -- Placeholder while counting
			enable_directory_caching = false, -- Disabled - only file caching now
			enable_file_caching = true,
			request_debounce = 500, -- 500ms debounce for better UI responsiveness
			lazy_start = true, -- Start timer only when first request is made

			-- Enhanced performance settings
			max_concurrent_processing = 2, -- Max simultaneous processing jobs
			ui_responsiveness_check = true, -- Skip processing when UI is busy
			adaptive_intervals = true, -- Use adaptive processing intervals
			background_priority = true, -- Prioritize UI responsiveness over processing speed
		},

		-- Callbacks for UI updates
		update_callbacks = {},

		-- Throttling
		last_batch_time = 0,

		-- Debounce timers
		debounce_timers = {},

		-- Lazy initialization state
		timer_started = false,
	}

	return instance
end

--- Get singleton instance
--- @return table instance The singleton cache manager instance
function M.get_instance()
	return instance or init_instance()
end

function M.reset_instance()
	if instance and instance.timer then
		instance.timer:stop()
		instance.timer:close()

		-- Cleanup debounce timers
		if instance.debounce_timers then
			for key, timer in pairs(instance.debounce_timers) do
				if timer then
					pcall(function()
						timer:stop()
						timer:close()
					end)
				end
			end
		end
	end
	instance = nil
end

return M
