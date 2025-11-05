local sync = require 'custom.gravity.sync'
local utils = require 'custom.gravity.utils'
local manifest_lib = require 'custom.gravity.manifest'

local M = {}

-- Symbols used throughout gravity.nvim
local SYMBOLS = {
  -- Status symbols
  unchanged = '✓',
  source_changed = '→',
  system_changed = '←',
  conflict = '⚠',
  missing_system = '○',
  missing_source = '✗',
  out_of_sync = '◌',
  -- Action symbols
  success = '✓',
  warning = '⚠',
  syncing = '→',
}

-- Highlight groups for each status type
local HIGHLIGHTS = {
  unchanged = 'DiagnosticOk', -- Green
  source_changed = 'DiagnosticInfo', -- Blue
  system_changed = 'DiagnosticWarn', -- Yellow
  conflict = 'DiagnosticError', -- Red
  missing_system = 'Comment', -- Gray
  missing_source = 'DiagnosticError', -- Red
  out_of_sync = 'DiagnosticWarn', -- Yellow
  success = 'DiagnosticOk', -- Green
  warning = 'DiagnosticWarn', -- Yellow
}

-- Format change type for display with color
local function format_change_type(change_type)
  local descriptions = {
    unchanged = 'unchanged',
    source_changed = 'source changed',
    system_changed = 'system changed',
    conflict = 'CONFLICT',
    missing_system = 'not on system',
    missing_source = 'missing source',
    out_of_sync = 'out of sync',
  }

  local symbol = SYMBOLS[change_type] or '?'
  local desc = descriptions[change_type] or change_type
  local hl = HIGHLIGHTS[change_type] or 'Normal'

  return symbol .. ' ' .. desc, hl
end

-- Print colored text
local function cprint(text, hl_group)
  if type(text) == 'table' then
    -- Multiple parts with different highlights
    vim.api.nvim_echo(text, false, {})
  else
    -- Single text with one highlight
    vim.api.nvim_echo({ { text, hl_group or 'Normal' } }, false, {})
  end
end

-- Create a floating window with content
local function create_float_window(opts)
  opts = opts or {}
  local title = opts.title or ' gravity.nvim '
  local lines = opts.lines or {}
  local highlights = opts.highlights or {}
  local keymaps = opts.keymaps or {}
  local on_close = opts.on_close

  -- Calculate window size
  local max_line_width = 0
  for _, line in ipairs(lines) do
    max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(line))
  end

  local width = math.min(math.max(max_line_width + 4, 60), vim.o.columns - 10)
  local height = math.min(#lines + 2, vim.o.lines - 10)

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'gravity')

  -- Calculate window position (centered)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  -- Window options
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
  }

  -- Create window
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal,FloatBorder:FloatBorder')

  -- Set content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace('gravity_window')
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, ns_id, hl.group, hl.line, hl.col_start or 0, hl.col_end or -1)
  end

  -- Close window function
  local function close_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if on_close then
      on_close()
    end
  end

  -- Default close keymaps
  vim.keymap.set('n', 'q', close_window, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close_window, { buffer = buf, nowait = true })

  -- Custom keymaps
  for key, action in pairs(keymaps) do
    vim.keymap.set('n', key, function()
      action(close_window, buf, win)
    end, { buffer = buf, nowait = true })
  end

  return {
    buf = buf,
    win = win,
    close = close_window,
  }
end

-- Command: :GravityStatus
-- Shows which config files differ from repo
function M.status()
  local ok, status = pcall(sync.get_status)
  if not ok then
    vim.notify('Error loading gravity status: ' .. status, vim.log.levels.ERROR)
    return
  end

  if vim.tbl_isempty(status) then
    vim.notify('No config files configured in manifest.json', vim.log.levels.WARN)
    return
  end

  -- Build window content
  local lines = {}
  local highlights = {}

  table.insert(lines, '')
  table.insert(lines, 'Config File Status:')
  table.insert(lines, '')

  -- Sort by key for consistent display
  local keys = vim.tbl_keys(status)
  table.sort(keys)

  local has_changes = false

  for _, key in ipairs(keys) do
    local info = status[key]
    local change_type = info.change_type
    local formatted, hl = format_change_type(change_type)

    if change_type ~= 'unchanged' then
      has_changes = true
    end

    local override_indicator = info.used_override and ' [override]' or ''
    local line = '  ' .. formatted .. ' - ' .. key .. override_indicator
    table.insert(lines, line)

    -- Highlight the symbol (first character after spaces)
    table.insert(highlights, { group = hl, line = #lines - 1, col_start = 2, col_end = 3 })
  end

  table.insert(lines, '')
  table.insert(lines, '────────────────────────────────────────────────────────')
  table.insert(lines, '')

  if not has_changes then
    local msg = SYMBOLS.success .. ' All config files in sync'
    table.insert(lines, '  ' .. msg)
    table.insert(highlights, { group = HIGHLIGHTS.success, line = #lines - 1, col_start = 2, col_end = 3 })
  else
    table.insert(lines, '  Press [s] to sync changes')
  end

  table.insert(lines, '  Press [q] to close')
  table.insert(lines, '')

  -- Show floating window
  create_float_window {
    title = ' gravity.nvim - Status ',
    lines = lines,
    highlights = highlights,
    keymaps = {
      s = function(close_fn)
        close_fn()
        vim.schedule(function()
          M.sync_all()
        end)
      end,
    },
  }
end

-- Command: :GravitySync
-- Main entry point - shows full status and interactive menu
-- Perform the actual sync operation
local function perform_sync()
  -- Perform sync
  vim.notify('Syncing...', vim.log.levels.INFO)
  local ok, result = pcall(sync.sync_all, { quiet = false, force = true })

  if not ok then
    vim.notify('Error during sync: ' .. result, vim.log.levels.ERROR)
    return
  end

  -- Show results
  local msg = string.format(
    'Synced %d file%s, %d unchanged, %d skipped',
    result.synced,
    result.synced == 1 and '' or 's',
    result.unchanged,
    result.skipped
  )
  vim.notify(msg, vim.log.levels.INFO)
end

-- Check for system changes and show warning, or sync directly
local function do_sync_operation(status, files_to_sync)
  -- Check for system changes that would be overwritten
  local system_changed_files = {}
  for _, key in ipairs(files_to_sync) do
    local info = status[key]
    if info.change_type == 'system_changed' then
      table.insert(system_changed_files, key)
    end
  end

  -- If no system changes, sync directly
  if #system_changed_files == 0 then
    perform_sync()
    return
  end

  -- Warn about overwriting system changes with floating window
  local lines = {}
  local highlights = {}

  table.insert(lines, '')
  table.insert(lines, '⚠  WARNING: Local System Changes Detected')
  table.insert(highlights, { group = 'DiagnosticWarn', line = #lines - 1, col_start = 0, col_end = 1 })
  table.insert(lines, '')
  table.insert(lines, 'The following files have local changes that will be OVERWRITTEN:')
  table.insert(lines, '')

  for _, key in ipairs(system_changed_files) do
    table.insert(lines, '  • ' .. key)
    table.insert(highlights, { group = 'DiagnosticWarn', line = #lines - 1, col_start = 2, col_end = 3 })
  end

  table.insert(lines, '')
  table.insert(lines, 'Protection:')
  table.insert(lines, '  ✓ Timestamped backup will be created in backups/ directory')
  table.insert(highlights, { group = 'DiagnosticOk', line = #lines - 1, col_start = 2, col_end = 3 })
  table.insert(lines, '')
  table.insert(lines, 'To permanently preserve local changes instead:')
  table.insert(lines, '  1. Copy file to configs.overrides/ directory')
  table.insert(lines, '  2. Example: cp ~/.bashrc ~/.config/nvim/configs.overrides/.bashrc')
  table.insert(lines, '')
  table.insert(lines, '────────────────────────────────────────────────────────')
  table.insert(lines, '')
  table.insert(lines, '  Press [y] to proceed with sync (backup will be created)')
  table.insert(lines, '  Press [n] or [q] to cancel and preserve local changes')
  table.insert(lines, '')

  create_float_window {
    title = ' ⚠  Confirm Overwrite ',
    lines = lines,
    highlights = highlights,
    keymaps = {
      y = function(close_fn)
        close_fn()
        vim.schedule(function()
          perform_sync()
        end)
      end,
      n = function(close_fn)
        close_fn()
        vim.schedule(function()
          vim.notify('Sync cancelled - your local changes are preserved', vim.log.levels.INFO)
        end)
      end,
    },
  }
end

function M.sync_all()
  -- Get status
  local ok, status = pcall(sync.get_status)
  if not ok then
    vim.notify('Error getting status: ' .. status, vim.log.levels.ERROR)
    return
  end

  if vim.tbl_isempty(status) then
    vim.notify('No config files configured in manifest.json', vim.log.levels.WARN)
    return
  end

  -- Build file list
  local all_keys = vim.tbl_keys(status)
  table.sort(all_keys)

  local has_changes = false
  local files_to_sync = {}

  for _, key in ipairs(all_keys) do
    local info = status[key]
    if info.change_type ~= 'unchanged' then
      has_changes = true
      table.insert(files_to_sync, key)
    end
  end

  -- If nothing needs syncing, we're done
  if not has_changes then
    vim.notify('All config files in sync', vim.log.levels.INFO)
    return
  end

  -- Build window content
  local lines = {}
  local highlights = {}
  local file_line_map = {} -- Maps line numbers to file keys

  table.insert(lines, '')
  table.insert(lines, 'Config File Status:')
  table.insert(lines, '')

  for _, key in ipairs(all_keys) do
    local info = status[key]
    local change_type = info.change_type
    local formatted, hl = format_change_type(change_type)
    local override_indicator = info.used_override and ' [override]' or ''
    local line = '  ' .. formatted .. ' - ' .. key .. override_indicator

    table.insert(lines, line)
    table.insert(highlights, { group = hl, line = #lines - 1, col_start = 2, col_end = 3 })

    -- Track which files have changes for diff viewing
    if change_type ~= 'unchanged' then
      file_line_map[#lines - 1] = key
    end
  end

  table.insert(lines, '')
  table.insert(lines, '────────────────────────────────────────────────────────')
  table.insert(lines, '')
  table.insert(lines, '  Press [s] to sync all changes')
  table.insert(lines, '  Press [d] then navigate and [Enter] to view diff')
  table.insert(lines, '  Press [q] to close')
  table.insert(lines, '')

  -- Show floating window
  local diff_mode = false

  create_float_window {
    title = ' gravity.nvim - Sync ',
    lines = lines,
    highlights = highlights,
    keymaps = {
      s = function(close_fn)
        close_fn()
        vim.schedule(function()
          do_sync_operation(status, files_to_sync)
        end)
      end,
      d = function(close_fn, buf, win)
        diff_mode = true

        -- Update footer
        local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        new_lines[#new_lines - 3] = '  Navigate with [j]/[k] or arrow keys'
        new_lines[#new_lines - 2] = '  Press [Enter] on a changed file to view diff'
        new_lines[#new_lines - 1] = '  Press [q] to close'

        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)

        -- Reapply highlights after updating buffer
        local ns_id = vim.api.nvim_create_namespace('gravity_window')
        vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
        for _, hl in ipairs(highlights) do
          vim.api.nvim_buf_add_highlight(buf, ns_id, hl.group, hl.line, hl.col_start or 0, hl.col_end or -1)
        end

        vim.notify('Diff mode: Navigate and press Enter on a changed file', vim.log.levels.INFO)
      end,
      ['<CR>'] = function(close_fn, buf, win)
        if diff_mode then
          local cursor = vim.api.nvim_win_get_cursor(win)
          local line_num = cursor[1] - 1 -- 0-indexed
          local file_key = file_line_map[line_num]

          if file_key then
            close_fn()
            vim.schedule(function()
              M.diff { args = file_key }
            end)
          else
            vim.notify('No changed file on this line', vim.log.levels.WARN)
          end
        end
      end,
    },
  }
end

-- Show diff in floating window
local function show_diff_window(config_key, status, all_changed_files)
  local info = status[config_key]
  if not info then
    vim.notify('Config file not found in manifest: ' .. config_key, vim.log.levels.ERROR)
    return
  end

  local source_path = info.source_path
  local system_path = utils.expand_path(info.config.target)
  local source_label = info.used_override and 'override' or 'base'

  local lines = {}
  local highlights = {}

  table.insert(lines, '')
  table.insert(lines, 'File: ' .. config_key)
  table.insert(lines, 'Comparing: system vs ' .. source_label)
  table.insert(lines, '')

  if not utils.file_exists(source_path) then
    table.insert(lines, '✗ Source file not found: ' .. source_path)
    table.insert(highlights, { group = 'ErrorMsg', line = #lines - 1 })
  elseif not utils.file_exists(system_path) then
    table.insert(lines, '○ System file not found (will be created on sync)')
    table.insert(highlights, { group = 'Comment', line = #lines - 1 })
  else
    local diff = utils.show_diff(system_path, source_path)
    if not diff then
      table.insert(lines, SYMBOLS.success .. ' Files are identical')
      table.insert(highlights, { group = HIGHLIGHTS.success, line = #lines - 1, col_start = 0, col_end = 1 })
    else
      local diff_lines = vim.split(diff, '\n')
      for _, line in ipairs(diff_lines) do
        table.insert(lines, line)
        local line_idx = #lines - 1

        if line:match '^%-' then
          -- Removed lines (red)
          table.insert(highlights, { group = 'DiffDelete', line = line_idx })
        elseif line:match '^%+' then
          -- Added lines (green)
          table.insert(highlights, { group = 'DiffAdd', line = line_idx })
        elseif line:match '^@@' then
          -- Hunk headers (cyan)
          table.insert(highlights, { group = 'DiffChange', line = line_idx })
        end
      end
    end
  end

  table.insert(lines, '')
  table.insert(lines, '────────────────────────────────────────────────────────')
  table.insert(lines, '')

  -- Find current file index for navigation
  local current_idx = nil
  for i, key in ipairs(all_changed_files) do
    if key == config_key then
      current_idx = i
      break
    end
  end

  if current_idx and #all_changed_files > 1 then
    table.insert(lines, '  Press [n] for next file, [p] for previous file')
  end
  table.insert(lines, '  Press [s] to sync all changes')
  table.insert(lines, '  Press [q] to close')
  table.insert(lines, '')

  -- Build keymaps
  local keymaps = {
    s = function(close_fn)
      close_fn()
      vim.schedule(function()
        M.sync_all()
      end)
    end,
  }

  -- Add navigation if there are multiple files
  if current_idx and #all_changed_files > 1 then
    keymaps['n'] = function(close_fn)
      close_fn()
      local next_idx = current_idx + 1
      if next_idx > #all_changed_files then
        next_idx = 1 -- Wrap around
      end
      vim.schedule(function()
        show_diff_window(all_changed_files[next_idx], status, all_changed_files)
      end)
    end

    keymaps['p'] = function(close_fn)
      close_fn()
      local prev_idx = current_idx - 1
      if prev_idx < 1 then
        prev_idx = #all_changed_files -- Wrap around
      end
      vim.schedule(function()
        show_diff_window(all_changed_files[prev_idx], status, all_changed_files)
      end)
    end
  end

  create_float_window {
    title = ' gravity.nvim - Diff: ' .. config_key .. ' ',
    lines = lines,
    highlights = highlights,
    keymaps = keymaps,
  }
end

-- Command: :GravityDiff <file>
-- Show diff for a specific config file
function M.diff(args)
  local file_key = args.args

  -- Get status
  local ok, status = pcall(sync.get_status)
  if not ok then
    vim.notify('Error getting status: ' .. status, vim.log.levels.ERROR)
    return
  end

  -- Get all files with changes
  local files_with_changes = {}
  for key, info in pairs(status) do
    if info.change_type ~= 'unchanged' and info.change_type ~= 'missing_source' then
      table.insert(files_with_changes, key)
    end
  end

  if #files_with_changes == 0 then
    vim.notify('All config files in sync', vim.log.levels.INFO)
    return
  end

  table.sort(files_with_changes)

  -- If no file specified, use the first changed file
  if not file_key or file_key == '' then
    file_key = files_with_changes[1]
  end

  -- Validate file exists in status
  if not status[file_key] then
    vim.notify('Config file not found in manifest: ' .. file_key, vim.log.levels.ERROR)
    return
  end

  -- Show diff window
  show_diff_window(file_key, status, files_with_changes)
end

-- Command: :GravityTest
-- Run test suite and show results in floating window
function M.test()
  local config_dir = vim.fn.stdpath 'config'
  local test_script = config_dir .. '/tests/run_tests.sh'

  -- Check if test script exists
  if not utils.file_exists(test_script) then
    vim.notify('Test script not found: ' .. test_script, vim.log.levels.ERROR)
    return
  end

  -- Show loading window with spinner
  local spinner_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }
  local spinner_idx = 1
  local loading_lines = {
    '',
    'Running gravity.nvim test suite...',
    '',
    '  ' .. spinner_frames[1] .. ' Executing tests',
    '',
    '  Please wait...',
    '',
  }

  local loading_win = create_float_window {
    title = ' gravity.nvim - Testing ',
    lines = loading_lines,
    highlights = {
      { group = 'DiagnosticInfo', line = 3, col_start = 2, col_end = 3 },
    },
  }

  -- Animate spinner
  local spinner_timer = vim.loop.new_timer()
  spinner_timer:start(
    0,
    100,
    vim.schedule_wrap(function()
      if not vim.api.nvim_buf_is_valid(loading_win.buf) then
        spinner_timer:stop()
        return
      end

      spinner_idx = (spinner_idx % #spinner_frames) + 1
      loading_lines[4] = '  ' .. spinner_frames[spinner_idx] .. ' Executing tests'

      vim.api.nvim_buf_set_option(loading_win.buf, 'modifiable', true)
      vim.api.nvim_buf_set_lines(loading_win.buf, 0, -1, false, loading_lines)
      vim.api.nvim_buf_set_option(loading_win.buf, 'modifiable', false)

      -- Reapply highlights
      local ns_id = vim.api.nvim_create_namespace('gravity_window')
      vim.api.nvim_buf_clear_namespace(loading_win.buf, ns_id, 0, -1)
      vim.api.nvim_buf_add_highlight(loading_win.buf, ns_id, 'DiagnosticInfo', 3, 2, 3)
    end)
  )

  local start_time = vim.loop.now()
  local output = {}

  -- Run tests asynchronously
  vim.fn.jobstart({ 'bash', test_script }, {
    cwd = config_dir,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(output, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(output, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      -- Stop spinner
      spinner_timer:stop()
      spinner_timer:close()

      -- Ensure minimum 2 second delay
      local elapsed = vim.loop.now() - start_time
      local delay = math.max(0, 2000 - elapsed)

      vim.defer_fn(function()
        -- Close loading window
        if vim.api.nvim_win_is_valid(loading_win.win) then
          vim.api.nvim_win_close(loading_win.win, true)
        end

        -- Parse test output
        local lines = {}
        local highlights = {}
        local success_count = 0
        local fail_count = 0

        table.insert(lines, '')
        table.insert(lines, 'gravity.nvim Test Results')
        table.insert(lines, '')

        for _, line in ipairs(output) do
          -- Remove ANSI color codes for display
          local clean_line = line:gsub('\27%[[0-9;]*m', '')

          if clean_line:match 'Success.*||' then
            success_count = success_count + 1
            local test_name = clean_line:match '||%s*(.+)' or clean_line
            table.insert(lines, '  ✓ ' .. test_name)
            table.insert(highlights, { group = 'DiagnosticOk', line = #lines - 1, col_start = 2, col_end = 3 })
          elseif clean_line:match 'Fail.*||' then
            fail_count = fail_count + 1
            local test_name = clean_line:match '||%s*(.+)' or clean_line
            table.insert(lines, '  ✗ ' .. test_name)
            table.insert(highlights, { group = 'DiagnosticError', line = #lines - 1, col_start = 2, col_end = 3 })
          end
        end

        local total_tests = success_count + fail_count

        table.insert(lines, '')
        table.insert(lines, '────────────────────────────────────────────────────────')
        table.insert(lines, '')

        if fail_count == 0 and total_tests > 0 then
          table.insert(lines, '  ✓ All tests passed!')
          table.insert(highlights, { group = 'DiagnosticOk', line = #lines - 1, col_start = 2, col_end = 3 })
        elseif fail_count > 0 then
          table.insert(lines, '  ✗ Some tests failed')
          table.insert(highlights, { group = 'DiagnosticError', line = #lines - 1, col_start = 2, col_end = 3 })
        end

        table.insert(lines, '')
        table.insert(lines, string.format('  Total: %d tests (%d passed, %d failed)', total_tests, success_count, fail_count))
        if success_count > 0 then
          table.insert(highlights, { group = 'DiagnosticOk', line = #lines - 1 })
        end
        table.insert(lines, '  Press [q] to close')
        table.insert(lines, '')

        -- Show results window
        local title = fail_count > 0 and ' gravity.nvim - Tests Failed ✗ ' or ' gravity.nvim - Tests Passed ✓ '
        create_float_window {
          title = title,
          lines = lines,
          highlights = highlights,
        }
      end, delay)
    end,
  })
end

-- Setup function to register commands
function M.setup()
  -- Create user commands
  vim.api.nvim_create_user_command('GravityStatus', M.status, {
    desc = 'Show config file sync status',
  })

  vim.api.nvim_create_user_command('GravitySync', M.sync_all, {
    desc = 'Sync config files from repo to system',
  })

  vim.api.nvim_create_user_command('GS', M.sync_all, {
    desc = 'Alias for GravitySync',
  })

  vim.api.nvim_create_user_command('GravityDiff', M.diff, {
    nargs = 1,
    desc = 'Show diff for a specific config file',
    complete = function()
      -- Auto-complete with config file names from manifest
      local ok, manifest = pcall(manifest_lib.load)
      if not ok then
        return {}
      end
      local configs = manifest_lib.get_configs(manifest)
      return vim.tbl_keys(configs)
    end,
  })

  vim.api.nvim_create_user_command('GravityTest', M.test, {
    desc = 'Run gravity.nvim test suite',
  })

  -- Check for sync changes on startup
  vim.api.nvim_create_autocmd('VimEnter', {
    callback = function()
      vim.defer_fn(function()
        local ok, status = pcall(sync.get_status)
        if not ok then
          return -- Silently fail if manifest missing or error
        end

        -- Count files that need syncing
        local needs_sync = 0
        for _, info in pairs(status) do
          if info.change_type ~= 'unchanged' and info.change_type ~= 'missing_source' then
            needs_sync = needs_sync + 1
          end
        end

        -- Launch GravitySync if changes detected
        if needs_sync > 0 then
          M.sync_all()
        end
      end, 200) -- Slightly longer delay for UI stability
    end,
  })
end

return M
