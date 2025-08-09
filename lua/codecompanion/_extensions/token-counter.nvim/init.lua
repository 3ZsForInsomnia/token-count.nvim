-- CodeCompanion extension for token-count.nvim
-- Provides token count visualization for CodeCompanion context items

local Extension = {}

--- Debug helper to print table contents
--- @param obj any Object to print
--- @param name string Name for the object
--- @param depth number Current depth (for indentation)
local function debug_print_table(obj, name, depth)
	depth = depth or 0
	local indent = string.rep("  ", depth)

	if type(obj) == "table" then
		print(indent .. name .. " = {")
		for k, v in pairs(obj) do
			if type(v) == "table" and depth < 3 then -- Limit depth to avoid infinite recursion
				debug_print_table(v, tostring(k), depth + 1)
			else
				print(indent .. "  " .. tostring(k) .. " = " .. tostring(v) .. " (" .. type(v) .. ")")
			end
		end
		print(indent .. "}")
	else
		print(indent .. name .. " = " .. tostring(obj) .. " (" .. type(obj) .. ")")
	end
end

--- Extract file items from CodeCompanion context
--- @param chat table CodeCompanion chat object
--- @return table file_items List of file context items
local function extract_file_context_items(chat)
	print("=== DEBUG: Analyzing CodeCompanion chat object ===")

	-- First, let's see what the chat object looks like
	debug_print_table(chat, "chat", 0)

	print("\n=== DEBUG: Looking for context_items ===")

	local context_items = chat.context_items
	if not context_items then
		print("DEBUG: No context_items found in chat object")
		print("DEBUG: Available chat keys: " .. table.concat(vim.tbl_keys(chat or {}), ", "))
		return {}
	end

	print("DEBUG: Found context_items, type: " .. type(context_items))
	print("DEBUG: Context items count: " .. (context_items and #context_items or "nil"))

	if type(context_items) == "table" then
		debug_print_table(context_items, "context_items", 0)
	end

	local file_items = {}

	if type(context_items) == "table" then
		for i, item in ipairs(context_items) do
			print(string.format("\n=== DEBUG: Processing context item %d ===", i))
			debug_print_table(item, "item_" .. i, 0)

			-- Try different possible indicators for file items
			local is_file = false
			local file_path = nil

			-- Check various possible structures
			if item.type == "file" or item.type == "buffer" then
				is_file = true
				file_path = item.path or item.file_path or item.filename
				print(
					string.format(
						"DEBUG: Item %d identified as file by type '%s', path: %s",
						i,
						item.type,
						tostring(file_path)
					)
				)
			elseif item.path or item.file_path or item.filename then
				is_file = true
				file_path = item.path or item.file_path or item.filename
				print(
					string.format(
						"DEBUG: Item %d identified as file by path presence, path: %s",
						i,
						tostring(file_path)
					)
				)
			elseif type(item.content) == "string" and (item.name or item.title) then
				-- Might be a file with content
				is_file = true
				file_path = item.name or item.title
				print(
					string.format(
						"DEBUG: Item %d identified as potential file by content+name, name: %s",
						i,
						tostring(file_path)
					)
				)
			end

			if is_file and file_path then
				local file_item = {
					path = file_path,
					content = item.content or "",
					original_item = item, -- Keep reference to original for debugging
				}
				table.insert(file_items, file_item)
				print(
					string.format("DEBUG: Added file item: %s (content length: %d)", file_path, #(item.content or ""))
				)
			else
				print(string.format("DEBUG: Item %d not recognized as file item", i))
			end
		end
	end

	print(string.format("\n=== DEBUG: Final result: %d file items extracted ===", #file_items))
	for i, item in ipairs(file_items) do
		print(string.format("  %d. %s (%d chars)", i, item.path, #item.content))
	end

	return file_items
end

--- Count tokens for context items
--- @param file_items table List of file context items
--- @return table results Token count results
local function count_context_tokens(file_items)
	print("\n=== DEBUG: Starting token counting ===")

	local results = {
		items = {},
		total_tokens = 0,
		errors = {},
	}

	-- Get token counting dependencies
	local models_ok, models = pcall(require, "token-count.models.utils")
	local config_ok, config_module = pcall(require, "token-count.config")

	if not (models_ok and config_ok) then
		print("DEBUG: Failed to load token-count modules")
		print("DEBUG: models_ok = " .. tostring(models_ok))
		print("DEBUG: config_ok = " .. tostring(config_ok))
		return results
	end

	local current_config = config_module.get()
	local model_config = models.get_model(current_config.model)

	if not model_config then
		print("DEBUG: Failed to get model config for: " .. tostring(current_config.model))
		return results
	end

	print("DEBUG: Using model: " .. current_config.model .. " (" .. model_config.name .. ")")

	local provider = models.get_provider_handler(model_config.provider)
	if not provider then
		print("DEBUG: Failed to get provider: " .. tostring(model_config.provider))
		return results
	end

	-- Count tokens for each file
	for i, file_item in ipairs(file_items) do
		print(string.format("\nDEBUG: Counting tokens for item %d: %s", i, file_item.path))
		print(string.format("DEBUG: Content length: %d characters", #file_item.content))

		if #file_item.content == 0 then
			print("DEBUG: Empty content, skipping")
			goto continue
		end

		local count, error = provider.count_tokens_sync(file_item.content, model_config.encoding)

		if count then
			print(string.format("DEBUG: Token count successful: %d tokens", count))
			local item_result = {
				path = file_item.path,
				tokens = count,
				content_length = #file_item.content,
			}
			table.insert(results.items, item_result)
			results.total_tokens = results.total_tokens + count
		else
			print(string.format("DEBUG: Token count failed: %s", tostring(error)))
			table.insert(results.errors, {
				path = file_item.path,
				error = error,
			})
		end

		::continue::
	end

	print(
		string.format(
			"\nDEBUG: Token counting complete. Total: %d tokens across %d items",
			results.total_tokens,
			#results.items
		)
	)

	return results
end

--- Show context token counts in a notification
--- @param chat table CodeCompanion chat object
local function show_context_summary(chat)
	print("\n=== DEBUG: show_context_summary called ===")

	local file_items = extract_file_context_items(chat)

	if #file_items == 0 then
		vim.notify("No file context items found in CodeCompanion chat", vim.log.levels.WARN)
		return
	end

	local results = count_context_tokens(file_items)

	if #results.items == 0 then
		vim.notify("Could not count tokens for any context items", vim.log.levels.ERROR)
		return
	end

	-- Build summary message
	local lines = {
		"CodeCompanion Context Summary:",
		string.format("Total: %d tokens across %d files", results.total_tokens, #results.items),
		"",
	}

	-- Add model info if available
	local config_ok, config_module = pcall(require, "token-count.config")
	local models_ok, models = pcall(require, "token-count.models.utils")

	if config_ok and models_ok then
		local current_config = config_module.get()
		local model_config = models.get_model(current_config.model)
		if model_config then
			local percentage = (results.total_tokens / model_config.context_window) * 100
			table.insert(lines, string.format("Model: %s", model_config.name))
			table.insert(
				lines,
				string.format(
					"Context usage: %.1f%% (%d / %d)",
					percentage,
					results.total_tokens,
					model_config.context_window
				)
			)
			table.insert(lines, "")
		end
	end

	-- Add per-file breakdown
	table.insert(lines, "File breakdown:")
	for _, item in ipairs(results.items) do
		local filename = vim.fn.fnamemodify(item.path, ":t")
		table.insert(lines, string.format("  %s: %d tokens", filename, item.tokens))
	end

	-- Show errors if any
	if #results.errors > 0 then
		table.insert(lines, "")
		table.insert(lines, "Errors:")
		for _, error_item in ipairs(results.errors) do
			table.insert(lines, string.format("  %s: %s", error_item.path, error_item.error))
		end
	end

	-- Display the summary
	for _, line in ipairs(lines) do
		print(line)
	end

	vim.notify(
		string.format("Context: %d tokens (see :messages for details)", results.total_tokens),
		vim.log.levels.INFO
	)
end

--- Setup the CodeCompanion extension
--- @param opts table Configuration options
function Extension.setup(opts)
	opts = opts or {}

	print("=== DEBUG: Setting up CodeCompanion token-count extension ===")
	print("DEBUG: Options provided:")
	debug_print_table(opts, "opts", 0)

	-- Try to get CodeCompanion config
	local codecompanion_ok, codecompanion_config = pcall(require, "codecompanion.config")
	if not codecompanion_ok then
		print("DEBUG: Failed to load codecompanion.config")
		vim.notify("CodeCompanion not found - extension not loaded", vim.log.levels.WARN)
		return
	end

	print("DEBUG: CodeCompanion config loaded successfully")

	-- Add keymap to chat strategies
	local chat_keymaps = codecompanion_config.strategies.chat.keymaps
	if not chat_keymaps then
		print("DEBUG: Could not find chat keymaps in CodeCompanion config")
		return
	end

	print("DEBUG: Adding keymap to chat keymaps")

	chat_keymaps.view_context_tokens = {
		modes = {
			n = opts.keymap or "gt",
		},
		description = "View Context Token Counts",
		callback = function(chat)
			print("=== DEBUG: Keymap callback triggered ===")
			show_context_summary(chat)
		end,
	}

	print(
		"DEBUG: Extension setup complete. Use '"
			.. (opts.keymap or "gt")
			.. "' in CodeCompanion chat to view token counts"
	)

	-- Create standalone Neovim commands
	vim.api.nvim_create_user_command("TokenCountCodeCompanion", function()
		-- Try to find active CodeCompanion chat
		local codecompanion_ok, codecompanion = pcall(require, "codecompanion")
		if not codecompanion_ok then
			vim.notify("CodeCompanion not available", vim.log.levels.ERROR)
			return
		end

		-- This is a guess at how to get current chat - we'll see from debug output
		local chat = codecompanion.get_current_chat and codecompanion.get_current_chat()
		if not chat then
			vim.notify("No active CodeCompanion chat found", vim.log.levels.WARN)
			return
		end

		show_context_summary(chat)
	end, {
		desc = "Show token counts for current CodeCompanion context",
	})

	vim.api.nvim_create_user_command("TokenCountCodeCompanionDebug", function()
		print("=== DEBUG: Manual debug command triggered ===")

		-- Try to find any CodeCompanion chat objects
		local codecompanion_ok, codecompanion = pcall(require, "codecompanion")
		if not codecompanion_ok then
			print("DEBUG: CodeCompanion module not available")
			return
		end

		print("DEBUG: CodeCompanion module loaded")
		debug_print_table(codecompanion, "codecompanion_module", 0)

		-- Look for active chats or chat manager
		if codecompanion.get_current_chat then
			local chat = codecompanion.get_current_chat()
			if chat then
				print("DEBUG: Found current chat via get_current_chat()")
				show_context_summary(chat)
			else
				print("DEBUG: get_current_chat() returned nil")
			end
		else
			print("DEBUG: No get_current_chat() method found")
		end

		vim.notify("Debug output printed to :messages", vim.log.levels.INFO)
	end, {
		desc = "Debug CodeCompanion token counting integration",
	})
end

return Extension
