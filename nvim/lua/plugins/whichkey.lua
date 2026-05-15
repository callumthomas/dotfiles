return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		preset = "modern", -- or "classic", "helix"
		icons = {
			breadcrumb = "»",
			separator = "➜",
			group = "+",
		},
		win = {
			border = "rounded",
			padding = { 1, 2 }, -- extra window padding [top/bottom, right/left]
		},
		-- Add this to make which-key show up automatically
		delay = 300, -- delay before showing which-key (replaces timeoutlen handling)
	},
	config = function(_, opts)
		local wk = require("which-key")
		wk.setup(opts)
		-- Register leader key groups for better organization
		wk.add({
			{ "<leader>c", group = "Code" },
			{ "<leader>f", group = "File/Find" },
			{ "<leader>g", group = "Git" },
		})
	end,
}
