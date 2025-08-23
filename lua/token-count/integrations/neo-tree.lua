
local M = {}

local config = {
	component = {
		enabled = true,
		show_icon = true,
		icon = "🪙",
		icon_fallback = "t",
		icon_position = "right", -- "left", "right", "none"
		show_decimals_threshold = 10000, -- Show decimals under 10k
	},
	source = {
		enabled = false, -- Disabled by default, can be enabled by users
	},
}

--- Get cache manager (lazy loaded)
local function get_cache_manager()
	return require("token-count.cache")
end

local function token_count_component(config, node, _)
	local count
	if node.type == "file" then
		count = get_cache_manager().get_file_token_count(node:get_id())
	elseif node.type == "directory" then
		count = get_cache_manager().get_directory_token_count(node:get_id())
	else
		return {}
	end
	
	if not count then
		return {}
	end

	local display = ""

	-- Add icon based on configuration
	if M.config.component.show_icon then
		local icon = M.config.component.icon

		if M.config.component.icon_position == "left" then
			display = icon .. count
		elseif M.config.component.icon_position == "right" then
			display = count .. icon
		else
			display = count
		end
	else
		display = count
	end

	return {
		text = " " .. display,
		highlight = config.highlight or "TokenCountComponent",
	}
end

function M.setup(user_config)
	-- Merge user config
	if user_config then
		M.config = vim.tbl_deep_extend("force", config, user_config)
	else
		M.config = config
	end

	-- Register custom source
	if M.config.source.enabled then
		M.register_source()
	end

	-- Set up highlight group
	vim.api.nvim_set_hl(0, "TokenCountComponent", { fg = "#98c379", default = true })
	
	-- Set up neotree event handlers for dynamic directory scanning
	local events = require("neo-tree.events")
	
	-- Throttle directory scanning to prevent UI blocking
	local last_scan_time = {}
	local SCAN_THROTTLE_MS = 10000 -- 10 seconds - much more conservative
	
	local function should_scan_directory(dir_path)
		local now = vim.loop.hrtime() / 1000000
		local last_scan = last_scan_time[dir_path] or 0
		if (now - last_scan) < SCAN_THROTTLE_MS then
			return false
		end
		last_scan_time[dir_path] = now
		return true
	end
	
	events.subscribe({
		event = "neo_tree_buffer_enter",
		handler = function(state)
			-- Very conservative directory scanning with long delay
			vim.defer_fn(function()
				if state.tree and state.tree:get_nodes() then
					local dirs_to_scan = {}
					for _, node in ipairs(state.tree:get_nodes()) do
						if node.type == "directory" and node:is_expanded() and should_scan_directory(node:get_id()) then
							table.insert(dirs_to_scan, node:get_id())
						end
					end
					
					-- Only scan a few directories at a time
					for i = 1, math.min(2, #dirs_to_scan) do
						vim.defer_fn(function()
							get_cache_manager().queue_directory_files(dirs_to_scan[i], false)
						end, i * 1000) -- 1 second between each directory
					end
				end
			end, 2000) -- 2 second delay before starting
		end,
	})
	
	events.subscribe({
		event = "neo_tree_popup_buffer_enter", 
		handler = function(state)
			-- Very conservative scanning when neotree opens
			vim.defer_fn(function()
				if state.path and should_scan_directory(state.path) then
					get_cache_manager().queue_directory_files(state.path, false)
				end
			end, 3000) -- 3 second delay
		end,
	})
end

function M.get_component()
	return token_count_component
end

M.config = config

function M.clear_cache()
	get_cache_manager().clear_cache()
end

function M.get_config()
	return vim.deepcopy(config)
end

function M.get_cache_stats()
	return get_cache_manager().get_stats()
end
return M
