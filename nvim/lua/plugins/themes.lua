-- return {
-- 	"navarasu/onedark.nvim",
-- 	priority = 1000, -- make sure to load this before all the other start plugins
-- 	config = function()
-- 		require('onedark').setup {
-- 			style = 'darker',
-- 			highlights = {},
-- 			code_style = {
-- 				comments = "italic",
-- 				keywords = "none",
-- 				functions = "none",
-- 				strings = "none",
-- 				variables = "none",
-- 			},
-- 		}
-- 		require('onedark').load()
-- 	end
-- }

return {
	{
		"0Risotto/rainbow12",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd("colorscheme rainbow12")
		end,
	},
}
