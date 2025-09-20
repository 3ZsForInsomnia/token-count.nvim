--- Buffer validation and filetype checking
local M = {}

--- Check if a filetype is valid/acceptable for token counting
--- @param filetype string The filetype to check
--- @return boolean valid Whether the filetype is acceptable
function M.is_valid_filetype(filetype)
	-- Supported file types for token counting
	local valid_types = {
		-- Programming languages
		"lua", "python", "go", "rust", "java", "c", "cpp", "zig",
		
		-- Web development
		"javascript", "typescript", "jsx", "tsx",
		"javascriptreact", "typescriptreact",
		"vue", "svelte",
		"html", "css", "scss", "sass", "less", "stylus",
		"json", "json5", "jsonc",
		"xml", "svg",
		
		-- Shell and scripting
		"sh", "bash", "zsh", "fish", "powershell", "ps1",
		"vim", "viml", "vimscript",
		"ruby", "php", "swift", "kotlin", "scala", "clojure", "haskell",
		"elixir", "erlang", "dart", "crystal", "nim",
		"assembly", "asm", "nasm", "gas", "objc", "objcpp",
		"ocaml", "fsharp", "racket", "scheme", "lisp", "commonlisp",
		
		-- Configuration and data
		"yaml", "yml", "toml", "ini", "cfg", "conf", "config", "properties",
		"env", "dotenv",
		"markdown", "md", "rst", "org", "asciidoc", "tex", "latex", "bibtex",
		"txt", "text", "plaintext",
		"sql", "mysql", "postgresql", "sqlite", "plsql",
		"graphql", "gql",
		"dockerfile", "docker", "containerfile",
		"terraform", "tf", "hcl",
		"ansible", "yaml.ansible",
		"make", "makefile", "cmake", "ninja", "bazel", "buck",
		"gradle", "maven", "sbt",
		"diff", "patch", "gitcommit", "gitrebase", "gitconfig",
		"gitignore", "gitattributes",
		"csv", "tsv", "psv", "ssv",
		"proto", "protobuf", "grpc",
		"log", "logs", "trace",
		"jupyter", "ipynb",
		"r", "rmd", "rnw",
		"julia", "jl",
		"matlab", "m",
		"octave",
		"stata", "do", "ado",
		"sas",
		"edge", "liquid", "mustache", "handlebars", "jinja", "j2",
		"email", "mail", "eml",
		"requirements", "pipfile", "poetry",
		"gemfile", "rakefile", "guardfile",
		"cargo",
		"pom",
	}

	-- Handle empty or nil filetype
	if not filetype or filetype == "" then
		return false
	end

	-- Check if filetype is in our valid list
	for _, valid_type in ipairs(valid_types) do
		if filetype == valid_type then
			return true
		end
	end

	return false
end

--- Check if a buffer is safe to work with (not floating, not special)
--- @param buffer_id number Buffer ID to check
--- @return boolean safe Whether the buffer is safe to work with
function M.is_safe_buffer(buffer_id)
	-- Check if buffer exists and is loaded
	if not vim.api.nvim_buf_is_valid(buffer_id) or not vim.api.nvim_buf_is_loaded(buffer_id) then
		return false
	end

	-- Check buffer type - skip special buffers
	local buftype = vim.api.nvim_buf_get_option(buffer_id, "buftype")
	if buftype ~= "" then
		return false -- Skip quickfix, help, terminal, etc.
	end

	-- Check if buffer is in a floating window
	local win_ids = vim.fn.win_findbuf(buffer_id)
	for _, win_id in ipairs(win_ids) do
		if vim.api.nvim_win_is_valid(win_id) then
			local win_config = vim.api.nvim_win_get_config(win_id)
			if win_config.relative ~= "" then
				return false -- Skip floating windows
			end
		end
	end

	-- Check for telescope and other plugin buffers by name patterns
	local bufname = vim.api.nvim_buf_get_name(buffer_id)
	if
		bufname:match("telescope://")
		or bufname:match("^%[.*%]$") -- Buffers like [Command Line], [Prompt]
		or bufname:match("neo%-tree")
		or bufname:match("NvimTree")
		or bufname:match("^term://")
	then
		return false
	end

	return true
end

--- Check if a buffer is valid for token counting without switching to it
--- @param buffer_id number Buffer ID to check
--- @return boolean valid Whether the buffer is valid for token counting
function M.is_buffer_valid_for_counting(buffer_id)
	-- First check if buffer is safe to work with
	if not M.is_safe_buffer(buffer_id) then
		return false
	end

	-- Get filetype without switching buffers
	local filetype = vim.api.nvim_buf_get_option(buffer_id, "filetype")
	return M.is_valid_filetype(filetype)
end

return M