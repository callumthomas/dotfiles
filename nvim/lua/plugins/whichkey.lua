return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		icons = {
			breadcrumb = "»",
			separator = "➜",
			group = "+",
		},
		window = {
			border = "rounded",
			position = "bottom",
			margin = { 1, 0, 1, 0 },
			padding = { 1, 2, 1, 2 },
		},
	},
	config = function(_, opts)
		local wk = require("which-key")
		wk.setup(opts)

		-- Register leader key groups for better organization
		wk.add({
			{ "<leader>c", group = "Code" },
			{ "<leader>f", group = "File/Find" },
			{ "<leader>g", group = "Git" },
			{ "<leader>s", group = "Search" },
			{ "<leader>w", group = "Window" },
			{ "<leader>x", group = "Diagnostics/Quickfix" },
		})
	end,
}
