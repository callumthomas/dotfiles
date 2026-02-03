return {
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		config = function()
			local builtin = require("telescope.builtin")

			-- Set up keymaps
			vim.keymap.set(
				"n",
				"<leader>fb",
				"<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>",
				{ desc = "Find Buffer" }
			)

			vim.keymap.set("n", "<leader>/", function()
				builtin.live_grep()
			end, { desc = "Grep" })

			vim.keymap.set("n", "<leader>fc", "<cmd>Telescope command_history<cr>", { desc = "Command History" })
			vim.keymap.set("n", "<leader>fh", "<cmd>noh<cr>", { desc = "Clear Highlight" })

			vim.keymap.set("n", "<leader><space>", function()
				builtin.find_files({
					attach_mappings = function(_, map)
						map("i", "<C-p>", require("telescope.actions.layout").toggle_preview)
						map("n", "<C-p>", require("telescope.actions.layout").toggle_preview)
						return true
					end,
				})
			end, { desc = "Find Project Files" })

			vim.keymap.set("n", "<leader>ff", function()
				builtin.find_files({
					hidden = true,
					no_ignore = true,
				})
			end, { desc = "Find Anything" })
		end,
	},
}
