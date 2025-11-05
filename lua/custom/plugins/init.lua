-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  -- gravity.nvim: Smart dotfile sync
  {
    name = 'gravity.nvim',
    dir = vim.fn.stdpath 'config' .. '/lua/custom/gravity',
    config = function()
      require('custom.gravity').setup()
    end,
    lazy = false,
    priority = 100,
  },
  {
    'ThePrimeagen/vim-be-good',
    cmd = 'VimBeGood',
  },
  -- Claude Code integration
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    config = true,
    keys = {
      { '<leader>ac', '<cmd>ClaudeCode<cr>', desc = 'Toggle Claude' },
      { '<leader>af', '<cmd>ClaudeCodeFocus<cr>', desc = 'Focus Claude' },
    },
  },
  -- Formatting plugin
  {
    'stevearc/conform.nvim',
    lazy = true,
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local conform = require 'conform'

      conform.setup {
        formatters_by_ft = {
          -- Go: goimports adds/removes imports, gofumpt does strict formatting
          go = { 'goimports', 'gofumpt' },

          -- React / TypeScript / JSON
          javascript = { 'biome', 'prettier' },
          typescript = { 'biome', 'prettier' },
          javascriptreact = { 'biome', 'prettier' },
          typescriptreact = { 'biome', 'prettier' },
          json = { 'biome', 'prettier' },

          -- Lua
          lua = { 'stylua' },
        },

        -- Auto format on save
        format_on_save = {
          lsp_fallback = true,
          timeout_ms = 5000,
        },

        notify_on_error = true,
      }
    end,
  },
}
