return {
  {
    "zaldih/themery.nvim",
    lazy = false,
    config = function()
      require("themery").setup({
        -- add the config here
      })
    end,
  },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
}
