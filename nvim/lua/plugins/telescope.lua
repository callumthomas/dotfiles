return {
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		config = function()
			local builtin = require("telescope.builtin")

			-- Set up keymaps
			vim.keymap.set("n", "<leader>,", "<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>")

			vim.keymap.set("n", "<leader>/", function()
				require("telescope.builtin").live_grep()
			end)

			vim.keymap.set("n", "<leader>:", "<cmd>Telescope command_history<cr>")

			vim.keymap.set("n", "<leader><space>", function()
				require("telescope.builtin").find_files({

				})
			end)
		end,
	},
}
