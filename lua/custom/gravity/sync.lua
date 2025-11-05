local utils = require 'custom.gravity.utils'
local manifest_lib = require 'custom.gravity.manifest'

local M = {}

-- Symbols and colors for output
local SYMBOLS = {
  warning = '⚠',
  syncing = '→',
}

local function cprint(text, hl_group)
  vim.api.nvim_echo({ { text, hl_group or 'Normal' } }, false, {})
end

-- Get path to sync state file
local function get_state_path()
  return vim.fn.stdpath 'config' .. '/.sync_state.json'
end

-- Get the source file path (check override first, fall back to base)
-- Returns: source_path, used_override
local function get_source_file(config_file)
  local config_dir = vim.fn.stdpath 'config'
  local base_path = config_dir .. '/' .. config_file.source

  -- Extract filename from source path
  local filename = vim.fn.fnamemodify(base_path, ':t')
  local override_path = config_dir .. '/configs.overrides/' .. filename

  -- Check if override exists
  if utils.file_exists(override_path) then
    return override_path, true
  end

  -- Fall back to base
  return base_path, false
end

-- Load sync state from .sync_state.json
function M.load_state()
  local state_path = get_state_path()
  local state = utils.read_json(state_path)

  if not state then
    -- Initialize empty state
    return {
      manifest_hash = '',
      dotfiles = {},
    }
  end

  return state
end

-- Save sync state to .sync_state.json
function M.save_state(state)
  local state_path = get_state_path()
  utils.write_json(state_path, state)
end

-- Detect change type for a config file (three-way detection)
-- Returns: "unchanged", "source_changed", "system_changed", "conflict", "missing_system", "missing_source", "out_of_sync"
function M.detect_change_type(config_key, config_file, manifest)
  local source_path, used_override = get_source_file(config_file)
  local system_path = utils.expand_path(config_file.target)

  -- Check if files exist
  local source_exists = utils.file_exists(source_path)
  local system_exists = utils.file_exists(system_path)

  if not source_exists then
    return 'missing_source'
  end

  if not system_exists then
    return 'missing_system'
  end

  -- Compute current hashes
  local source_hash = utils.hash_file(source_path)
  local system_hash = utils.hash_file(system_path)

  -- Load previous state
  local state = M.load_state()
  local prev = state.dotfiles[config_key] or {}

  -- If no previous state, check if files match
  if not prev.source_hash then
    if source_hash == system_hash then
      return 'unchanged'
    else
      -- File exists on system but differs from source (never synced)
      return 'out_of_sync'
    end
  end

  -- Detect what changed since last sync
  local source_changed = (source_hash ~= prev.source_hash)
  local system_changed = (system_hash ~= prev.system_hash)

  -- Check if files are currently identical
  if source_hash == system_hash then
    -- Files match now, but check if state is stale
    if source_changed or system_changed then
      -- Files are identical but state needs updating
      -- Sync will update state without copying files
      return 'source_changed' -- Safe to sync (no overwrite risk)
    else
      -- Files match and state is current
      return 'unchanged'
    end
  end

  -- Files differ - check three-way detection
  if source_changed and system_changed then
    return 'conflict'
  elseif source_changed then
    return 'source_changed'
  elseif system_changed then
    return 'system_changed'
  end

  return 'unchanged'
end

-- Get status for all config files
function M.get_status()
  local manifest = manifest_lib.load()
  local configs = manifest_lib.get_configs(manifest)
  local status = {}

  for key, config in pairs(configs) do
    local change_type = M.detect_change_type(key, config, manifest)
    local source_path, used_override = get_source_file(config)

    status[key] = {
      config = config,
      change_type = change_type,
      used_override = used_override,
      source_path = source_path,
    }
  end

  return status
end

-- Sync a single config file from source to system
function M.sync_file(config_key, config_file, manifest, opts)
  opts = opts or {}
  local source_path, used_override = get_source_file(config_file)
  local system_path = utils.expand_path(config_file.target)

  -- Create backup if system file exists
  if utils.file_exists(system_path) and not opts.no_backup then
    local backup_path = utils.backup_file(system_path)
    if backup_path and not opts.quiet then
      print('  Backed up to: ' .. backup_path)
    end
  end

  -- Copy file from source to system
  utils.copy_file(source_path, system_path)

  -- Update state
  local state = M.load_state()
  local source_hash = utils.hash_file(source_path)
  local system_hash = utils.hash_file(system_path)

  state.dotfiles[config_key] = {
    source_hash = source_hash,
    system_hash = system_hash,
    used_override = used_override,
    last_sync = os.date '!%Y-%m-%dT%H:%M:%SZ',
  }

  M.save_state(state)

  return true
end

-- Sync all config files that need syncing
function M.sync_all(opts)
  opts = opts or {}
  local manifest = manifest_lib.load()
  local status = M.get_status()

  local sync_count = 0
  local unchanged_count = 0
  local skipped_count = 0

  for key, info in pairs(status) do
    local change_type = info.change_type

    if change_type == 'unchanged' then
      unchanged_count = unchanged_count + 1
    elseif change_type == 'missing_source' then
      cprint(string.format('%s Skipping %s (missing source file)', SYMBOLS.warning, key), 'DiagnosticWarn')
      skipped_count = skipped_count + 1
    elseif change_type == 'system_changed' then
      if not opts.force then
        cprint(string.format('%s Skipping %s (system changed, use :GravityDiff to review)', SYMBOLS.warning, key), 'DiagnosticWarn')
        skipped_count = skipped_count + 1
      else
        M.sync_file(key, info.config, manifest, opts)
        sync_count = sync_count + 1
      end
    elseif change_type == 'conflict' then
      cprint(string.format('%s Conflict: %s (both source and system changed, use :GravityDiff to review)', SYMBOLS.warning, key), 'DiagnosticError')
      skipped_count = skipped_count + 1
    else
      -- source_changed, missing_system, out_of_sync
      if not opts.quiet then
        local override_note = info.used_override and ' (override)' or ''
        cprint(string.format('%s Syncing %s%s', SYMBOLS.syncing, key, override_note), 'DiagnosticInfo')
      end
      M.sync_file(key, info.config, manifest, opts)
      sync_count = sync_count + 1
    end
  end

  return {
    synced = sync_count,
    unchanged = unchanged_count,
    skipped = skipped_count,
  }
end

return M
