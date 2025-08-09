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
}

local cache = {}

--- Pending async requests to avoid duplicate calls
local pending_requests = {}

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

--- Get token count for a file path (cached with async updates)
--- @param file_path string Path to the file
--- @return string|nil formatted_count Formatted token count or nil if unavailable
local function get_file_token_count(file_path)
	-- Check cache
	local cache_key = file_path
	local cached = cache[cache_key]
	if cached and (vim.loop.hrtime() / 1000000 - cached.timestamp) < 30000 then -- 30 second cache
		return cached.formatted_count
	end

	-- Check if we already have a pending request for this file
	if pending_requests[cache_key] then
		-- Return cached value if available, even if expired
		return cached and cached.formatted_count
	end

	-- Try to get dependencies
	local models_ok, models = pcall(require, "token-count.models.utils")
	local config_module_ok, config_module = pcall(require, "token-count.config")

	if not (models_ok and config_module_ok) then
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

	-- Mark as pending and start async count
	pending_requests[cache_key] = true

	-- Count tokens asynchronously
	provider.count_tokens_async(content, model_config.encoding, function(count, error)
		-- Clear pending request
		pending_requests[cache_key] = nil

		if count then
			local formatted = format_token_count(count)
			cache[cache_key] = { formatted_count = formatted, timestamp = vim.loop.hrtime() / 1000000 }

			-- Trigger neo-tree refresh to update display
			vim.schedule(function()
				local neo_tree_ok, manager = pcall(require, "neo-tree.sources.manager")
				if neo_tree_ok then
					local state = manager.get_state("filesystem")
					if state then
						manager.refresh("filesystem")
					end
				end
			end)
		end
	end)

	-- Return cached value if available, or nil for first time
	return cached and cached.formatted_count
end

--- Token count component function for neo-tree
--- @param config table Component configuration
--- @param node table Neo-tree node
--- @param _ table State (unused)
--- @return table Component result with text and highlight
local function token_count_component(config, node, _)
	if node.type ~= "file" then
		return {}
	end

	local count = get_file_token_count(node:get_id())
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

--- Setup the neo-tree integration
--- @param user_config table|nil User configuration options
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
end

--- Get the token count component function for neo-tree
--- @return function Component function
function M.get_component()
	return token_count_component
end

--- Export the config for external access
M.config = config

--- Clear token count cache and pending requests
function M.clear_cache()
	cache = {}
	pending_requests = {}
end

--- Get current configuration
--- @return table config Current configuration
function M.get_config()
	return vim.deepcopy(config)
end

return M
