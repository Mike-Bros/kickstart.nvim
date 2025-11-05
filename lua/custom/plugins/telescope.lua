return {
  'nvim-telescope/telescope.nvim',
  event = 'VimEnter',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons',
    'nvim-telescope/telescope-live-grep-args.nvim',
    { -- If encountering errors, see telescope-fzf-native README for install instructions
      'nvim-telescope/telescope-fzf-native.nvim',

      -- `build` is used to run some command when the plugin is installed/updated.
      -- This is only run then, not every time Neovim starts up.
      build = 'make',

      -- `cond` is a condition used to determine whether this plugin should be
      -- installed and loaded.
      cond = function()
        return vim.fn.executable 'make' == 1
      end,
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },
    'mollerhoj/telescope-recent-files.nvim',
  },
  keys = {
    {
      '<leader>sl',
      function()
        require('telescope.builtin').lsp_document_symbols()
      end,
      desc = '[S]earch [L]SP Document Symbols',
    },
    {
      '<leader>sh',
      function()
        require('telescope.builtin').help_tags()
      end,
      desc = '[S]earch [H]elp',
    },
    {
      '<leader>sk',
      function()
        require('telescope.builtin').keymaps()
      end,
      desc = '[S]earch [K]eymaps',
    },
    {
      '<C-p>',
      function()
        -- require("telescope.builtin").find_files()
        require('telescope').extensions['recent-files'].recent_files {}
      end,
      desc = '[S]earch [F]iles',
    },
    {
      '<leader>sf',
      function()
        require('telescope').extensions['recent-files'].recent_files {}
      end,
      desc = '[S]earch [F]iles',
    },
    {
      '<leader>sa',
      function()
        require('telescope.builtin').find_files { no_ignore = true, prompt_title = 'All Files' }
      end,
      desc = '[S]earch [A]ll Files',
    },
    {
      '<leader>ss',
      function()
        require('telescope.builtin').builtin()
      end,
      desc = '[S]earch [S]elect Telescope',
    },
    {
      '<leader>sw',
      function()
        require('telescope.builtin').grep_string()
      end,
      desc = '[S]earch current [W]ord',
    },
    {
      '<leader>sg',
      function()
        require('telescope.builtin').live_grep()
      end,
      desc = '[S]earch by [G]rep',
    },
    {
      '<leader>sd',
      function()
        require('telescope.builtin').diagnostics()
      end,
      desc = '[S]earch [D]iagnostics',
    },
    {
      '<leader>sr',
      function()
        require('telescope.builtin').resume()
      end,
      desc = '[S]earch [R]esume',
    },
    {
      '<leader>s.',
      function()
        require('telescope.builtin').oldfiles()
      end,
      desc = "[S]earch Recent Files ('.' for repeat)",
    },
    {
      '<leader><leader>',
      function()
        require('telescope.builtin').buffers()
      end,
      desc = '[ ] Find existing buffers',
    },
    {
      '<leader>gs',
      function()
        require('telescope.builtin').git_status()
      end,
      desc = '[G]it [S]tatus (modified files)',
    },
    {
      '<leader>gc',
      function()
        require('telescope.builtin').git_commits()
      end,
      desc = '[G]it [C]ommits (history)',
    },
    {
      '<leader>gb',
      function()
        require('telescope.builtin').git_branches()
      end,
      desc = '[G]it [B]ranches',
    },
  },
  config = function()
    local actions = require 'telescope.actions'

    require('telescope').setup {
      defaults = {
        path_display = { truncate = 1 },
        prompt_prefix = ' 🔍  ',
        selection_caret = '  ',
        layout_config = {
          prompt_position = 'top',
        },
        preview = {
          timeout = 200,
        },
        sorting_strategy = 'ascending',
        mappings = {
          i = {
            ['<esc>'] = actions.close,
            ['<C-Down>'] = actions.cycle_history_next,
            ['<C-Up>'] = actions.cycle_history_prev,
          },
        },
        file_ignore_patterns = { '.git/' },
      },
      extensions = {
        live_grep_args = {
          mappings = {
            i = {
              ['<C-k>'] = require('telescope-live-grep-args.actions').quote_prompt(),
              ['<C-i>'] = require('telescope-live-grep-args.actions').quote_prompt {
                postfix = ' --iglob ',
              },
            },
          },
        },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
        buffers = {
          previewer = false,
          layout_config = {
            width = 80,
          },
        },
        oldfiles = {
          prompt_title = 'History',
          cwd_only = true,
        },
        lsp_references = {
          previewer = false,
        },
        lsp_definitions = {
          previewer = false,
        },
        lsp_document_symbols = {
          symbol_width = 55,
        },
      },
    }

    require('telescope').load_extension 'fzf'
    require('telescope').load_extension 'recent-files'
  end,
}
