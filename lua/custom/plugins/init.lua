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
  -- Dashboard
  {
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local dashboard = require 'dashboard'

      -- Generate system info footer
      local function get_footer()
        local stats = {}
        local total_plugins = #vim.tbl_keys(require('lazy').plugins())
        local datetime = os.date '%Y-%m-%d %H:%M:%S'
        local version = vim.version()
        local nvim_version = 'v' .. version.major .. '.' .. version.minor .. '.' .. version.patch

        table.insert(stats, '')
        table.insert(stats, '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
        table.insert(stats, string.format('  Neovim %s  |  %d plugins  |  %s', nvim_version, total_plugins, datetime))
        table.insert(stats, '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')

        return stats
      end

      dashboard.setup {
        theme = 'hyper',
        config = {
          header = {},
          week_header = {
            enable = false,
          },
          packages = { enable = false },
          shortcut = {
            {
              desc = '󰈞 Find',
              group = 'DiagnosticInfo',
              key = 'f',
              action = function()
                require('telescope').extensions['recent-files'].recent_files {}
              end,
            },
            {
              desc = '󰱽 Grep',
              group = '@property',
              key = 'r',
              action = function()
                require('telescope.builtin').live_grep()
              end,
            },
            {
              desc = '󰊢 Git',
              group = 'DiagnosticWarn',
              key = 'g',
              action = function()
                require('telescope.builtin').git_status()
              end,
            },
            {
              desc = '󱐋 Practice',
              group = 'DiagnosticOk',
              key = 'p',
              action = function()
                vim.cmd 'VimBeGood'
              end,
            },
            {
              desc = '󰈆 Quit',
              group = 'DiagnosticError',
              key = 'q',
              action = function()
                vim.cmd 'qa'
              end,
            },
          },
          project = { enable = true, limit = 8, label = 'Recent Projects' },
          mru = { limit = 10, label = 'Recent Files' },
          footer = get_footer,
        },
        hide = {
          statusline = false,
          tabline = false,
          winbar = false,
        },
      }

      -- Custom highlight for footer
      vim.api.nvim_set_hl(0, 'DashboardFooter', { fg = '#9d7cd8' }) -- Purple

      -- Add keybinding reference section after footer
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'dashboard',
        callback = function()
          local buf = vim.api.nvim_get_current_buf()
          local ns = vim.api.nvim_create_namespace('dashboard_footer')

          -- Find and color the footer lines (search for the separator lines)
          local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          for i, line in ipairs(lines) do
            if line:match('━━━━━━') then
              -- Apply purple color to separator and info line
              vim.api.nvim_buf_add_highlight(buf, ns, 'DashboardFooter', i - 1, 0, -1)
              if i < #lines then
                vim.api.nvim_buf_add_highlight(buf, ns, 'DashboardFooter', i, 0, -1)
              end
              if i + 1 <= #lines then
                vim.api.nvim_buf_add_highlight(buf, ns, 'DashboardFooter', i + 1, 0, -1)
              end
            end
          end

          vim.api.nvim_buf_set_option(buf, 'modifiable', true)

          local line_count = vim.api.nvim_buf_line_count(buf)
          local keybinds = {
            '',
            '  Quick Reference:',
            '  ━━━━━━━━━━━━━━━',
            '  <leader>n   File Explorer (Neo-tree)',
            '  <leader>ac  Claude Code (toggle)',
            '  <leader>af  Claude Code (focus)',
            '  ',
            '  Full keybindings: https://sao.bros.ninja/keybindings',
          }

          vim.api.nvim_buf_set_lines(buf, line_count, -1, false, keybinds)
          vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        end,
      })
    end,
  },
}
