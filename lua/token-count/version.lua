--- Version management and compatibility checking
local M = {}

M.VERSION = "1.0.0"
M.MIN_NVIM_VERSION = "0.9.0"
M.REQUIRED_PYTHON = "3.7"
M.RECOMMENDED_PYTHON = "3.11"

--- Check Neovim version compatibility
--- @return boolean compatible Whether current Neovim version is supported
--- @return string? error Error message if incompatible
function M.check_nvim_compatibility()
    local current_version = vim.version()
    local required_version = vim.version.parse(M.MIN_NVIM_VERSION)
    
    if vim.version.cmp(current_version, required_version) < 0 then
        local error_msg = string.format(
            "token-count.nvim requires Neovim %s or later (found %s)",
            M.MIN_NVIM_VERSION,
            tostring(current_version)
        )
        return false, error_msg
    end
    
    return true, nil
end

--- Check Python version compatibility
--- @return boolean compatible Whether Python version is supported
--- @return string version_info Python version information
--- @return boolean recommended Whether Python version is recommended
function M.check_python_compatibility()
    local python_cmds = {"python3", "python"}
    
    for _, cmd in ipairs(python_cmds) do
        local result = vim.system({cmd, "--version"}, {text = true}):wait()
        if result.code == 0 then
            local version_str = result.stdout:match("Python (%d+%.%d+)")
            if version_str then
                local major, minor = version_str:match("(%d+)%.(%d+)")
                local version_num = tonumber(major) + tonumber(minor) / 10
                local required_num = 3.7
                local recommended_num = 3.11
                
                if version_num >= required_num then
                    local is_recommended = version_num >= recommended_num
                    return true, result.stdout:gsub("%s+$", ""), is_recommended
                else
                    return false, result.stdout:gsub("%s+$", ""), false
                end
            end
        end
    end
    
    return false, "Python not found or version not detected", false
end

--- Check overall system compatibility
--- @return boolean compatible Whether system meets all requirements
--- @return table report Detailed compatibility report
function M.check_system_compatibility()
    local report = {
        nvim_compatible = false,
        nvim_version = tostring(vim.version()),
        python_compatible = false,
        python_version = "Not found",
        python_recommended = false,
        issues = {},
        warnings = {}
    }
    
    -- Check Neovim compatibility
    local nvim_ok, nvim_error = M.check_nvim_compatibility()
    report.nvim_compatible = nvim_ok
    if not nvim_ok then
        table.insert(report.issues, nvim_error)
    end
    
    -- Check Python compatibility
    local python_ok, python_version, python_recommended = M.check_python_compatibility()
    report.python_compatible = python_ok
    report.python_version = python_version
    report.python_recommended = python_recommended
    
    if not python_ok then
        table.insert(report.issues, string.format(
            "Python %s or later required (found: %s)",
            M.REQUIRED_PYTHON,
            python_version
        ))
    elseif not python_recommended then
        table.insert(report.warnings, string.format(
            "Python %s or later recommended for best performance (found: %s)",
            M.RECOMMENDED_PYTHON,
            python_version
        ))
    end
    
    report.compatible = nvim_ok and python_ok
    
    return report.compatible, report
end

--- Display compatibility report to user
--- @param report table Compatibility report from check_system_compatibility
function M.display_compatibility_report(report)
    local lines = {
        "=== token-count.nvim Compatibility Report ===",
        "",
        string.format("Plugin version: %s", M.VERSION),
        string.format("Neovim: %s (%s)", report.nvim_version, report.nvim_compatible and "✓" or "✗"),
        string.format("Python: %s (%s)", report.python_version, report.python_compatible and "✓" or "✗"),
        ""
    }
    
    if #report.issues > 0 then
        table.insert(lines, "Issues:")
        for _, issue in ipairs(report.issues) do
            table.insert(lines, "  • " .. issue)
        end
        table.insert(lines, "")
    end
    
    if #report.warnings > 0 then
        table.insert(lines, "Warnings:")
        for _, warning in ipairs(report.warnings) do
            table.insert(lines, "  • " .. warning)
        end
        table.insert(lines, "")
    end
    
    if report.compatible then
        table.insert(lines, "✓ System is compatible with token-count.nvim")
    else
        table.insert(lines, "✗ System compatibility issues found")
        table.insert(lines, "")
        table.insert(lines, "Please resolve the issues above before using this plugin.")
    end
    
    for _, line in ipairs(lines) do
        print(line)
    end
end

--- Initialize version checking (called during setup)
function M.initialize()
    local compatible, report = M.check_system_compatibility()
    
    if not compatible then
        M.display_compatibility_report(report)
        error("System compatibility check failed. See report above.")
    end
    
    -- Log successful compatibility check
    local log = require("token-count.log")
    log.info(string.format(
        "Compatibility check passed - Neovim: %s, Python: %s", 
        report.nvim_version, 
        report.python_version
    ))
    
    -- Show warnings if any
    if #report.warnings > 0 then
        for _, warning in ipairs(report.warnings) do
            log.warn(warning)
        end
    end
end

return M