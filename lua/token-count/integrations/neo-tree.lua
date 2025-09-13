
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
		local file_path = node:get_id()
		local cache_manager = get_cache_manager()
		
		-- Check if we have a cached count
		count = cache_manager.get_file_token_count(file_path)
		
		-- If no cached count and we haven't requested this file before, request it now
		if not count or count == cache_manager.get_config().placeholder_text then
			local instance = require("token-count.cache.instance").get_instance()
			if not instance.neo_tree_requested[file_path] then
				instance.neo_tree_requested[file_path] = true
				-- Queue for background processing
				cache_manager.count_file_background(file_path, function(result, error)
					-- Result will be cached automatically, neo-tree will refresh on next display
				end)
			end
		end
	elseif node.type == "directory" then
		-- No longer support directory token counting to avoid bulk processing
		return {}
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
	
	-- Neo-tree now uses reactive token counting - files are only processed when
	-- they become visible and only once per session via the neo_tree_requested tracking
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
