return {
	"folke/snacks.nvim",
	lazy = false,
	---@type snacks.Config
	opts = {
		picker = {},
	},
	keys = {
		{
			"<leader><space>",
			function()
				Snacks.picker.files()
			end,
			desc = "Find Project Files",
		},
		{
			"<leader>ff",
			function()
				Snacks.picker.files({ hidden = true, ignored = true })
			end,
			desc = "Find Anything",
		},
		{
			"<leader>fb",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Find Buffer",
		},
		{
			"<leader>/",
			function()
				Snacks.picker.grep()
			end,
			desc = "Grep",
		},
		{
			"<leader>fc",
			function()
				Snacks.picker.command_history()
			end,
			desc = "Command History",
		},
		{ "<leader>fh", "<cmd>noh<cr>", desc = "Clear Highlight" },
	},
}
