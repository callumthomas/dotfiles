return {
	"lewis6991/gitsigns.nvim",
	event = "VeryLazy",
	opts = {
		current_line_blame = true,
		current_line_blame_opts = {
			delay = 300,
		},
		current_line_blame_formatter = " <summary> • <author_time:%m-%d-%Y %H:%M:%S> • <author> • <<abbrev_sha>>",
		on_attach = function(bufnr)
			local gs = require("gitsigns")
			local opts = { buffer = bufnr }

			vim.keymap.set("n", "]h", function()
				if vim.wo.diff then
					return "]c"
				end
				vim.schedule(function()
					gs.next_hunk()
				end)
				return "<Ignore>"
			end, vim.tbl_extend("force", opts, { expr = true, desc = "Next hunk" }))

			vim.keymap.set("n", "[h", function()
				if vim.wo.diff then
					return "[c"
				end
				vim.schedule(function()
					gs.prev_hunk()
				end)
				return "<Ignore>"
			end, vim.tbl_extend("force", opts, { expr = true, desc = "Previous hunk" }))

			vim.keymap.set("n", "<leader>gs", gs.stage_hunk, vim.tbl_extend("force", opts, { desc = "Stage hunk" }))
			vim.keymap.set("n", "<leader>gr", gs.reset_hunk, vim.tbl_extend("force", opts, { desc = "Reset hunk" }))
			vim.keymap.set("n", "<leader>gp", gs.preview_hunk, vim.tbl_extend("force", opts, { desc = "Preview hunk" }))
			vim.keymap.set("n", "<leader>gb", gs.blame_line, vim.tbl_extend("force", opts, { desc = "Blame line" }))
		end,
	},
}
