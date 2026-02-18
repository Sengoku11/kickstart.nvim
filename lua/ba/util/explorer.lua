local M = {}

-- NOTE: Why this utility exists:
-- Snacks.explorer does not support grouping empty directories.
-- In Java/Scala projects with deep package paths, that becomes noisy.
-- So <leader>e routes to Neo-tree for those project roots.

local default_neotree_project_markers = {
  '.mvn',
  'mvnw',
  'pom.xml',
  'build.gradle',
  'build.gradle.kts',
  'settings.gradle',
  'settings.gradle.kts',
  'gradlew',
  'build.sbt',
  'project/build.properties',
  'project/plugins.sbt',
  '.bloop',
  '.metals',
}

---@return string[]
function M.project_markers()
  local configured = vim.g.ba_neotree_project_markers
  if type(configured) == 'table' and #configured > 0 then
    return configured
  end
  return default_neotree_project_markers
end

---@param path string
---@return string|nil
function M.root(path)
  if not path or path == '' then
    return nil
  end
  return vim.fs.root(path, M.project_markers())
end

---@return boolean
function M.use_neotree_for_context()
  local file = vim.api.nvim_buf_get_name(0)
  if M.root(file) then
    return true
  end
  local cwd = (vim.uv and vim.uv.cwd and vim.uv.cwd()) or vim.fn.getcwd()
  return M.root(cwd) ~= nil
end

function M.open()
  if M.use_neotree_for_context() then
    local ok_cmd, cmd = pcall(require, 'neo-tree.command')
    if ok_cmd and type(cmd.execute) == 'function' then
      cmd.execute { toggle = true, source = 'filesystem' }
      return
    end
    local ok_vimcmd = pcall(function()
      vim.cmd 'Neotree toggle'
    end)
    if ok_vimcmd then
      return
    end
  end

  local ok_snacks, snacks = pcall(require, 'snacks')
  if ok_snacks and snacks and snacks.explorer then
    local ok_open = pcall(function()
      snacks.explorer()
    end)
    if ok_open then
      return
    end
  end
  vim.notify('[explorer] Neither neo-tree nor snacks explorer is available.', vim.log.levels.WARN)
end

return M
