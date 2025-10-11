local M = {}

function M.initialize_plugin(opts)

	-- Log successful setup
	local config = require("token-count.config")
	require("token-count.log").info("token-count.nvim setup complete with model: " .. config.get().model)

	-- Note: Virtual environment setup is now deferred until first use
	-- to avoid blocking plugin startup. The environment will be set up
	-- automatically when token counting is first attempted.
end

return M
