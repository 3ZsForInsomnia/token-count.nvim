local M = {}

--- Log levels with numeric values for comparison
local LOG_LEVELS = {
	info = 1,
	warn = 2,
	error = 3,
}

--- Get log file path in XDG state directory
--- @return string log_path Path to the log file
local function get_log_path()
	local state_dir = vim.fn.stdpath("state")
	local log_dir = state_dir .. "/token-count.nvim"

	-- Ensure directory exists
	vim.fn.mkdir(log_dir, "p")

	return log_dir .. "/log.txt"
end

--- Get current timestamp
--- @return string timestamp Formatted timestamp
local function get_timestamp()
	return os.date("%Y-%m-%d %H:%M:%S")
end

--- Write log entry to file if level meets threshold
--- @param level string Log level ("info", "warn", "error")
--- @param message string Log message
local function write_log(level, message)
	local config = require("token-count.config").get()
	local current_level = LOG_LEVELS[config.log_level] or LOG_LEVELS.warn
	local msg_level = LOG_LEVELS[level] or LOG_LEVELS.info

	-- Only log if message level meets or exceeds configured level
	if msg_level >= current_level then
		local log_path = get_log_path()
		local timestamp = get_timestamp()
		local log_entry = string.format("[%s] %s: %s\n", timestamp, level:upper(), message)

		-- Append to log file
		local file = io.open(log_path, "a")
		if file then
			file:write(log_entry)
			file:close()
		end
	end
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

return M
