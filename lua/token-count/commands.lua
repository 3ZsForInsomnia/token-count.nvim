--- Command Operations
--- This module provides a unified interface for all token counting commands
local M = {}

-- Import submodules
local single = require("token-count.commands.single")
local multiple = require("token-count.commands.multiple")
local selection = require("token-count.commands.selection")

-- Re-export single buffer functions
M.count_current_buffer = single.count_current_buffer
M.change_model = single.change_model

-- Re-export multiple buffer functions
M.count_all_buffers = multiple.count_all_buffers

-- Re-export selection functions
M.count_visual_selection = selection.count_visual_selection

return M