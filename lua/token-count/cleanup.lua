--- Resource cleanup system for token-count.nvim
--- Prevents resource leaks by tracking and cleaning up timers, jobs, and memory
local M = {}

-- Track resources for cleanup (lightweight references only)
local tracked_resources = {
	timers = {}, -- timer_id -> timer_object
	jobs = {}, -- job_id -> true (just tracking existence)
	autocommand_groups = {}, -- group_name -> group_id
	cache_cleanup_timer = nil,
}

-- Cleanup configuration
local CLEANUP_CONFIG = {
	interval = 600000, -- 10 minutes between cleanup cycles
	max_cache_size = 2000, -- Maximum cache entries before forced cleanup
	max_debounce_timers = 50, -- Maximum debounce timers before cleanup
	stale_job_timeout = 300000, -- 5 minutes - consider jobs stale after this
}

-- Track job creation times to detect stale jobs
local job_timestamps = {}

--- Register a timer for cleanup tracking
--- @param timer userdata Timer object
--- @param identifier string Unique identifier
function M.register_timer(timer, identifier)
	if timer and identifier then
		tracked_resources.timers[identifier] = timer
	end
end

--- Register a job for cleanup tracking
--- @param job_id number Job ID
function M.register_job(job_id)
	if job_id and job_id > 0 then
		tracked_resources.jobs[job_id] = true
		job_timestamps[job_id] = vim.loop.hrtime() / 1000000
	end
end

--- Unregister a job when it completes
--- @param job_id number Job ID
function M.unregister_job(job_id)
	if job_id then
		tracked_resources.jobs[job_id] = nil
		job_timestamps[job_id] = nil
	end
end

--- Register an autocommand group for cleanup
--- @param group_id number Autocommand group ID
--- @param identifier string Unique identifier
function M.register_autocommand_group(group_id, identifier)
	if group_id and identifier then
		tracked_resources.autocommand_groups[identifier] = group_id
	end
end

--- Clean up stale timers
local function cleanup_stale_timers()
	local log = require("token-count.log")
	local cleaned_count = 0

	for identifier, timer in pairs(tracked_resources.timers) do
		if timer then
			-- Check if timer is still valid
			local success = pcall(function()
				return timer:is_closing()
			end)

			if not success or timer:is_closing() then
				tracked_resources.timers[identifier] = nil
				cleaned_count = cleaned_count + 1
			end
		else
			tracked_resources.timers[identifier] = nil
			cleaned_count = cleaned_count + 1
		end
	end

	if cleaned_count > 0 then
		log.warn(string.format("Cleaned up %d stale timer references", cleaned_count))
	end
end

--- Clean up stale jobs
local function cleanup_stale_jobs()
	local log = require("token-count.log")
	local now = vim.loop.hrtime() / 1000000
	local cleaned_count = 0

	for job_id, _ in pairs(tracked_resources.jobs) do
		local job_time = job_timestamps[job_id]

		-- Clean up jobs that are too old or no longer exist
		if not job_time or (now - job_time) > CLEANUP_CONFIG.stale_job_timeout then
			-- Try to stop the job if it's still running
			pcall(vim.fn.jobstop, job_id)

			tracked_resources.jobs[job_id] = nil
			job_timestamps[job_id] = nil
			cleaned_count = cleaned_count + 1
		end
	end

	if cleaned_count > 0 then
		log.warn(string.format("Cleaned up %d stale job references", cleaned_count))
	end
end

--- Clean up cache memory to prevent unbounded growth
local function cleanup_cache_memory()
	local instance_ok, instance_manager = pcall(require, "token-count.cache.instance")
	if not instance_ok then
		return
	end

	local instance = instance_manager.get_instance()
	local log = require("token-count.log")
	local now = vim.loop.hrtime() / 1000000

	-- Clean up expired cache entries
	local expired_count = 0
	for path, cached_item in pairs(instance.cache) do
		if cached_item.timestamp then
			local age = now - cached_item.timestamp
			local ttl = cached_item.type == "directory" and instance.config.directory_cache_ttl
				or instance.config.cache_ttl

			if age > ttl then
				instance.cache[path] = nil
				expired_count = expired_count + 1
			end
		end
	end

	-- Enforce size limits by removing oldest entries
	local cache_size = 0
	local cache_items = {}
	for path, cached_item in pairs(instance.cache) do
		cache_size = cache_size + 1
		table.insert(cache_items, { path = path, timestamp = cached_item.timestamp or 0 })
	end

	local size_cleaned = 0
	if cache_size > CLEANUP_CONFIG.max_cache_size then
		table.sort(cache_items, function(a, b)
			return a.timestamp < b.timestamp
		end)

		local to_remove = cache_size - CLEANUP_CONFIG.max_cache_size
		for i = 1, to_remove do
			instance.cache[cache_items[i].path] = nil
			size_cleaned = size_cleaned + 1
		end
	end

	-- Clean up excessive debounce timers
	local debounce_cleaned = 0
	if instance.debounce_timers then
		local debounce_count = 0
		local debounce_items = {}

		for key, timer in pairs(instance.debounce_timers) do
			if timer then
				debounce_count = debounce_count + 1
				table.insert(debounce_items, key)
			else
				instance.debounce_timers[key] = nil
			end
		end

		if debounce_count > CLEANUP_CONFIG.max_debounce_timers then
			-- Remove oldest debounce timers (arbitrary cleanup)
			for i = 1, debounce_count - CLEANUP_CONFIG.max_debounce_timers do
				local key = debounce_items[i]
				if instance.debounce_timers[key] then
					pcall(function()
						instance.debounce_timers[key]:stop()
						instance.debounce_timers[key]:close()
					end)
					instance.debounce_timers[key] = nil
					debounce_cleaned = debounce_cleaned + 1
				end
			end
		end
	end

	if expired_count > 0 or size_cleaned > 0 or debounce_cleaned > 0 then
		log.warn(
			string.format(
				"Cache cleanup: %d expired, %d size-limited, %d debounce timers",
				expired_count,
				size_cleaned,
				debounce_cleaned
			)
		)
	end
end

--- Perform periodic cleanup
local function periodic_cleanup()
	cleanup_stale_timers()
	cleanup_stale_jobs()
	cleanup_cache_memory()
end

--- Start the cleanup system
function M.start_cleanup_system()
	if tracked_resources.cache_cleanup_timer then
		return -- Already started
	end

	tracked_resources.cache_cleanup_timer = vim.loop.new_timer()
	tracked_resources.cache_cleanup_timer:start(CLEANUP_CONFIG.interval, CLEANUP_CONFIG.interval, function()
		vim.schedule(function()
			pcall(periodic_cleanup) -- Fail silently if cleanup has issues
		end)
	end)

	require("token-count.log").info("Resource cleanup system started")
end

--- Stop the cleanup system
function M.stop_cleanup_system()
	if tracked_resources.cache_cleanup_timer then
		tracked_resources.cache_cleanup_timer:stop()
		tracked_resources.cache_cleanup_timer:close()
		tracked_resources.cache_cleanup_timer = nil
	end
end

--- Full cleanup on plugin shutdown
function M.cleanup_all()
	local log = require("token-count.log")

	-- Stop cleanup timer
	M.stop_cleanup_system()

	-- Clean up all tracked timers
	for identifier, timer in pairs(tracked_resources.timers) do
		if timer then
			pcall(function()
				if not timer:is_closing() then
					timer:stop()
					timer:close()
				end
			end)
		end
	end
	tracked_resources.timers = {}

	-- Stop all tracked jobs
	for job_id, _ in pairs(tracked_resources.jobs) do
		pcall(vim.fn.jobstop, job_id)
	end
	tracked_resources.jobs = {}
	job_timestamps = {}

	-- Clean up autocommand groups
	for identifier, group_id in pairs(tracked_resources.autocommand_groups) do
		pcall(vim.api.nvim_del_augroup_by_id, group_id)
	end
	tracked_resources.autocommand_groups = {}

	log.warn("Plugin resource cleanup completed")
end

--- Initialize cleanup system (called during plugin setup)
function M.initialize()
	-- Set up VimLeave cleanup
	local augroup = vim.api.nvim_create_augroup("TokenCountCleanup", { clear = true })
	M.register_autocommand_group(augroup, "cleanup_augroup")

	vim.api.nvim_create_autocmd("VimLeave", {
		group = augroup,
		callback = function()
			M.cleanup_all()
		end,
		desc = "token-count.nvim resource cleanup on exit",
	})

	-- Start periodic cleanup
	M.start_cleanup_system()
end

return M
