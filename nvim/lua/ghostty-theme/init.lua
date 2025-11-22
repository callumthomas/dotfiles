local M = {}

-- Color palette from Ghostty
local colors = {
	-- Terminal colors
	black = "#1a1a1a",
	red = "#f4005f",
	green = "#98e024",
	yellow = "#fd971f",
	blue = "#9d65ff",
	magenta = "#f4005f",
	cyan = "#58d1eb",
	white = "#c4c5b5",

	-- Bright colors
	bright_black = "#625e4c",
	bright_red = "#f4005f",
	bright_green = "#98e024",
	bright_yellow = "#e0d561",
	bright_blue = "#9d65ff",
	bright_magenta = "#f4005f",
	bright_cyan = "#58d1eb",
	bright_white = "#f6f6ef",

	-- UI colors
	background = "#0c0c0c",
	foreground = "#d9d9d9",
	cursor = "#fc971f",
	cursor_text = "#000000",
	selection_bg = "#343434",
	selection_fg = "#ffffff",

	-- Additional UI colors (derived)
	dark_bg = "#080808",
	light_bg = "#1a1a1a",
	comment = "#625e4c",
	line_number = "#625e4c",
}

function M.setup()
	-- Reset colors
	vim.cmd("highlight clear")
	if vim.fn.exists("syntax_on") then
		vim.cmd("syntax reset")
	end

	vim.o.termguicolors = true
	vim.g.colors_name = "ghostty-theme"

	local highlights = {
		-- Editor
		Normal = { fg = colors.foreground, bg = "none" },  -- Changed from colors.background
		NormalFloat = { fg = colors.foreground, bg = "none" },  -- Changed from colors.light_bg
		NormalNC = { fg = colors.foreground, bg = "none" },  -- Changed from colors.background

		-- Line numbers
		LineNr = { fg = colors.line_number },
		SignColumn = { fg = colors.line_number, bg = "none" },  -- Changed from colors.background

		-- Statusline (optional - you might want to keep these opaque)
		StatusLine = { fg = colors.foreground, bg = "none" },  -- Changed from colors.light_bg
		StatusLineNC = { fg = colors.comment, bg = "none" },  -- Changed from colors.light_bg

		-- Tabline (optional)
		TabLine = { fg = colors.comment, bg = "none" },
		TabLineFill = { bg = "none" },
		TabLineSel = { fg = colors.foreground, bg = "none", bold = true },

		-- Editor
		-- Normal = { fg = colors.foreground, bg = colors.background },
		-- NormalFloat = { fg = colors.foreground, bg = colors.light_bg },
		-- NormalNC = { fg = colors.foreground, bg = colors.background },

		-- Cursor
		Cursor = { fg = colors.cursor_text, bg = colors.cursor },
		CursorLine = { bg = colors.light_bg },
		CursorColumn = { bg = colors.light_bg },
		CursorLineNr = { fg = colors.bright_yellow, bold = true },

		-- Line numbers
		-- LineNr = { fg = colors.line_number },
		-- SignColumn = { fg = colors.line_number, bg = colors.background },

		-- Visual mode
		Visual = { fg = colors.selection_fg, bg = colors.selection_bg },
		VisualNOS = { fg = colors.selection_fg, bg = colors.selection_bg },

		-- Search
		Search = { fg = colors.cursor_text, bg = colors.yellow },
		IncSearch = { fg = colors.cursor_text, bg = colors.cursor },

		-- Splits
		VertSplit = { fg = colors.comment },
		WinSeparator = { fg = colors.comment },

		-- Statusline
		-- StatusLine = { fg = colors.foreground, bg = colors.light_bg },
		-- StatusLineNC = { fg = colors.comment, bg = colors.light_bg },

		-- Tabline
		TabLine = { fg = colors.comment, bg = colors.light_bg },
		TabLineFill = { bg = colors.light_bg },
		TabLineSel = { fg = colors.foreground, bg = colors.background, bold = true },

		-- Popups
		Pmenu = { fg = colors.foreground, bg = colors.light_bg },
		PmenuSel = { fg = colors.selection_fg, bg = colors.selection_bg },
		PmenuSbar = { bg = colors.light_bg },
		PmenuThumb = { bg = colors.comment },

		-- Syntax
		Comment = { fg = colors.comment, italic = true },
		Constant = { fg = colors.magenta },
		String = { fg = colors.green },
		Character = { fg = colors.green },
		Number = { fg = colors.magenta },
		Boolean = { fg = colors.magenta },
		Float = { fg = colors.magenta },

		Identifier = { fg = colors.foreground },
		Function = { fg = colors.blue },

		Statement = { fg = colors.red },
		Conditional = { fg = colors.red },
		Repeat = { fg = colors.red },
		Label = { fg = colors.red },
		Operator = { fg = colors.red },
		Keyword = { fg = colors.red },
		Exception = { fg = colors.red },

		PreProc = { fg = colors.cyan },
		Include = { fg = colors.cyan },
		Define = { fg = colors.cyan },
		Macro = { fg = colors.cyan },
		PreCondit = { fg = colors.cyan },

		Type = { fg = colors.cyan },
		StorageClass = { fg = colors.cyan },
		Structure = { fg = colors.cyan },
		Typedef = { fg = colors.cyan },

		Special = { fg = colors.yellow },
		SpecialChar = { fg = colors.yellow },
		Tag = { fg = colors.yellow },
		Delimiter = { fg = colors.foreground },
		SpecialComment = { fg = colors.comment, italic = true },
		Debug = { fg = colors.red },

		Underlined = { underline = true },
		Ignore = { fg = colors.comment },
		Error = { fg = colors.red, bold = true },
		Todo = { fg = colors.yellow, bold = true },

		-- Treesitter
		["@variable"] = { fg = colors.foreground },
		["@variable.builtin"] = { fg = colors.magenta },
		["@variable.parameter"] = { fg = colors.foreground },
		["@variable.member"] = { fg = colors.foreground },

		["@constant"] = { fg = colors.magenta },
		["@constant.builtin"] = { fg = colors.magenta },

		["@string"] = { fg = colors.green },
		["@string.escape"] = { fg = colors.yellow },
		["@string.regexp"] = { fg = colors.yellow },

		["@number"] = { fg = colors.magenta },
		["@boolean"] = { fg = colors.magenta },

		["@function"] = { fg = colors.blue },
		["@function.builtin"] = { fg = colors.cyan },
		["@function.macro"] = { fg = colors.cyan },

		["@keyword"] = { fg = colors.red },
		["@keyword.function"] = { fg = colors.red },
		["@keyword.operator"] = { fg = colors.red },
		["@keyword.return"] = { fg = colors.red },

		["@operator"] = { fg = colors.red },

		["@type"] = { fg = colors.cyan },
		["@type.builtin"] = { fg = colors.cyan },

		["@property"] = { fg = colors.foreground },
		["@attribute"] = { fg = colors.cyan },

		["@constructor"] = { fg = colors.blue },

		["@tag"] = { fg = colors.red },
		["@tag.attribute"] = { fg = colors.cyan },
		["@tag.delimiter"] = { fg = colors.comment },

		-- Git
		DiffAdd = { fg = colors.green, bg = colors.dark_bg },
		DiffChange = { fg = colors.yellow, bg = colors.dark_bg },
		DiffDelete = { fg = colors.red, bg = colors.dark_bg },
		DiffText = { fg = colors.yellow, bg = colors.light_bg },

		-- Diagnostic
		DiagnosticError = { fg = colors.red },
		DiagnosticWarn = { fg = colors.yellow },
		DiagnosticInfo = { fg = colors.cyan },
		DiagnosticHint = { fg = colors.comment },

		DiagnosticUnderlineError = { undercurl = true, sp = colors.red },
		DiagnosticUnderlineWarn = { undercurl = true, sp = colors.yellow },
		DiagnosticUnderlineInfo = { undercurl = true, sp = colors.cyan },
		DiagnosticUnderlineHint = { undercurl = true, sp = colors.comment },
	}

	-- Apply highlights
	for group, opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, group, opts)
	end
end

-- Setup on load
M.setup()

return M
