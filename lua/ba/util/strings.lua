local M = {}

---@param value string|nil
---@return string|nil
function M.strip_wrapping_quotes(value)
  if not value or value == '' then
    return value
  end

  local first = value:sub(1, 1)
  local last = value:sub(-1)
  if (first == '"' and last == '"') or (first == "'" and last == "'") then
    return value:sub(2, -2)
  end

  return value
end

return M
