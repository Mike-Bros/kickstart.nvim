-- Full integration test for gravity.nvim
-- Tests complete sync workflow with multiple configs in various states
-- Run with: nvim --headless -c "PlenaryBustedFile tests/gravity/integration_spec.lua"

local sync = require 'custom.gravity.sync'
local utils = require 'custom.gravity.utils'
local manifest_lib = require 'custom.gravity.manifest'

-- Test utilities
local function create_test_env()
  local test_dir = vim.fn.tempname()
  vim.fn.mkdir(test_dir, 'p')
  vim.fn.mkdir(test_dir .. '/configs', 'p')
  vim.fn.mkdir(test_dir .. '/configs.overrides', 'p')
  vim.fn.mkdir(test_dir .. '/home', 'p')
  vim.fn.mkdir(test_dir .. '/home/.config', 'p')
  vim.fn.mkdir(test_dir .. '/home/.config/nvim', 'p')
  return test_dir
end

local function cleanup_test_env(test_dir)
  vim.fn.delete(test_dir, 'rf')
end

local function write_test_file(path, content)
  -- Create parent directory if it doesn't exist
  local parent = vim.fn.fnamemodify(path, ':h')
  vim.fn.mkdir(parent, 'p')

  local file = io.open(path, 'w')
  if file then
    file:write(content)
    file:close()
  end
end

local function read_test_file(path)
  local file = io.open(path, 'r')
  if not file then
    return nil
  end
  local content = file:read '*a'
  file:close()
  return content
end

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function create_test_manifest(test_dir, configs)
  local manifest = {
    version = '1.0.0',
    configs = configs or {},
  }
  write_test_file(test_dir .. '/manifest.json', vim.json.encode(manifest))
end

describe('gravity.nvim full integration', function()
  local test_dir
  local original_stdpath
  local original_home

  before_each(function()
    -- Create test environment
    test_dir = create_test_env()

    -- Mock vim.fn.stdpath to return test directory
    original_stdpath = vim.fn.stdpath
    vim.fn.stdpath = function(what)
      if what == 'config' then
        return test_dir
      end
      return original_stdpath(what)
    end

    -- Mock HOME environment variable
    original_home = os.getenv 'HOME'
    vim.env.HOME = test_dir .. '/home'
  end)

  after_each(function()
    -- Restore mocks
    vim.fn.stdpath = original_stdpath
    vim.env.HOME = original_home

    -- Clean up test environment
    cleanup_test_env(test_dir)
  end)

  it('syncs multiple configs in all states to various locations', function()
    -- ============================================================
    -- SETUP: Create configs in every possible state
    -- ============================================================
    -- Using test-specific filenames that would never conflict with real configs

    -- 1. missing_system: New file that doesn't exist on system yet
    write_test_file(test_dir .. '/configs/test-shell.conf', '# Test shell config from repo\ntest_alias="test"')

    -- 2. unchanged: File already synced and identical
    local unchanged_content = '# Test init config\ntest_value="unchanged"'
    write_test_file(test_dir .. '/configs/test-init.conf', unchanged_content)
    write_test_file(test_dir .. '/home/.test-config/test-init.conf', unchanged_content)

    -- 3. missing_system + needs directory creation: New file in non-existent subdirectory
    write_test_file(test_dir .. '/configs/test-app.json', '{"test_app":"gravity","test_version":1}')

    -- 4. source_changed: Repo file was updated since last sync
    local git_old = '[test]\nname = Old Test\nemail = old@test.test'
    local git_new = '[test]\nname = New Test\nemail = new@test.test'
    write_test_file(test_dir .. '/configs/test-git.conf', git_new)
    write_test_file(test_dir .. '/home/test-git.conf', git_old) -- System has old version

    -- 5. system_changed: User edited system file since last sync
    local tmux_original = 'test_prefix=ctrl-a'
    local tmux_system_edit = 'test_prefix=ctrl-b\n# Test comment added by user'
    write_test_file(test_dir .. '/configs/test-tmux.conf', tmux_original)
    write_test_file(test_dir .. '/home/test-tmux.conf', tmux_system_edit)

    -- 6. conflict: Both repo and system changed since last sync
    local settings_original = '{"test_theme":"light"}'
    local settings_repo = '{"test_theme":"dark","test_font":12}'
    local settings_system = '{"test_theme":"auto","test_editor":"vim"}'
    write_test_file(test_dir .. '/configs/test-settings.json', settings_repo)
    vim.fn.mkdir(test_dir .. '/home/.test-app/test-user', 'p')
    write_test_file(test_dir .. '/home/.test-app/test-user/test-settings.json', settings_system)

    -- 7. out_of_sync: File exists on system but was never synced (no state)
    local vim_repo = '" Test vim config from repo\nset test_number'
    local vim_system = '" Different test vim config\nset test_nonumber'
    write_test_file(test_dir .. '/configs/test-vim.conf', vim_repo)
    write_test_file(test_dir .. '/home/test-vim.conf', vim_system)

    -- 8. With override: Use override file instead of base
    write_test_file(test_dir .. '/configs/test-override.conf', 'test base content')
    write_test_file(test_dir .. '/configs.overrides/test-override.conf', 'test override content')

    -- 9. missing_source: System file mapped but source doesn't exist (should skip)
    -- (Don't create source file, only system file)
    write_test_file(test_dir .. '/home/test-missing.conf', 'test orphaned config')

    -- ============================================================
    -- SETUP: Create manifest mapping all configs
    -- ============================================================

    create_test_manifest(test_dir, {
      ['test-shell.conf'] = {
        source = 'configs/test-shell.conf',
        target = '~/test-shell.conf',
      },
      ['test-init.conf'] = {
        source = 'configs/test-init.conf',
        target = '~/.test-config/test-init.conf',
      },
      ['test-app.json'] = {
        source = 'configs/test-app.json',
        target = '~/.test-local/share/testapp/test-app.json',
      },
      ['test-git.conf'] = {
        source = 'configs/test-git.conf',
        target = '~/test-git.conf',
      },
      ['test-tmux.conf'] = {
        source = 'configs/test-tmux.conf',
        target = '~/test-tmux.conf',
      },
      ['test-settings.json'] = {
        source = 'configs/test-settings.json',
        target = '~/.test-app/test-user/test-settings.json',
      },
      ['test-vim.conf'] = {
        source = 'configs/test-vim.conf',
        target = '~/test-vim.conf',
      },
      ['test-override.conf'] = {
        source = 'configs/test-override.conf',
        target = '~/test-override.conf',
      },
      ['test-missing.conf'] = {
        source = 'configs/test-missing.conf',
        target = '~/test-missing.conf',
      },
    })

    -- ============================================================
    -- SETUP: Create previous sync state for some files
    -- ============================================================

    -- For unchanged file: Record that it was synced
    local state = {
      manifest_hash = '',
      dotfiles = {
        ['test-init.conf'] = {
          source_hash = utils.hash_file(test_dir .. '/configs/test-init.conf'),
          system_hash = utils.hash_file(test_dir .. '/home/.test-config/test-init.conf'),
          used_override = false,
          last_sync = '2024-01-01T00:00:00Z',
        },
      },
    }

    -- For source_changed: Record old state so we can detect change
    state.dotfiles['test-git.conf'] = {
      source_hash = vim.fn.sha256(git_old), -- Old hash
      system_hash = vim.fn.sha256(git_old),
      used_override = false,
      last_sync = '2024-01-01T00:00:00Z',
    }

    -- For system_changed: Record original state
    state.dotfiles['test-tmux.conf'] = {
      source_hash = vim.fn.sha256(tmux_original),
      system_hash = vim.fn.sha256(tmux_original), -- System was same at last sync
      used_override = false,
      last_sync = '2024-01-01T00:00:00Z',
    }

    -- For conflict: Record original state (both have changed since)
    state.dotfiles['test-settings.json'] = {
      source_hash = vim.fn.sha256(settings_original),
      system_hash = vim.fn.sha256(settings_original),
      used_override = false,
      last_sync = '2024-01-01T00:00:00Z',
    }

    sync.save_state(state)

    -- ============================================================
    -- TEST: Verify status detection before sync
    -- ============================================================

    local status = sync.get_status()

    assert.equals('missing_system', status['test-shell.conf'].change_type)
    assert.equals('unchanged', status['test-init.conf'].change_type)
    assert.equals('missing_system', status['test-app.json'].change_type)
    assert.equals('source_changed', status['test-git.conf'].change_type)
    assert.equals('system_changed', status['test-tmux.conf'].change_type)
    assert.equals('conflict', status['test-settings.json'].change_type)
    assert.equals('out_of_sync', status['test-vim.conf'].change_type)
    assert.equals('missing_system', status['test-override.conf'].change_type)
    assert.is_true(status['test-override.conf'].used_override) -- Should detect override
    assert.equals('missing_source', status['test-missing.conf'].change_type)

    -- ============================================================
    -- ACTION: Perform sync_all()
    -- ============================================================

    local result = sync.sync_all({ quiet = true, force = true }) -- force=true to overwrite system_changed

    -- ============================================================
    -- VERIFY: Check sync results summary
    -- ============================================================

    -- Should sync: missing_system (3), source_changed (1), system_changed (1), out_of_sync (1)
    -- Should skip: unchanged (1), conflict (1), missing_source (1)
    assert.equals(6, result.synced) -- test-shell, test-app, test-git, test-tmux, test-vim, test-override
    assert.equals(1, result.unchanged) -- test-init
    assert.equals(2, result.skipped) -- test-settings (conflict), test-missing (missing_source)

    -- ============================================================
    -- VERIFY: Check all files are in correct locations with correct content
    -- ============================================================

    -- 1. test-shell.conf: Should be created in home directory
    assert.is_true(file_exists(test_dir .. '/home/test-shell.conf'))
    assert.equals(
      '# Test shell config from repo\ntest_alias="test"',
      read_test_file(test_dir .. '/home/test-shell.conf')
    )

    -- 2. test-init.conf: Should be unchanged (already synced)
    assert.equals(
      unchanged_content,
      read_test_file(test_dir .. '/home/.test-config/test-init.conf')
    )

    -- 3. test-app.json: Should be created with parent directories
    assert.is_true(file_exists(test_dir .. '/home/.test-local/share/testapp/test-app.json'))
    assert.equals(
      '{"test_app":"gravity","test_version":1}',
      read_test_file(test_dir .. '/home/.test-local/share/testapp/test-app.json')
    )

    -- 4. test-git.conf: Should be updated with new content from repo
    assert.equals(
      git_new,
      read_test_file(test_dir .. '/home/test-git.conf')
    )

    -- 5. test-tmux.conf: Should be overwritten with repo version (force=true)
    assert.equals(
      tmux_original,
      read_test_file(test_dir .. '/home/test-tmux.conf')
    )

    -- 6. test-settings.json: Should NOT be changed (conflict, not forced)
    -- Actually with force=true it should have been skipped due to conflict
    assert.equals(
      settings_system,
      read_test_file(test_dir .. '/home/.test-app/test-user/test-settings.json')
    )

    -- 7. test-vim.conf: Should be overwritten with repo version
    assert.equals(
      vim_repo,
      read_test_file(test_dir .. '/home/test-vim.conf')
    )

    -- 8. test-override.conf: Should use override content
    assert.equals(
      'test override content',
      read_test_file(test_dir .. '/home/test-override.conf')
    )

    -- 9. test-missing.conf: Should remain unchanged (source missing)
    assert.equals(
      'test orphaned config',
      read_test_file(test_dir .. '/home/test-missing.conf')
    )

    -- ============================================================
    -- VERIFY: State file was updated correctly
    -- ============================================================

    local new_state = sync.load_state()

    -- All synced files should have updated state
    assert.is_not_nil(new_state.dotfiles['test-shell.conf'])
    assert.is_not_nil(new_state.dotfiles['test-app.json'])
    assert.is_not_nil(new_state.dotfiles['test-git.conf'])
    assert.is_not_nil(new_state.dotfiles['test-tmux.conf'])
    assert.is_not_nil(new_state.dotfiles['test-vim.conf'])
    assert.is_not_nil(new_state.dotfiles['test-override.conf'])

    -- Verify test-git.conf hashes were updated to new values
    local new_git_hash = vim.fn.sha256(git_new)
    assert.equals(new_git_hash, new_state.dotfiles['test-git.conf'].source_hash)
    assert.equals(new_git_hash, new_state.dotfiles['test-git.conf'].system_hash)

    -- Verify override flag was recorded
    assert.is_true(new_state.dotfiles['test-override.conf'].used_override)
    assert.is_false(new_state.dotfiles['test-shell.conf'].used_override)

    -- ============================================================
    -- VERIFY: Backups were created for overwritten files
    -- ============================================================

    local backup_dir = test_dir .. '/backups'
    assert.is_true(vim.fn.isdirectory(backup_dir) == 1)

    -- Should have backups for files that were overwritten
    local backups = vim.fn.readdir(backup_dir)
    -- test-git, test-tmux, test-vim should have backups
    local has_git_backup = false
    local has_tmux_backup = false
    local has_vim_backup = false

    for _, backup_file in ipairs(backups) do
      if backup_file:match 'test%-git' then
        has_git_backup = true
      end
      if backup_file:match 'test%-tmux' then
        has_tmux_backup = true
      end
      if backup_file:match 'test%-vim' then
        has_vim_backup = true
      end
    end

    assert.is_true(has_git_backup)
    assert.is_true(has_tmux_backup)
    assert.is_true(has_vim_backup)

    -- ============================================================
    -- FINAL VERIFICATION: Run status again, should mostly be unchanged
    -- ============================================================

    local final_status = sync.get_status()

    assert.equals('unchanged', final_status['test-shell.conf'].change_type)
    assert.equals('unchanged', final_status['test-init.conf'].change_type)
    assert.equals('unchanged', final_status['test-app.json'].change_type)
    assert.equals('unchanged', final_status['test-git.conf'].change_type)
    assert.equals('unchanged', final_status['test-tmux.conf'].change_type)
    assert.equals('conflict', final_status['test-settings.json'].change_type) -- Still a conflict
    assert.equals('unchanged', final_status['test-vim.conf'].change_type)
    assert.equals('unchanged', final_status['test-override.conf'].change_type)
    assert.equals('missing_source', final_status['test-missing.conf'].change_type)
  end)
end)
