-- Neo-tree integration for token-count.nvim
-- Provides both a custom component and a dedicated token count source

local M = {}

--- Default configuration
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
		enabled = true,
		name = "token_count",
		display_name = "Token Count",
		-- Extensible for future features
		components = {
			token_count = true,
			-- Future: context_usage = true, model_info = true, etc.
		},
	},
}

--- Cache for token counts to avoid recalculation
local cache = {}

--- Format token count for display
--- @param count number Token count
--- @return string formatted Formatted display string
local function format_token_count(count)
	if count >= 1000000 then
		require("token-count.log").info("I dare you to try adding this nonsense to your AI context")
		return "HUGE"
	elseif count >= config.component.show_decimals_threshold then
		if count >= 1000000 then
			return math.floor(count / 1000000) .. "M"
		elseif count >= 1000 then
			return math.floor(count / 1000) .. "k"
		end
	else
		if count >= 1000 then
			return string.format("%.1fk", count / 1000)
		end
	end

	return tostring(count)
end

--- Get token count for a file path (cached)
--- @param file_path string Path to the file
--- @return string|nil formatted_count Formatted token count or nil if unavailable
local function get_file_token_count(file_path)
	-- Check cache
	local cache_key = file_path
	local cached = cache[cache_key]
	if cached and (vim.loop.hrtime() / 1000000 - cached.timestamp) < 30000 then -- 30 second cache
		return cached.formatted_count
	end

	-- Try to get token count
	local buffer_ops_ok, buffer_ops = pcall(require, "token-count.utils.buffer_ops")
	local models_ok, models = pcall(require, "token-count.models.utils")
	local config_module_ok, config_module = pcall(require, "token-count.config")

	if not (buffer_ops_ok and models_ok and config_module_ok) then
		return nil
	end

	-- Read file content
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	if not content or content == "" then
		cache[cache_key] = { formatted_count = "0", timestamp = vim.loop.hrtime() / 1000000 }
		return "0"
	end

	-- Get model and provider
	local current_config = config_module.get()
	local model_config = models.get_model(current_config.model)
	if not model_config then
		return nil
	end

	local provider = models.get_provider_handler(model_config.provider)
	if not provider then
		return nil
	end

	-- Count tokens synchronously (for immediate display)
	local count, error = provider.count_tokens_sync(content, model_config.encoding)
	if count then
		local formatted = format_token_count(count)
		cache[cache_key] = { formatted_count = formatted, timestamp = vim.loop.hrtime() / 1000000 }
		return formatted
	end

	return nil
end

--- Token count component for file renderer
local token_count_component = {
	provider = function(props)
		local node = props.tree.state.tree:get_node()
		if node.type ~= "file" then
			return ""
		end

		local count = get_file_token_count(node.path)
		if not count then
			return ""
		end

		local display = ""

		-- Add icon based on configuration
		if config.component.show_icon then
			local icon = config.component.icon
			-- Fallback to simple character if icon might not render
			if icon == "🪙" then
				-- Simple heuristic: if we can't determine font support, use fallback
				icon = config.component.icon_fallback
			end

			if config.component.icon_position == "left" then
				display = icon .. count
			elseif config.component.icon_position == "right" then
				display = count .. icon
			else
				display = count
			end
		else
			display = count
		end

		return display
	end,
	highlight = "TokenCountComponent",
}

--- Setup the neo-tree integration
--- @param user_config table|nil User configuration options
function M.setup(user_config)
	-- Merge user config
	if user_config then
		config = vim.tbl_deep_extend("force", config, user_config)
	end

	-- Register custom component
	if config.component.enabled then
		local renderer = require("neo-tree.ui.renderer")
		renderer.define_component("token_count", token_count_component)
	end

	-- Register custom source
	if config.source.enabled then
		M.register_source()
	end

	-- Set up highlight group
	vim.api.nvim_set_hl(0, "TokenCountComponent", { fg = "#98c379", default = true })
end

--- Register the token count source for neo-tree
function M.register_source()
	local sources = require("neo-tree.sources.manager")

	local token_count_source = {
		name = config.source.name,
		display_name = config.source.display_name,

		-- Use filesystem as base and extend it
		setup = function(state, opts)
			local filesystem = require("neo-tree.sources.filesystem")
			return filesystem.setup(state, opts)
		end,

		refresh = function(state)
			local filesystem = require("neo-tree.sources.filesystem")
			-- Clear cache on refresh
			cache = {}
			return filesystem.refresh(state)
		end,

		navigate = function(state, path)
			local filesystem = require("neo-tree.sources.filesystem")
			return filesystem.navigate(state, path)
		end,

		-- Custom renderers that include token count
		renderers = {
			file = {
				{ "icon" },
				{ "name", use_git_status_colors = true },
				{ "token_count" },
				{ "git_status" },
				{ "diagnostics" },
			},
			directory = {
				{ "icon" },
				{ "name", use_git_status_colors = true },
				{ "git_status" },
				{ "diagnostics" },
			},
		},
	}

	sources.register(token_count_source)
end

--- Clear token count cache
function M.clear_cache()
	cache = {}
end

--- Get current configuration
--- @return table config Current configuration
function M.get_config()
	return vim.deepcopy(config)
end

return M
