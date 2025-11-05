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

-- Command: :GravityStatus
-- Shows which config files differ from repo (simple, non-interactive for scripts)
function M.status()
  print '\n=== Gravity Status ==='

  local ok, status = pcall(sync.get_status)
  if not ok then
    print('Error: ' .. status)
    return
  end

  if vim.tbl_isempty(status) then
    print 'No config files configured in manifest.json'
    return
  end

  print '\nConfig Files:'

  -- Sort by key for consistent display
  local keys = vim.tbl_keys(status)
  table.sort(keys)

  local has_changes = false

  for _, key in ipairs(keys) do
    local info = status[key]
    local change_type = info.change_type
    local formatted, hl = format_change_type(change_type)

    -- Highlight changes
    if change_type ~= 'unchanged' then
      has_changes = true
    end

    -- Show if using override
    local override_indicator = info.used_override and ' [override]' or ''
    cprint({
      { '  ' .. formatted .. ' ', hl },
      { key, 'Normal' },
      { override_indicator, 'Comment' },
    })
  end

  if not has_changes then
    cprint('\n' .. SYMBOLS.success .. ' All config files in sync', HIGHLIGHTS.success)
  else
    print '\nRun :GravitySync to review and apply changes'
  end

  print ''
end

-- Print colored diff output
local function print_colored_diff(diff)
  local lines = vim.split(diff, '\n')
  for _, line in ipairs(lines) do
    if line:match '^%-' then
      -- Removed lines (red)
      cprint(line, 'DiffDelete')
    elseif line:match '^%+' then
      -- Added lines (green)
      cprint(line, 'DiffAdd')
    elseif line:match '^@@' then
      -- Hunk headers (cyan)
      cprint(line, 'DiffChange')
    else
      -- Context lines
      print(line)
    end
  end
end

-- Show interactive diff for a file
local function show_diff_interactive(config_key, status)
  local info = status[config_key]
  if not info then
    print('File not found in status')
    return
  end

  local source_path = info.source_path
  local system_path = utils.expand_path(info.config.target)

  if not utils.file_exists(source_path) then
    print('Source file not found: ' .. source_path)
    return
  end

  if not utils.file_exists(system_path) then
    print('System file not found (will be created on sync)')
    return
  end

  local source_label = info.used_override and 'override' or 'base'
  cprint(string.format('\n=== Diff: %s (system vs %s) ===\n', config_key, source_label), 'Title')

  local diff = utils.show_diff(system_path, source_path)
  if not diff then
    cprint(SYMBOLS.success .. ' Files are identical', HIGHLIGHTS.success)
  else
    print_colored_diff(diff)
  end
end

-- Command: :GravitySync
-- Main entry point - shows full status and interactive menu
function M.sync_all()
  -- Variables need to persist across loop iterations
  local status
  local files_to_sync = {}

  -- Interactive menu loop
  while true do
    print '\n=== Gravity Sync ==='

    -- Get status
    local ok, status_result = pcall(sync.get_status)
    if not ok then
      print('Error: ' .. status_result)
      return
    end
    status = status_result

    if vim.tbl_isempty(status) then
      print 'No config files configured in manifest.json'
      return
    end

    -- Show all config files with their status
    print '\nConfig Files:'
    local all_keys = vim.tbl_keys(status)
    table.sort(all_keys)

    local has_changes = false
    files_to_sync = {}

    for _, key in ipairs(all_keys) do
      local info = status[key]
      local change_type = info.change_type
      local formatted, hl = format_change_type(change_type)

      if change_type ~= 'unchanged' then
        has_changes = true
        table.insert(files_to_sync, key)
      end

      -- Show if using override
      local override_indicator = info.used_override and ' [override]' or ''
      cprint({
        { '  ' .. formatted .. ' ', hl },
        { key, 'Normal' },
        { override_indicator, 'Comment' },
      })
    end

    -- If nothing needs syncing, we're done
    if not has_changes then
      cprint('\n' .. SYMBOLS.success .. ' All config files in sync', HIGHLIGHTS.success)
      return
    end

    -- Show interactive menu
    print '\nOptions:'
    for i, key in ipairs(files_to_sync) do
      cprint({
        { '  ', 'Normal' },
        { tostring(i), 'Number' },
        { '. Diff ', 'Normal' },
        { key, 'Identifier' },
      })
    end
    cprint({
      { '  ', 'Normal' },
      { 'y', 'DiagnosticOk' },
      { '. Yes, sync all changes', 'Normal' },
    })
    cprint({
      { '  ', 'Normal' },
      { 'q', 'DiagnosticWarn' },
      { '. Quit', 'Normal' },
    })
    print ''

    -- Get user input
    local response = vim.fn.input('Choice: ')
    print '' -- newline after input

    -- Handle response
    if response:lower() == 'y' then
      -- Proceed with sync
      break
    elseif response:lower() == 'q' or response == '' then
      print '\nCancelled'
      return
    else
      -- Try to parse as number for diff
      local num = tonumber(response)
      if num and num >= 1 and num <= #files_to_sync then
        local file_key = files_to_sync[num]
        show_diff_interactive(file_key, status)
        print '\nPress Enter to continue...'
        vim.fn.input ''
      else
        print '\nInvalid choice. Press Enter to continue...'
        vim.fn.input ''
      end
    end
  end

  -- Check for system changes that would be overwritten
  local system_changed_files = {}
  for _, key in ipairs(files_to_sync) do
    local info = status[key]
    if info.change_type == 'system_changed' then
      table.insert(system_changed_files, key)
    end
  end

  -- Warn about overwriting system changes
  if #system_changed_files > 0 then
    cprint('\n⚠ WARNING: The following files have local system changes:', HIGHLIGHTS.warning)
    for _, key in ipairs(system_changed_files) do
      cprint('  ' .. key, HIGHLIGHTS.warning)
    end
    cprint('\nSyncing will OVERWRITE your local changes!', 'ErrorMsg')
    print 'To preserve local changes:'
    print '  1. Copy file to configs.overrides/ directory'
    print '  2. Example: cp ~/.bashrc ~/.config/nvim/configs.overrides/.bashrc'
    print '\nProceed anyway? [y/N]: '
    local confirm = vim.fn.input ''
    print ''

    if confirm:lower() ~= 'y' then
      cprint('\nSync cancelled - your local changes are preserved', HIGHLIGHTS.success)
      return
    end
  end

  -- Perform sync
  print '\nSyncing...'
  local ok2, result = pcall(sync.sync_all, { quiet = false })

  if not ok2 then
    cprint('Error during sync: ' .. result, 'ErrorMsg')
    return
  end

  cprint(
    string.format(
      '\n%s Synced %d file%s, %d unchanged, %d skipped',
      SYMBOLS.success,
      result.synced,
      result.synced == 1 and '' or 's',
      result.unchanged,
      result.skipped
    ),
    HIGHLIGHTS.success
  )
  print ''
end

-- Command: :GravityDiff <file>
-- Show diff for a specific config file with interactive menu
function M.diff(args)
  local initial_file = args.args

  if not initial_file or initial_file == '' then
    -- No file specified, show all files with changes
    local ok, status = pcall(sync.get_status)
    if not ok then
      print('Error getting status: ' .. status)
      return
    end

    -- Get files with changes
    local files_with_changes = {}
    for key, info in pairs(status) do
      if info.change_type ~= 'unchanged' then
        table.insert(files_with_changes, key)
      end
    end

    if #files_with_changes == 0 then
      print(string.format('%s All config files in sync', SYMBOLS.success))
      return
    end

    table.sort(files_with_changes)

    -- Show interactive menu to select file
    cprint('\n=== Gravity Diff ===', 'Title')
    print '\nFiles with changes:'
    for i, key in ipairs(files_with_changes) do
      cprint({
        { '  ', 'Normal' },
        { tostring(i), 'Number' },
        { '. ', 'Normal' },
        { key, 'Identifier' },
      })
    end
    print '\nSelect file number or '
    cprint({
      { 'q', 'DiagnosticWarn' },
      { ' to quit', 'Normal' },
    })
    local response = vim.fn.input('Choice: ')
    print ''

    if response:lower() == 'q' or response == '' then
      return
    end

    local num = tonumber(response)
    if not num or num < 1 or num > #files_with_changes then
      print 'Invalid choice'
      return
    end

    initial_file = files_with_changes[num]
  end

  -- Interactive diff viewer loop
  local current_file = initial_file

  while true do
    -- Get status
    local ok, status = pcall(sync.get_status)
    if not ok then
      print('Error getting status: ' .. status)
      return
    end

    local info = status[current_file]
    if not info then
      print('Config file not found in manifest: ' .. current_file)
      return
    end

    local source_path = info.source_path
    local system_path = utils.expand_path(info.config.target)

    -- Show diff
    cprint(string.format('\n=== Diff: %s ===', current_file), 'Title')
    local source_label = info.used_override and 'override' or 'base'
    print(string.format('Comparing: system vs %s\n', source_label))

    if not utils.file_exists(source_path) then
      cprint('Source file not found: ' .. source_path, 'ErrorMsg')
    elseif not utils.file_exists(system_path) then
      cprint('System file not found (will be created on sync)', 'Comment')
    else
      local diff = utils.show_diff(system_path, source_path)
      if not diff then
        cprint(SYMBOLS.success .. ' Files are identical', HIGHLIGHTS.success)
      else
        print_colored_diff(diff)
      end
    end

    -- Get all available files
    local all_files = vim.tbl_keys(status)
    table.sort(all_files)

    -- Interactive menu
    print '\nOptions:'
    for i, key in ipairs(all_files) do
      if key ~= current_file then
        cprint({
          { '  ', 'Normal' },
          { tostring(i), 'Number' },
          { '. Diff ', 'Normal' },
          { key, 'Identifier' },
        })
      end
    end
    cprint({
      { '  ', 'Normal' },
      { 't', 'DiagnosticInfo' },
      { '. Show status', 'Normal' },
    })
    cprint({
      { '  ', 'Normal' },
      { 's', 'DiagnosticOk' },
      { '. Sync changes', 'Normal' },
    })
    cprint({
      { '  ', 'Normal' },
      { 'q', 'DiagnosticWarn' },
      { '. Quit', 'Normal' },
    })
    print ''

    local response = vim.fn.input('Choice: ')
    print ''

    if response:lower() == 'q' or response == '' then
      return
    elseif response:lower() == 't' then
      M.status()
      return
    elseif response:lower() == 's' then
      M.sync_all()
      return
    else
      local num = tonumber(response)
      if num and num >= 1 and num <= #all_files then
        current_file = all_files[num]
      else
        print '\nInvalid choice. Press Enter to continue...'
        vim.fn.input ''
      end
    end
  end
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
end

return M
