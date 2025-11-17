return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter.configs").setup({
				-- Install parsers for these languages
				ensure_installed = {
					"lua",
					"vim",
					"vimdoc",
					"query",
					"javascript",
					"typescript",
					"python",
					"go",
					"rust",
					"php",
					"xml",
					"html",
					"css",
					"tsx",
					"json",
				},

				sync_install = false,

				auto_install = true,

				highlight = {
					enable = true,
				},

				indent = {
					enable = true,
				},
			})
		end,
	},
}
