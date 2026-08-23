local set = vim.opt

set.number = true
set.autoindent = true
set.tabstop = 4
set.shiftwidth = 4
set.smarttab = true
set.softtabstop = 4
set.splitbelow = true
set.splitright = true
--set.mouse = "a"


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

local plugins = {
	"lambdalisue/suda.vim",
	{
		"nvim-treesitter/nvim-treesitter",
		config = function()
			require("nvim-treesitter.configs").setup({
				-- From https://github.com/nvim-treesitter/nvim-treesitter

				-- A list of parser names, or "all" (the five listed parsers should always be installed)
				ensure_installed = { "c", "lua", "vim", "vimdoc", "query" },

				-- Automatically install missing parsers when entering buffer
				-- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
				auto_install = true,

				highlight = {
					enable = true
				}
			})
		end
	}
}


require("lazy").setup(plugins, opts)

-- Bind :w!! to sudo write
vim.keymap.set("ca", "w!!", "SudaWrite")

-- Set color scheme
-- vim.cmd.colorscheme("lunaperche")
vim.cmd.colorscheme("sorbet") -- Might like this one a bit more!

