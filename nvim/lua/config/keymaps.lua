-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set

-- copy to system clipboard
keymap({ "n", "v", "x" }, "<leader>y", '"+y')
keymap({ "n", "v", "x" }, "<leader>Y", '"+y')

-- delete without buffer
keymap({ "n", "v", "x" }, "<leader>d", '"_d')

-- auto center motions
keymap("n", "<C-d>", "<C-d>zz")
keymap("n", "<C-u>", "<C-u>zz")
keymap("n", "n", "nzzzv")
keymap("n", "N", "Nzzzv")

-- paste without replacing buffer
keymap({ "x", "v" }, "<leader>p", '"_dP')
