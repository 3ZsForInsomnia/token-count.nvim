--- Buffer Operations
--- This module provides a unified interface for buffer-related operations
local M = {}

-- Import submodules
local content = require("token-count.buffer.content")
local counting = require("token-count.buffer.counting")

-- Re-export content functions
M.get_buffer_contents = content.get_buffer_contents
M.get_current_buffer_if_valid = content.get_current_buffer_if_valid

-- Re-export counting functions
M.count_current_buffer_async = counting.count_current_buffer_async

return M