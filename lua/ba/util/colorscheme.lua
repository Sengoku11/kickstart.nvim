---@class BA.util.colorscheme
local M = {}

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

return M
