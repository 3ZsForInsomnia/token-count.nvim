--- User command definitions
local M = {}

--- Create all user commands for the plugin
function M.create_commands()
	-- Core token counting commands
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
end
	-- Cache Management Commands
	vim.api.nvim_create_user_command("TokenCountCacheClear", function()
		local cache_manager = require("token-count.cache")
		cache_manager.clear_cache()
		print("Token count cache cleared")
	end, {
		desc = "Clear token count cache",
	})

	vim.api.nvim_create_user_command("TokenCountCacheStats", function()
		local cache_manager = require("token-count.cache")
		local stats = cache_manager.get_stats()
		print(string.format(
			"Unified Cache Stats:\n  Files: %d cached\n  Directories: %d cached\n  Processing: %d items\n  Queued: %d items\n  Timer: %s",
			stats.cached_files,
			stats.cached_directories,
			stats.processing_items,
			stats.queued_items,
			stats.timer_active and "active" or "inactive"
		))
	end, {
		desc = "Show token count cache statistics",
	})

	vim.api.nvim_create_user_command("TokenCountCacheRefresh", function()
		local cache_manager = require("token-count.cache")
		cache_manager.clear_cache()
		-- Re-queue current directory
		vim.schedule(function()
			local cwd = vim.fn.getcwd()
			cache_manager.queue_directory_files(cwd)
			vim.notify("Cache cleared and directory re-queued for processing", vim.log.levels.INFO)
		end)
	end, {
		desc = "Refresh token count cache for current directory",
	})

--- Create virtual environment management commands
function M.create_venv_commands()
	vim.api.nvim_create_user_command("TokenCountVenvStatus", function()
		local venv = require("token-count.venv")
		local status = venv.get_status()

		local function status_icon(condition)
			return condition and "✓" or "✗"
		end

		local function provider_status(installed, api_key, error_msg, provider_name)
			local install_status = status_icon(installed)
			local api_status = api_key and "✓" or "✗"
			local result = string.format("%s: %s installed, %s API key", provider_name, install_status, api_status)
			if not installed and error_msg then
				result = result .. " (" .. error_msg .. ")"
			end
			return result
		end

		local lines = {
			"=== Token Count Virtual Environment Status ===",
			"",
			"System:",
			"  Python 3: " .. status_icon(status.python_available) .. " " .. (status.python_info or "Not found"),
			"  Virtual env: " .. status_icon(status.venv_exists) .. " " .. status.venv_path,
			"  Python executable: " .. status.python_path,
			"",
			"Provider Dependencies:",
			"  " .. provider_status(status.tiktoken_installed, true, status.tiktoken_error, "tiktoken (required)"),
			"  " .. provider_status(status.anthropic_installed, status.anthropic_api_key, status.anthropic_error, "Anthropic"),
			"  " .. provider_status(status.gemini_installed, status.gemini_api_key, status.gemini_error, "Google GenAI"),
			"",
			"Overall Status: " .. status_icon(status.ready) .. " " .. (status.ready and "Ready" or "Not ready"),
		}

		-- Add helpful notes
		if not status.anthropic_api_key then
			table.insert(lines, "")
			table.insert(lines, "Note: Set ANTHROPIC_API_KEY environment variable to use Anthropic models")
		end
		if not status.gemini_api_key then
			table.insert(lines, "")
			table.insert(lines, "Note: Set GOOGLE_API_KEY environment variable to use Google GenAI models")
		end

		for _, line in ipairs(lines) do
			print(line)
		end
	end, {
		desc = "Show comprehensive virtual environment and provider status",
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
end

return M