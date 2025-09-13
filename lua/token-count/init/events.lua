local M = {}
local _autocommands_setup = false

-- Lazy load cleanup system to avoid circular dependencies
local function get_cleanup()
	local cleanup_ok, cleanup = pcall(require, "token-count.cleanup")
	return cleanup_ok and cleanup or nil
end
function M.setup_autocommands()
	-- Prevent double setup
	if _autocommands_setup then
		return
	end
	_autocommands_setup = true
	
	-- Register health check
	vim.health = vim.health or {}
	vim.health["token-count"] = require("token-count.health").check

	-- Setup autocommands
	local augroup = vim.api.nvim_create_augroup("TokenCount", { clear = true })
	
	-- Register autocommand group for cleanup tracking
	local cleanup = get_cleanup()
	if cleanup then
		cleanup.register_autocommand_group(augroup, "token_count_main")
	end

	-- Update token count cache on buffer save
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = augroup,
		callback = function(args)
			-- Only process valid buffer types
			-- Lazy load buffer validation
			local buffer_validation = require("token-count.buffer.validation")
			if buffer_validation.is_buffer_valid_for_counting(args.buf) then
				-- Update cache asynchronously (don't block save)
				-- Only load buffer counting when actually needed
				local buffer = require("token-count.buffer")
				buffer.count_current_buffer_async(function(result, error)
					if result then
						require("token-count.log").info(
							string.format(
								"Buffer saved - Token count: %d (Model: %s)",
								result.token_count,
								result.model_config.name
							)
						)
						
						-- Update cache if available
						local current_file = vim.api.nvim_buf_get_name(args.buf)
						if current_file and current_file ~= "" then
							local cache_manager = require("token-count.cache")
							cache_manager.update_cache_with_count(current_file, result.token_count, false)
						end
					end
					-- Silently ignore errors to avoid disrupting save workflow
				end)
			end
		end,
		desc = "Update token count cache after buffer save",
	})
end
	-- Update token count cache on buffer read (file opened)
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = augroup,
		callback = function(args)
			-- Only process valid buffer types
			local buffer_validation = require("token-count.buffer.validation")
			if buffer_validation.is_buffer_valid_for_counting(args.buf) then
				-- Update cache asynchronously (don't block file opening)
				local buffer = require("token-count.buffer")
				buffer.count_current_buffer_async(function(result, error)
					if result then
						require("token-count.log").info(
							string.format(
								"Buffer opened - Token count: %d (Model: %s)",
								result.token_count,
								result.model_config.name
							)
						)
						
						-- Update cache if available
						local current_file = vim.api.nvim_buf_get_name(args.buf)
						if current_file and current_file ~= "" then
							local cache_manager = require("token-count.cache")
							cache_manager.update_cache_with_count(current_file, result.token_count, false)
						end
					end
					-- Silently ignore errors to avoid disrupting file opening workflow
				end)
			end
		end,
		desc = "Update token count cache after buffer read (file opened)",
	})

return M