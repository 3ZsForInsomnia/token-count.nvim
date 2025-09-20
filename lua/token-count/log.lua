local M = {}

local LOG_LEVELS = {
	info = 1,
	warn = 2,
	error = 3,
}

 -- Log management configuration
 local LOG_CONFIG = {
 	MAX_LOG_SIZE = 5 * 1024 * 1024, -- 5MB
 	CHECK_INTERVAL = 3600, -- 1 hour in seconds
 }
 
 -- Track last size check
 local last_size_check = 0
local function get_log_path()
	local state_dir = vim.fn.stdpath("state")
	local log_dir = state_dir .. "/token-count.nvim"

	-- Ensure directory exists
	vim.fn.mkdir(log_dir, "p")

	return log_dir .. "/log.txt"
end

local function get_timestamp()
	return os.date("%Y-%m-%d %H:%M:%S")
end

 --- Check if log rotation is needed (called hourly)
 --- @param log_path string Path to log file
 local function maybe_rotate_log(log_path)
 	local now = os.time()
 	if (now - last_size_check) < LOG_CONFIG.CHECK_INTERVAL then
 		return -- Too soon to check
 	end
 	
 	last_size_check = now
 	
 	-- Check file size
 	local stat = vim.loop.fs_stat(log_path)
 	if stat and stat.size > LOG_CONFIG.MAX_LOG_SIZE then
 		-- Truncate to keep only last 1MB
 		local file = io.open(log_path, "r")
 		if file then
 			local content = file:read("*all")
 			file:close()
 			
 			-- Keep last 1MB of content
 			local keep_size = 1024 * 1024
 			if #content > keep_size then
 				local truncated = content:sub(-keep_size)
 				-- Find first complete line to avoid partial entries
 				local first_newline = truncated:find("\n")
 				if first_newline then
 					truncated = truncated:sub(first_newline + 1)
 				end
 				
 				-- Write truncated content
 				local out_file = io.open(log_path, "w")
 				if out_file then
 					out_file:write(string.format("[%s] INFO: Log rotated (size limit reached)\n", get_timestamp()))
 					out_file:write(truncated)
 					out_file:close()
 				end
 			end
 		end
 	end
 end
 
--- @param level string Log level ("info", "warn", "error")
--- @param message string Log message
local function write_log(level, message)
	-- Schedule logging to avoid fast event context issues
	vim.schedule(function()
		local log_path = get_log_path()
		
		-- Check for log rotation (hourly)
		maybe_rotate_log(log_path)
		
		local config = require("token-count.config").get()
		local current_level = LOG_LEVELS[config.log_level] or LOG_LEVELS.warn
		local msg_level = LOG_LEVELS[level] or LOG_LEVELS.info

		-- Only log if message level meets or exceeds configured level
		if msg_level >= current_level then
			local timestamp = get_timestamp()
			local log_entry = string.format("[%s] %s: %s\n", timestamp, level:upper(), message)

			-- Append to log file
			local file = io.open(log_path, "a")
			if file then
				file:write(log_entry)
				file:close()
			end
		end
	end)
end

--- Log info message
--- @param message string Message to log
function M.info(message)
	write_log("info", message)
end

--- Log warning message
--- @param message string Message to log
function M.warn(message)
	write_log("warn", message)
end

--- Log error message (also shows vim.notify)
--- @param message string Message to log
function M.error(message)
	write_log("error", message)
	vim.notify("token-count.nvim: " .. message, vim.log.levels.ERROR)
end

--- Get log file path (for debugging/health checks)
--- @return string log_path Path to the log file
function M.get_log_path()
	return get_log_path()
end

--- Clear log file
function M.clear_log()
	local log_path = get_log_path()
	local file = io.open(log_path, "w")
	if file then
		file:close()
		M.info("Log file cleared")
	end
end

--- Check log size once at startup (with delay)
function M.setup_log_rotation()
	vim.defer_fn(function()
		local log_path = get_log_path()
		maybe_rotate_log(log_path)
	end, 3000) -- 3 second delay
end

return M
