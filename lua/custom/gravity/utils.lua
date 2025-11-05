local M = {}

-- Expand path with ~ and environment variables
function M.expand_path(path)
  return vim.fn.expand(path)
end

-- Check if file exists
function M.file_exists(path)
  local expanded = M.expand_path(path)
  return vim.fn.filereadable(expanded) == 1
end

-- Read file contents
function M.read_file(path)
  local expanded = M.expand_path(path)
  local file = io.open(expanded, 'r')
  if not file then
    return nil
  end

  local content = file:read '*a'
  file:close()
  return content
end

-- Write file contents
function M.write_file(path, content)
  local expanded = M.expand_path(path)

  -- Create parent directory if needed
  local parent = vim.fn.fnamemodify(expanded, ':h')
  vim.fn.mkdir(parent, 'p')

  local file = io.open(expanded, 'w')
  if not file then
    error('Failed to write file: ' .. expanded)
  end

  file:write(content)
  file:close()
end

-- Compute SHA256 hash of file contents
function M.hash_file(path)
  local content = M.read_file(path)
  if not content then
    return nil
  end
  return vim.fn.sha256(content)
end

-- Compute SHA256 hash of a string
function M.hash_string(str)
  return vim.fn.sha256(str)
end

-- Create backup of a file with timestamp
function M.backup_file(path)
  local expanded = M.expand_path(path)
  if not M.file_exists(expanded) then
    return nil
  end

  local config_dir = vim.fn.stdpath 'config'
  local backup_dir = config_dir .. '/backups'
  vim.fn.mkdir(backup_dir, 'p')

  local timestamp = os.date '%Y-%m-%d_%H%M%S'
  local filename = vim.fn.fnamemodify(expanded, ':t')
  local backup_path = string.format('%s/%s.%s', backup_dir, filename, timestamp)

  local content = M.read_file(expanded)
  M.write_file(backup_path, content)

  return backup_path
end

-- Copy file from source to target
function M.copy_file(source, target)
  local content = M.read_file(source)
  if not content then
    error('Failed to read source file: ' .. source)
  end
  M.write_file(target, content)
end

-- Get file modification time
function M.get_mtime(path)
  local expanded = M.expand_path(path)
  if not M.file_exists(expanded) then
    return nil
  end
  return vim.fn.getftime(expanded)
end

-- Format timestamp for display
function M.format_time_ago(timestamp)
  if not timestamp then
    return 'never'
  end

  local now = os.time()
  local diff = os.difftime(now, timestamp)

  if diff < 60 then
    return 'just now'
  elseif diff < 3600 then
    local mins = math.floor(diff / 60)
    return mins .. ' minute' .. (mins == 1 and '' or 's') .. ' ago'
  elseif diff < 86400 then
    local hours = math.floor(diff / 3600)
    return hours .. ' hour' .. (hours == 1 and '' or 's') .. ' ago'
  else
    local days = math.floor(diff / 86400)
    return days .. ' day' .. (days == 1 and '' or 's') .. ' ago'
  end
end

-- Read JSON file
function M.read_json(path)
  local content = M.read_file(path)
  if not content then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    error('Failed to parse JSON file: ' .. path)
  end

  return decoded
end

-- Write JSON file
function M.write_json(path, data)
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    error('Failed to encode JSON data')
  end

  M.write_file(path, encoded)
end

-- Show diff between two files
function M.show_diff(file1, file2)
  local cmd = string.format('diff -u %s %s', vim.fn.shellescape(file1), vim.fn.shellescape(file2))
  local diff = vim.fn.system(cmd)

  -- diff returns empty if files are identical
  if vim.v.shell_error == 0 then
    return nil
  end

  return diff
end

return M
