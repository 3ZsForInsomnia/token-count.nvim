--- Virtual Environment Management
--- This module provides a unified interface for virtual environment operations
local M = {}

-- Import submodules
local utils = require("token-count.venv.utils")
local manager = require("token-count.venv.manager")
local dependencies = require("token-count.venv.dependencies")
local setup = require("token-count.venv.setup")

-- Re-export utility functions
M.get_python_path = utils.get_python_path
M.venv_exists = utils.venv_exists
M.check_python_available = utils.check_python_available

-- Re-export manager functions
M.create_venv = manager.create_venv
M.clean_venv = manager.clean_venv

M.tiktoken_installed = function() return dependencies.is_dependency_installed("tiktoken") end
M.tokencost_installed = function() return dependencies.is_dependency_installed("tokencost") end
M.deepseek_tokenizer_installed = function() return dependencies.is_dependency_installed("deepseek_tokenizer") end
M.anthropic_installed = function() return dependencies.is_dependency_installed("anthropic") end
M.gemini_installed = function() return dependencies.is_dependency_installed("gemini") end

M.install_tiktoken = function(callback) dependencies.install_dependency("tiktoken", callback) end
M.install_tokencost = function(callback) dependencies.install_dependency("tokencost", callback) end
M.install_deepseek_tokenizer = function(callback) dependencies.install_dependency("deepseek_tokenizer", callback) end
M.install_anthropic = function(callback) dependencies.install_dependency("anthropic", callback) end
M.install_gemini = function(callback) dependencies.install_dependency("gemini", callback) end

M.install_all_dependencies = dependencies.install_all_dependencies

-- Re-export setup functions
M.setup_venv = setup.setup_venv
M.get_status = setup.get_status

return M