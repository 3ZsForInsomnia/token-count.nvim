local M = {}

local utils = require("token-count.venv.utils")

-- Cache for dependency installation checks to avoid repeated blocking calls
local dependency_cache = {}

-- Lazy initialization flag - dependencies are only checked when actually needed
local _lazy_init_started = false
local _lazy_init_complete = false
local _lazy_init_callbacks = {}

local function get_cleanup()
	local cleanup_ok, cleanup = pcall(require, "token-count.cleanup")
	return cleanup_ok and cleanup or nil
end
--- @param dependency_name string The dependency name (tiktoken, anthropic, gemini)
--- Internal function to actually check dependency installation (blocking)
local function _check_dependency_impl(dependency_name)
	if not utils.venv_exists() then
		return false, "Virtual environment does not exist"
	end
	local dep_config = utils.DEPENDENCIES[dependency_name]
	if not dep_config then
		return false, "Unknown dependency: " .. dependency_name
	end
	local python_path = utils.get_python_path()
	local check_cmd = { python_path, "-c", dep_config.import_test }
	local result = vim.system(check_cmd, { text = true }):wait()
	if result.code == 0 and result.stdout:match("OK") then
		return true, nil
	else
		return false, result.stderr or "Import failed"
	end
end

--- Async version of dependency checking that doesn't block
--- @param dependency_name string The dependency name
--- @param callback function Callback with (installed, error)
local function _check_dependency_async(dependency_name, callback)
	if not utils.venv_exists() then
		callback(false, "Virtual environment does not exist")
		return
	end

	local dep_config = utils.DEPENDENCIES[dependency_name]
	if not dep_config then
		callback(false, "Unknown dependency: " .. dependency_name)
		return
	end

	local python_path = utils.get_python_path()
	local check_cmd = { python_path, "-c", dep_config.import_test }

	vim.system(check_cmd, { text = true }, function(result)
		if result.code == 0 and result.stdout:match("OK") then
			callback(true, nil)
		else
			callback(false, result.stderr or "Import failed")
		end
	end)
end

--- Initialize dependency cache asynchronously for a specific dependency
--- @param dependency_name string The dependency name
--- @param callback function|nil Optional callback when complete
function M.init_dependency_cache_async(dependency_name, callback)
	if dependency_cache[dependency_name] then
		if callback then
			callback()
		end
		return
	end

	_check_dependency_async(dependency_name, function(installed, error)
		dependency_cache[dependency_name] = {
			checked = true,
			installed = installed,
			error = error,
		}
		if callback then
			callback()
		end
	end)
end

--- Initialize dependency cache for a specific dependency
function M.init_dependency_cache(dependency_name)
	if not dependency_cache[dependency_name] then
		local installed, error = _check_dependency_impl(dependency_name)
		dependency_cache[dependency_name] = {
			checked = true,
			installed = installed,
			error = error,
		}
	end
end

--- Initialize all dependency caches asynchronously (non-blocking)
--- @param callback function|nil Optional callback when complete
function M.init_all_dependency_caches_async(callback)
	local deps = vim.tbl_keys(utils.DEPENDENCIES)
	local completed = 0
	local total = #deps

	if total == 0 then
		if callback then
			callback()
		end
		return
	end

	for _, dep_name in ipairs(deps) do
		M.init_dependency_cache_async(dep_name, function()
			completed = completed + 1
			if completed == total then
				_lazy_init_complete = true
				if callback then
					callback()
				end
			end
		end)
	end
end

--- Ensure lazy initialization has been triggered
--- This is called on first actual use of token counting
--- @param callback function|nil Optional callback when initialization is complete
function M.ensure_lazy_init(callback)
	if _lazy_init_complete then
		if callback then
			callback()
		end
		return
	end

	if callback then
		table.insert(_lazy_init_callbacks, callback)
	end

	if _lazy_init_started then
		-- Already in progress, callback will be called when complete
		return
	end

	_lazy_init_started = true

	-- Schedule initialization to avoid fast event context
	vim.schedule(function()
		M.init_all_dependency_caches_async(function()
			_lazy_init_complete = true
			-- Call all pending callbacks
			for _, cb in ipairs(_lazy_init_callbacks) do
				pcall(cb)
			end
			_lazy_init_callbacks = {}
		end)
	end)
end

--- @param dependency_name string The dependency name (tiktoken, anthropic, gemini)
--- @return boolean installed Whether the dependency is available (from cache only, never blocks)
--- @return string|nil error Error message if check failed
function M.is_dependency_installed(dependency_name)
	-- Return cached result only, never block
	-- This is safe to call from any context including fast events
	local cache_entry = dependency_cache[dependency_name]
	if cache_entry then
		return cache_entry.installed, cache_entry.error
	else
		-- Not cached yet - return false without blocking
		-- Lazy initialization will happen on first actual use
		return false, "Not initialized yet"
	end
end

--- Install a dependency in the virtual environment
--- @param dependency_name string The dependency name (tiktoken, anthropic, gemini)
--- @param callback function Callback function that receives (success, error)
function M.install_dependency(dependency_name, callback)
	if not utils.venv_exists() then
		callback(false, "Virtual environment does not exist")
		return
	end

	local dep_config = utils.DEPENDENCIES[dependency_name]
	if not dep_config then
		callback(false, "Unknown dependency: " .. dependency_name)
		return
	end

	local python_path = utils.get_python_path()
	local log = require("token-count.log")

	log.info("Installing " .. dep_config.display_name .. " in virtual environment")

	local install_cmd = { python_path, "-m", "pip", "install", dep_config.package }

	local job_id = vim.fn.jobstart(install_cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						log.info("pip install " .. dependency_name .. ": " .. line)
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data and #data > 0 then
				for _, line in ipairs(data) do
					if line ~= "" then
						log.warn("pip install " .. dependency_name .. " warning: " .. line)
					end
				end
			end
		end,
		on_exit = function(_, exit_code)
			-- Unregister job on completion
			local cleanup = get_cleanup()
			if cleanup then
				cleanup.unregister_job(job_id)
			end

			if exit_code == 0 then
				log.info(dep_config.display_name .. " installed successfully")
				-- Clear cache for this dependency since it was just installed
				M.clear_dependency_cache(dependency_name)
				-- Clear status cache since dependency state changed
				local venv_setup = require("token-count.venv.setup")
				venv_setup.clear_status_cache()
				callback(true, nil)
			else
				local error_msg = "Failed to install " .. dep_config.display_name .. " (exit code: " .. exit_code .. ")"
				log.error(error_msg)
				callback(false, error_msg)
			end
		end,
	})

	if job_id <= 0 then
		local error_msg = "Failed to start " .. dep_config.display_name .. " installation"
		log.error(error_msg)
		callback(false, error_msg)
	else
		-- Register job for cleanup tracking
		local cleanup = get_cleanup()
		if cleanup then
			cleanup.register_job(job_id)
		end
	end
end

--- Install all Python dependencies (checks async before installing)
--- @param callback function Callback function that receives (success, warnings)
function M.install_all_dependencies(callback)
	callback = callback or function() end
	local log = require("token-count.log")

	if not utils.venv_exists() then
		callback(false, "Virtual environment does not exist")
		return
	end

	log.info("Checking which Python dependencies need installation...")

	local dependencies_to_install = {}
	local warnings = {}

	-- First, ensure all dependencies are checked asynchronously
	M.ensure_lazy_init(function()
		-- Now check which dependencies need installation
		for dep_name, _ in pairs(utils.DEPENDENCIES) do
			local installed, _ = M.is_dependency_installed(dep_name)
			if not installed then
				table.insert(dependencies_to_install, dep_name)
			else
				log.info(utils.DEPENDENCIES[dep_name].display_name .. " already installed")
			end
		end

		if #dependencies_to_install == 0 then
			log.info("All dependencies already installed")
			callback(true, nil)
			return
		end

		-- Install dependencies sequentially
		local function install_next_dependency(index)
			if index > #dependencies_to_install then
				-- All done, check final status
				local tiktoken_ok, _ = M.is_dependency_installed("tiktoken")
				if tiktoken_ok then
					local warning_msg = nil
					if #warnings > 0 then
						warning_msg = "Some optional providers failed to install: " .. table.concat(warnings, ", ")
					end
					callback(true, warning_msg)
				else
					callback(false, "Critical dependency tiktoken failed to install")
				end
				return
			end

			local dep_name = dependencies_to_install[index]
			M.install_dependency(dep_name, function(success, error)
				if not success then
					local warning = utils.DEPENDENCIES[dep_name].display_name
						.. " ("
						.. (error or "unknown error")
						.. ")"
					table.insert(warnings, warning)
					log.warn(
						"Failed to install "
							.. utils.DEPENDENCIES[dep_name].display_name
							.. ": "
							.. (error or "unknown error")
					)
				end

				-- Continue with next dependency regardless of success/failure
				install_next_dependency(index + 1)
			end)
		end

		install_next_dependency(1)
	end)
end

--- Clear the cache for a specific dependency
--- @param dependency_name string The dependency name
function M.clear_dependency_cache(dependency_name)
	dependency_cache[dependency_name] = nil
end

return M
