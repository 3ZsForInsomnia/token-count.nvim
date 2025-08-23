--- Buffer Operations for Multiple Buffers
--- This module provides a unified interface for multiple buffer operations
local M = {}

-- Import submodules
local discovery = require("token-count.utils.buffer.discovery")
local counting = require("token-count.utils.buffer.counting")

-- Re-export discovery functions
M.is_buffer_safe_for_counting = discovery.is_buffer_safe_for_counting
M.get_valid_buffers = discovery.get_valid_buffers

-- Re-export counting functions
M.get_buffer_display_name = counting.get_buffer_display_name
M.count_multiple_buffers_async = counting.count_multiple_buffers_async
M.validate_and_get_current_buffer = counting.validate_and_get_current_buffer

return M