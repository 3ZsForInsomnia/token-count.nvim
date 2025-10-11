--- Unified token count cache manager (Main Entry Point)
--- Orchestrates all cache modules and provides the public API
local M = {}

local setup = require("token-count.cache.setup")
local api = require("token-count.cache.api")
local management = require("token-count.cache.management")

local instance_manager = require("token-count.cache.instance")
local processor = require("token-count.cache.processor")
local directory = require("token-count.cache.directory")
local timer = require("token-count.cache.timer")
local notifications = require("token-count.cache.notifications")

-- Export main functions from setup module
M.setup = setup.setup

M.get_token_count = api.get_token_count
M.get_file_token_count = api.get_file_token_count
M.get_directory_token_count = api.get_directory_token_count
M.process_immediate = api.process_immediate
M.invalidate_file = api.invalidate_file
M.update_cache_with_count = api.update_cache_with_count

 M.count_file_immediate = api.count_file_immediate
 M.count_file_background = api.count_file_background
 
                 -- Export configuration access
                 M.get_config = function()
                 	return require("token-count.cache.instance").get_instance().config
                 end
                 
M.register_update_callback = management.register_update_callback
M.clear_cache = management.clear_cache
M.get_stats = management.get_stats
M.queue_directory_files = management.queue_directory_files
M.update_config = management.update_config
M.get_config = management.get_config
M.cleanup = management.cleanup

-- Export internal modules for testing
M._internal = {
    instance = instance_manager,
    processor = processor,
    directory = directory,
    timer = timer,
    notifications = notifications,
    setup = setup,
    api = api,
    management = management,
}

return M