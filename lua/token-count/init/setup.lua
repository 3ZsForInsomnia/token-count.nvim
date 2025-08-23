local M = {}
--- Check if we should defer heavy initialization
--- @return boolean should_defer Whether to defer initialization
local function should_defer_initialization()
	-- Check if we're in a lazy-loading environment or startup
	-- Defer if we're in the startup process
	if vim.v.vim_did_enter == 0 then
		return true
	end
	
	-- Check if this might be called from a plugin manager during lazy loading
	local info = debug.getinfo(3, "S")
	if info and info.source and (info.source:match("lazy") or info.source:match("packer")) then
		return true
	end
	
	return false
end

--- Initialize the plugin environment
--- @param opts table|nil User configuration options
function M.initialize_plugin(opts)
	-- If we should defer initialization, set up a timer to do it later
	if should_defer_initialization() then
		vim.defer_fn(function()
			M.initialize_plugin(opts)
		end, 100) -- 100ms delay
		return
	end
	
	-- Log successful setup
	local config = require("token-count.config")
	require("token-count.log").info("token-count.nvim setup complete with model: " .. config.get().model)

	-- Setup virtual environment asynchronously (but only if not already ready)
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
	else
		require("token-count.log").info("Virtual environment already ready")
	end

	-- Install all provider dependencies asynchronously (but only if needed)
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