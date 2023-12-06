local set = vim.opt

set.number = true
set.autoindent = true
set.tabstop = 4
set.shiftwidth = 4
set.smarttab = true
set.softtabstop = 4
--set.mouse = "a"

-- https://www.reddit.com/r/neovim/comments/p3b20j/lua_solution_to_writing_a_file_using_sudo/
vim.api_nvim_set_keymap('c', 'w!!', "<esc>:lua require'utils'.sudo_write()<CR>", { silent = true })


-- Set up lazy.nvim. Code copied from https://github.com/folke/lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup(plugins, opts)
