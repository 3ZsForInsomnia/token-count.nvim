--- Plugin initialization and setup
local M = {}

--- Initialize the plugin environment
--- @param opts table|nil User configuration options
function M.initialize_plugin(opts)
	-- Log successful setup
	local config = require("token-count.config")
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

	-- Install all provider dependencies asynchronously
	venv.install_all_dependencies(function(success, warnings)
		if success then
			require("token-count.log").info("Python dependencies installation complete")
			if warnings then
				require("token-count.log").warn(warnings)
				vim.notify("Some providers may be unavailable: " .. warnings, vim.log.levels.WARN)
			end
		else
			require("token-count.log").error("Dependencies installation failed: " .. (warnings or "unknown error"))
		end
	end)

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

return M