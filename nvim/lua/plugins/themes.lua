return {
  dir = "~/.config/nvim/lua/ghostty-theme",
  name = "ghostty-theme",
  lazy = false,
  priority = 1000,
  config = function()
    require('ghostty-theme')
  end,
}

