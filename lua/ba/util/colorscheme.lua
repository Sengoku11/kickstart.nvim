---@class BA.util.colorscheme
local M = {}
local session_state_file = vim.fn.stdpath('state') .. '/colorscheme-sessions.json'

---@param value unknown
---@return table<string, string>
local function normalize_state(value)
  local state = {}
  if type(value) ~= 'table' then
    return state
  end

  for key, name in pairs(value) do
    if type(key) == 'string' and type(name) == 'string' and name ~= '' then
      state[key] = name
    end
  end
  return state
end

---@param value unknown
---@return string
local function encode(value)
  if vim.json and vim.json.encode then
    return vim.json.encode(value)
  end
  return vim.fn.json_encode(value)
end

---@param value string
---@return unknown
local function decode(value)
  if vim.json and vim.json.decode then
    local ok, decoded = pcall(vim.json.decode, value)
    if ok then
      return decoded
    end
  end

  local ok, decoded = pcall(vim.fn.json_decode, value)
  if ok then
    return decoded
  end
  return nil
end

---@return table<string, string>
local function load_state()
  if vim.fn.filereadable(session_state_file) == 0 then
    return {}
  end

  local ok, lines = pcall(vim.fn.readfile, session_state_file)
  if not ok then
    return {}
  end

  local raw = table.concat(lines, '\n')
  if raw == '' then
    return {}
  end

  return normalize_state(decode(raw))
end

---@param state table<string, string>
---@return boolean
local function save_state(state)
  vim.fn.mkdir(vim.fn.fnamemodify(session_state_file, ':h'), 'p')
  local ok, err = pcall(vim.fn.writefile, { encode(state) }, session_state_file)
  if not ok then
    vim.notify(('Failed to save colorscheme session state: %s'):format(err), vim.log.levels.WARN)
    return false
  end
  return true
end

---@param path string?
---@return string?
local function normalize_path(path)
  if type(path) ~= 'string' or path == '' then
    return nil
  end
  return vim.fn.fnamemodify(path, ':p')
end

---@return string?
function M.session_file()
  local this_session = normalize_path(vim.v.this_session)
  if this_session then
    return this_session
  end

  local ok_persistence, persistence = pcall(require, 'persistence')
  if not ok_persistence or type(persistence.current) ~= 'function' then
    return nil
  end

  local ok_current, session = pcall(persistence.current)
  if not ok_current then
    return nil
  end

  return normalize_path(session)
end

---@param name string
---@param opts? {plugin?: string, notify?: boolean}
function M.apply(name, opts)
  opts = opts or {}
  if (vim.g.colors_name or '') == name then
    return true
  end

  if opts.plugin then
    local ok_lazy, lazy = pcall(require, 'lazy')
    if ok_lazy then
      pcall(lazy.load, { plugins = { opts.plugin } })
    end
  end

  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok and opts.notify ~= false then
    vim.notify(("Failed to load colorscheme '%s': %s"):format(name, err), vim.log.levels.WARN)
  end
  return ok
end

---@return boolean
function M.save_for_session()
  local session_file = M.session_file()
  local colors_name = vim.g.colors_name
  if not session_file or type(colors_name) ~= 'string' or colors_name == '' then
    return false
  end

  local state = load_state()
  state[session_file] = colors_name
  return save_state(state)
end

---@return boolean
function M.restore_for_session()
  local session_file = M.session_file()
  if not session_file then
    return false
  end

  local state = load_state()
  local colors_name = state[session_file]
  if type(colors_name) ~= 'string' or colors_name == '' then
    return false
  end

  return M.apply(colors_name, { notify = true })
end

function M.setup_session_persistence()
  local group = vim.api.nvim_create_augroup('ba-colorscheme-session', { clear = true })

  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'PersistenceSavePre',
    callback = function()
      M.save_for_session()
    end,
  })

  local function restore()
    vim.schedule(function()
      M.restore_for_session()
    end)
  end

  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'PersistenceLoadPost',
    callback = restore,
  })

  vim.api.nvim_create_autocmd('SessionLoadPost', {
    group = group,
    callback = restore,
  })
end

return M
