local M = {}

-- Lazy load cleanup system to avoid circular dependencies
local function get_cleanup()
	local cleanup_ok, cleanup = pcall(require, "token-count.cleanup")
	return cleanup_ok and cleanup or nil
end
local pending_notifications = {}
local notification_timer = nil
local NOTIFICATION_BATCH_DELAY = 1000 -- 1 second

--- Flush pending notifications
local function flush_notifications()
	if #pending_notifications == 0 then
		return
	end

	-- Group by type for efficient updates
	local has_file_updates = false
	for _, notification in ipairs(pending_notifications) do
		if notification.path_type == "file" then
			has_file_updates = true
			break
		end
	end

	-- Only trigger UI updates if we have actual changes
	if has_file_updates then
		vim.schedule(function()
			-- Trigger neotree refresh if visible (batched)
			local neo_tree_ok, manager = pcall(require, "neo-tree.sources.manager")
			if neo_tree_ok then
				local state = manager.get_state("filesystem")
				if state and state.winid and vim.api.nvim_win_is_valid(state.winid) then
					manager.refresh("filesystem")
				end
			end
		end)
	end

	-- Trigger custom callbacks (but don't spam them)
	local instance = require("token-count.cache.instance").get_instance()
	local notifications_copy = vim.deepcopy(pending_notifications)
	if #instance.update_callbacks > 0 and #notifications_copy > 0 then
		vim.schedule(function()
			for _, callback in ipairs(instance.update_callbacks) do
				-- Only call with first notification to avoid spam
				pcall(callback, notifications_copy[1].path, notifications_copy[1].path_type)
			end
		end)
	end

	-- Clear pending notifications
	pending_notifications = {}
	notification_timer = nil
end

--- Notify UI components of cache updates
--- @param path string Path that was updated
--- @param path_type string Type of path ("file" or "directory")
function M.notify_cache_updated(path, path_type)
	-- Add to pending notifications
	table.insert(pending_notifications, {
		path = path,
		path_type = path_type,
		timestamp = vim.loop.hrtime() / 1000000,
	})

	-- Start or restart the batch timer
	if notification_timer then
		notification_timer:stop()
		notification_timer:close()
	end

	notification_timer = vim.loop.new_timer()
	
	-- Register timer for cleanup tracking
	local cleanup = get_cleanup()
	if cleanup then
		cleanup.register_timer(notification_timer, "notification_batch_timer")
	end
	
	notification_timer:start(NOTIFICATION_BATCH_DELAY, 0, function()
		flush_notifications()
	end)
end

--- Register callback for cache updates
--- @param callback function Callback function(path, path_type)
function M.register_update_callback(callback)
	local instance = require("token-count.cache.instance").get_instance()
	table.insert(instance.update_callbacks, callback)
end

return M
