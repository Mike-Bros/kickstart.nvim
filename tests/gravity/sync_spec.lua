-- Tests for gravity.nvim sync functionality
-- Run with: nvim --headless -c "PlenaryBustedDirectory tests/gravity {minimal_init = 'tests/minimal_init.lua'}"

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
  return test_dir
end

local function cleanup_test_env(test_dir)
  vim.fn.delete(test_dir, 'rf')
end

local function write_test_file(path, content)
  local file = io.open(path, 'w')
  if file then
    file:write(content)
    file:close()
  end
end

local function read_test_file(path)
  local file = io.open(path, 'r')
  if file then
    local content = file:read('*all')
    file:close()
    return content
  end
  return nil
end

local function create_test_manifest(test_dir, configs)
  local manifest = {
    version = '1.0.0',
    configs = configs or {},
  }
  write_test_file(test_dir .. '/manifest.json', vim.json.encode(manifest))
end

describe('gravity.nvim sync', function()
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

    -- Mock home directory
    original_home = os.getenv('HOME')
    vim.env.HOME = test_dir .. '/home'
  end)

  after_each(function()
    -- Restore original functions
    vim.fn.stdpath = original_stdpath
    vim.env.HOME = original_home

    -- Cleanup test directory
    cleanup_test_env(test_dir)
  end)

  describe('detect_change_type', function()
    it('detects missing_system when file not on system', function()
      -- Setup: file in dotfiles/ but not in ~/
      write_test_file(test_dir .. '/configs/test.conf', 'content')
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      local change_type = sync.detect_change_type('test.conf', config, manifest)

      assert.equals('missing_system', change_type)
    end)

    it('detects missing_source when source file missing', function()
      -- Setup: file on system but not in dotfiles/
      write_test_file(test_dir .. '/home/test.conf', 'content')
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      local change_type = sync.detect_change_type('test.conf', config, manifest)

      assert.equals('missing_source', change_type)
    end)

    it('detects unchanged when files identical', function()
      -- Setup: identical files
      local content = 'test content'
      write_test_file(test_dir .. '/configs/test.conf', content)
      write_test_file(test_dir .. '/home/test.conf', content)
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      local change_type = sync.detect_change_type('test.conf', config, manifest)

      assert.equals('unchanged', change_type)
    end)

    it('detects out_of_sync when files differ (no previous state)', function()
      -- Setup: different files, no sync state
      write_test_file(test_dir .. '/configs/test.conf', 'source content')
      write_test_file(test_dir .. '/home/test.conf', 'system content')
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      local change_type = sync.detect_change_type('test.conf', config, manifest)

      assert.equals('out_of_sync', change_type)
    end)

    it('detects source_changed after source modification', function()
      -- Setup: sync state exists, source changed
      local original = 'original content'
      local modified = 'modified content'

      write_test_file(test_dir .. '/configs/test.conf', original)
      write_test_file(test_dir .. '/home/test.conf', original)
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      -- Sync to create state
      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      sync.sync_file('test.conf', config, manifest, { no_backup = true, quiet = true })

      -- Modify source
      write_test_file(test_dir .. '/configs/test.conf', modified)

      -- Check status
      local change_type = sync.detect_change_type('test.conf', config, manifest)
      assert.equals('source_changed', change_type)
    end)

    it('detects system_changed after system modification', function()
      -- Setup: sync state exists, system changed
      local original = 'original content'
      local modified = 'modified content'

      write_test_file(test_dir .. '/configs/test.conf', original)
      write_test_file(test_dir .. '/home/test.conf', original)
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      -- Sync to create state
      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      sync.sync_file('test.conf', config, manifest, { no_backup = true, quiet = true })

      -- Modify system file
      write_test_file(test_dir .. '/home/test.conf', modified)

      -- Check status
      local change_type = sync.detect_change_type('test.conf', config, manifest)
      assert.equals('system_changed', change_type)
    end)

    it('detects conflict when both source and system changed', function()
      -- Setup: sync state exists, both changed
      local original = 'original content'
      local source_mod = 'source modified'
      local system_mod = 'system modified'

      write_test_file(test_dir .. '/configs/test.conf', original)
      write_test_file(test_dir .. '/home/test.conf', original)
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      -- Sync to create state
      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      sync.sync_file('test.conf', config, manifest, { no_backup = true, quiet = true })

      -- Modify both
      write_test_file(test_dir .. '/configs/test.conf', source_mod)
      write_test_file(test_dir .. '/home/test.conf', system_mod)

      -- Check status
      local change_type = sync.detect_change_type('test.conf', config, manifest)
      assert.equals('conflict', change_type)
    end)
  end)

  describe('override precedence', function()
    it('uses base file when no override exists', function()
      -- Setup: only base file
      write_test_file(test_dir .. '/configs/test.conf', 'base content')
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      local manifest = manifest_lib.load()
      local status = sync.get_status()

      assert.is_false(status['test.conf'].used_override)
      assert.equals(test_dir .. '/configs/test.conf', status['test.conf'].source_path)
    end)

    it('uses override file when override exists', function()
      -- Setup: both base and override
      write_test_file(test_dir .. '/configs/test.conf', 'base content')
      write_test_file(test_dir .. '/configs.overrides/test.conf', 'override content')
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      local manifest = manifest_lib.load()
      local status = sync.get_status()

      assert.is_true(status['test.conf'].used_override)
      assert.equals(test_dir .. '/configs.overrides/test.conf', status['test.conf'].source_path)
    end)

    it('syncs override content to system', function()
      -- Setup: override with specific content
      local override_content = 'override content'
      write_test_file(test_dir .. '/configs/test.conf', 'base content')
      write_test_file(test_dir .. '/configs.overrides/test.conf', override_content)
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      -- Sync
      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      sync.sync_file('test.conf', config, manifest, { no_backup = true, quiet = true })

      -- Verify system file has override content
      local system_content = utils.read_file(test_dir .. '/home/test.conf')
      assert.equals(override_content, system_content)
    end)
  end)

  describe('state tracking', function()
    it('creates state file after first sync', function()
      -- Setup
      write_test_file(test_dir .. '/configs/test.conf', 'content')
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      -- Sync
      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      sync.sync_file('test.conf', config, manifest, { no_backup = true, quiet = true })

      -- Check state file exists
      local state_exists = utils.file_exists(test_dir .. '/.sync_state.json')
      assert.is_true(state_exists)
    end)

    it('tracks source and system hashes', function()
      -- Setup
      local content = 'test content'
      write_test_file(test_dir .. '/configs/test.conf', content)
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      -- Sync
      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      sync.sync_file('test.conf', config, manifest, { no_backup = true, quiet = true })

      -- Load state
      local state = sync.load_state()
      local expected_hash = utils.hash_string(content)

      assert.equals(expected_hash, state.dotfiles['test.conf'].source_hash)
      assert.equals(expected_hash, state.dotfiles['test.conf'].system_hash)
    end)

    it('records whether override was used', function()
      -- Setup with override
      write_test_file(test_dir .. '/configs/test.conf', 'base')
      write_test_file(test_dir .. '/configs.overrides/test.conf', 'override')
      create_test_manifest(test_dir, {
        ['test.conf'] = {
          source = 'configs/test.conf',
          target = test_dir .. '/home/test.conf',
        },
      })

      -- Sync
      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      sync.sync_file('test.conf', config, manifest, { no_backup = true, quiet = true })

      -- Check state
      local state = sync.load_state()
      assert.is_true(state.dotfiles['test.conf'].used_override)
    end)
  end)

  describe('force flag', function()
    it('should sync system_changed files when force=true', function()
      -- Setup
      write_test_file(test_dir .. '/configs/test.conf', 'original content')
      write_test_file(test_dir .. '/manifest.json', [[
{
  "version": "1.0.0",
  "configs": {
    "test.conf": {
      "source": "configs/test.conf",
      "target": "~/.test.conf"
    }
  }
}
]])

      -- Initial sync
      local manifest = manifest_lib.load()
      local config = manifest.configs['test.conf']
      sync.sync_file('test.conf', config, manifest, { no_backup = true, quiet = true })

      -- Verify initial sync
      local system_path = test_dir .. '/home/.test.conf'
      assert.is_true(utils.file_exists(system_path))
      assert.are.equal('original content', read_test_file(system_path))

      -- Modify system file (simulate local changes)
      write_test_file(system_path, 'locally modified content')

      -- Try sync_all without force (should skip)
      local result_no_force = sync.sync_all({ quiet = true })
      assert.are.equal(0, result_no_force.synced)
      assert.are.equal(1, result_no_force.skipped)

      -- Verify system file unchanged
      assert.are.equal('locally modified content', read_test_file(system_path))

      -- Try sync_all with force=true (should sync)
      local result_with_force = sync.sync_all({ quiet = true, force = true })
      assert.are.equal(1, result_with_force.synced)
      assert.are.equal(0, result_with_force.skipped)

      -- Verify system file was overwritten with source
      assert.are.equal('original content', read_test_file(system_path))
    end)
  end)
end)
