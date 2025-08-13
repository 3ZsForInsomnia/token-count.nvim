local M = {}

--- Setup function for token-count.nvim
--- @param opts table|nil User configuration options
function M.setup(opts)
	-- Setup configuration
	local config = require("token-count.config")
	config.setup(opts)

	-- Create user commands
	vim.api.nvim_create_user_command("TokenCount", function()
		require("token-count.commands").count_current_buffer()
	end, {
		desc = "Count tokens in current buffer",
	})

	vim.api.nvim_create_user_command("TokenCountModel", function()
		require("token-count.commands").change_model()
	end, {
		desc = "Change the token counting model",
	})

	vim.api.nvim_create_user_command("TokenCountAll", function()
		require("token-count.commands").count_all_buffers()
	end, {
		desc = "Count tokens in all valid buffers",
	})

	vim.api.nvim_create_user_command("TokenCountSelection", function()
		require("token-count.commands").count_visual_selection()
	end, {
		desc = "Count tokens in current visual selection",
	})

	-- Virtual environment management commands
	vim.api.nvim_create_user_command("TokenCountVenvStatus", function()
		local venv = require("token-count.venv")
		local status = venv.get_status()

		local lines = {
			"=== Token Count Virtual Environment Status ===",
			"Python 3 available: "
				.. (status.python_available and "✓" or "✗")
				.. " "
				.. (status.python_info or "Not found"),
			"Virtual environment: " .. (status.venv_exists and "✓" or "✗") .. " " .. status.venv_path,
			"Python executable: " .. status.python_path,
			"tiktoken installed: "
				.. (status.tiktoken_installed and "✓" or "✗")
				.. (status.tiktoken_error and (" (" .. status.tiktoken_error .. ")") or ""),
			"Ready: " .. (status.ready and "✓" or "✗"),
		}

		for _, line in ipairs(lines) do
			print(line)
		end
	end, {
		desc = "Show virtual environment status",
	})

	vim.api.nvim_create_user_command("TokenCountVenvSetup", function()
		local venv = require("token-count.venv")
		vim.notify("Setting up virtual environment...", vim.log.levels.INFO)

		venv.setup_venv(function(success, error)
			if success then
				vim.notify("Virtual environment setup complete!", vim.log.levels.INFO)
			else
				vim.notify("Setup failed: " .. (error or "unknown error"), vim.log.levels.ERROR)
			end
		end)
	end, {
		desc = "Set up or repair the virtual environment",
	})

	vim.api.nvim_create_user_command("TokenCountVenvClean", function()
		local venv = require("token-count.venv")
		vim.ui.input({
			prompt = "Remove virtual environment? (y/N): ",
		}, function(input)
			if input and input:lower() == "y" then
				vim.notify("Removing virtual environment...", vim.log.levels.INFO)
				venv.clean_venv(function(success, error)
					if success then
						vim.notify("Virtual environment removed", vim.log.levels.INFO)
					else
						vim.notify("Removal failed: " .. (error or "unknown error"), vim.log.levels.ERROR)
					end
				end)
			else
				vim.notify("Cancelled", vim.log.levels.INFO)
			end
		end)
	end, {
		desc = "Remove the virtual environment",
	})
	-- Register health check
	vim.health = vim.health or {}
	vim.health["token-count"] = require("token-count.health").check

	-- Setup autocommands
	local augroup = vim.api.nvim_create_augroup("TokenCount", { clear = true })

	-- Update token count cache on buffer save
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = augroup,
		callback = function(args)
			-- Only process valid buffer types
			local buffer = require("token-count.buffer")
			local buffer_id, valid = buffer.get_current_buffer_if_valid()

			if valid and buffer_id == args.buf then
				-- Update cache asynchronously (don't block save)
				buffer.count_current_buffer_async(function(result, error)
					if result then
						require("token-count.log").info(
							string.format(
								"Buffer saved - Token count: %d (Model: %s)",
								result.token_count,
								result.model_config.name
							)
						)
					end
					-- Silently ignore errors to avoid disrupting save workflow
				end)
			end
		end,
		desc = "Update token count cache after buffer save",
	})

	-- Log successful setup
	require("token-count.log").info("token-count.nvim setup complete with model: " .. config.get().model)

	-- Setup virtual environment asynchronously
	local venv = require("token-count.venv")
	local status = venv.get_status()

	if not status.ready then
		require("token-count.log").info("Setting up virtual environment...")
		venv.setup_venv(function(success, error)
			if success then
				require("token-count.log").info("Virtual environment setup complete")
			else
				require("token-count.log").error("Virtual environment setup failed: " .. (error or "unknown error"))
			end
		end)
	end

	-- Auto-setup CodeCompanion extension if available
	local codecompanion_ok, _ = pcall(require, "codecompanion")
	if codecompanion_ok then
		-- Try to load our extension
		local extension_ok, extension = pcall(require, "codecompanion._extensions.token-counter.nvim")
		if extension_ok then
			extension.setup(opts.codecompanion or {})
			require("token-count.log").info("CodeCompanion extension auto-loaded")
		end
	end
end

--- Get current buffer token count (for integrations like lualine)
--- @param callback function Callback function that receives (result, error)
function M.get_current_buffer_count(callback)
	require("token-count.buffer").count_current_buffer_async(callback)
end

--- Get current buffer token count synchronously (may block)
--- @return number|nil token_count
--- @return string|nil error
function M.get_current_buffer_count_sync()
	local config = require("token-count.config").get()
	local models = require("token-count.models.utils")
	local buffer = require("token-count.buffer")

	-- Validate current buffer
	local buffer_id, valid = buffer.get_current_buffer_if_valid()
	if not valid then
		return nil, "Invalid buffer filetype"
	end

	-- Get content and model config
	local content = buffer.get_buffer_contents(buffer_id)
	local model_config = models.get_model(config.model)
	if not model_config then
		return nil, "Invalid model: " .. config.model
	end

	-- Get provider and count
	local provider = models.get_provider_handler(model_config.provider)
	if not provider then
		return nil, "Failed to load provider: " .. model_config.provider
	end

	return provider.count_tokens_sync(content, model_config.encoding)
end

--- Get available models (for external integrations)
--- @return string[] model_names List of available model names
function M.get_available_models()
	return require("token-count.models.utils").get_available_models()
end

--- Get current model configuration
--- @return table model_config Current model configuration
function M.get_current_model()
	local config = require("token-count.config").get()
	return require("token-count.models.utils").get_model(config.model)
end

return M
