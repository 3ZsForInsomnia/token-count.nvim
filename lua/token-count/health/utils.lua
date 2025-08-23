--- Health check utility functions
local M = {}

--- Check if a Python library is available
--- @param library_name string Name of the Python library
--- @return boolean success Whether the library is available
function M.check_python_library(library_name)
	-- Use the managed virtual environment if available
	local venv = require("token-count.venv")
	local status = venv.get_status()
	
	local python_path
	if status.ready then
		-- Use the managed venv Python
		python_path = venv.get_python_path()
	else
		-- Fallback to system Python for initial checks when venv isn't ready
		if status.python_available then
			-- Try to find the best available Python 3
			local python_candidates = { "python3", "python" }
			python_path = "python3" -- default fallback
			for _, cmd in ipairs(python_candidates) do
				local test_result = vim.system({ cmd, "--version" }, { text = true }):wait()
				if test_result.code == 0 and test_result.stdout:match("Python 3%.") then
					python_path = cmd
					break
				end
			end
		else
			return false, "Python 3 not available"
		end
	end
	
	local cmd = { python_path, "-c", "import " .. library_name .. "; print('OK')" }
	local result = vim.system(cmd, { text = true }):wait()

	if result.code == 0 and result.stdout:match("OK") then
		return true, nil
	else
		local error_msg = result.stderr and result.stderr:gsub("%s+$", "") or "Unknown error"
		return false, error_msg
	end
end

--- Report health check result
--- @param name string Name of the check
--- @param success boolean Whether the check passed
--- @param error_msg string|nil Error message if check failed
--- @param details string|nil Additional details
function M.report_check(name, success, error_msg, details)
	if success then
		vim.health.ok(name .. (details and (" (" .. details .. ")") or ""))
	else
		vim.health.error(name, error_msg or "Unknown error")
	end
end

return M