local M = {}

-- Get the config directory (where manifest files live)
local function get_config_dir()
  return vim.fn.stdpath 'config'
end

-- Read and parse a JSON file
local function read_json(filepath)
  local file = io.open(filepath, 'r')
  if not file then
    return nil
  end

  local content = file:read '*a'
  file:close()

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    error('Failed to parse JSON file: ' .. filepath)
  end

  return decoded
end

-- Deep merge two tables (overrides take precedence)
-- Arrays are replaced entirely, objects are merged recursively
local function deep_merge(base, overrides)
  if type(base) ~= 'table' or type(overrides) ~= 'table' then
    return overrides
  end

  local result = vim.deepcopy(base)

  for key, value in pairs(overrides) do
    -- Skip comment fields
    if not key:match '^_' then
      if type(value) == 'table' and type(result[key]) == 'table' then
        -- If both are tables and not arrays, merge recursively
        if vim.islist(value) then
          -- Arrays replace entirely
          result[key] = value
        else
          -- Objects merge recursively
          result[key] = deep_merge(result[key], value)
        end
      else
        -- Primitives or mismatched types replace
        result[key] = value
      end
    end
  end

  return result
end

-- Load and merge manifests
function M.load()
  local config_dir = get_config_dir()
  local base_path = config_dir .. '/manifest.json'
  local override_path = config_dir .. '/manifest.overrides.json'

  -- Load base manifest (required)
  local base = read_json(base_path)
  if not base then
    error('manifest.json not found at: ' .. base_path)
  end

  -- Validate base manifest has version
  if not base.version then
    error('manifest.json missing required "version" field')
  end

  -- Load overrides (optional)
  local overrides = read_json(override_path)

  -- If no overrides, return base
  if not overrides then
    return base
  end

  -- Validate override manifest has version
  if not overrides.version then
    error('manifest.overrides.json missing required "version" field')
  end

  -- Check version compatibility
  if base.version ~= overrides.version then
    error(
      string.format(
        'Manifest version mismatch!\n'
          .. '  Base: v%s, Overrides: v%s\n\n'
          .. '  The manifest format has changed. Update your manifest.overrides.json\n'
          .. '  to match the new v%s format.',
        base.version,
        overrides.version,
        base.version
      )
    )
  end

  -- Merge and return
  return deep_merge(base, overrides)
end

-- Get all config file configurations from manifest
function M.get_configs(manifest)
  return manifest.configs or {}
end

-- Get dependencies from manifest
function M.get_dependencies(manifest)
  return manifest.dependencies or {}
end

return M
