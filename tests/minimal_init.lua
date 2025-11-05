-- Minimal init for running tests
vim.cmd [[set runtimepath=$VIMRUNTIME]]
vim.cmd [[set packpath=/tmp/nvim/site]]

-- Add plenary.nvim (test framework)
local package_root = '/tmp/nvim/site/pack'
local install_path = package_root .. '/packer/start/plenary.nvim'

local function load_plugins()
  require('plenary.busted')
end

if vim.fn.isdirectory(install_path) == 0 then
  print 'Installing plenary.nvim...'
  vim.fn.system {
    'git',
    'clone',
    '--depth=1',
    'https://github.com/nvim-lua/plenary.nvim.git',
    install_path,
  }
end

vim.cmd('packadd plenary.nvim')

-- Add gravity plugin to runtime path
vim.opt.rtp:append('.')

load_plugins()
