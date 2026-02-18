---@class BA.util.git
local M = {}

local aug = vim.api.nvim_create_augroup('GitQuit', { clear = true })

-- Close Fugitive / git buffers with `q`
vim.api.nvim_create_autocmd('FileType', {
  group = aug,
  pattern = { 'git', 'fugitive', 'fugitiveblame' },
  callback = function(ev)
    local fugitive_win = vim.api.nvim_get_current_win()

    vim.keymap.set('n', 'q', function()
      if vim.fn.winnr '#' > 0 then
        vim.cmd 'wincmd p'
        if vim.api.nvim_win_is_valid(fugitive_win) then
          pcall(vim.api.nvim_win_close, fugitive_win, true)
        end
      elseif vim.fn.bufnr '$' == 1 then
        vim.cmd 'quit'
      else
        vim.cmd 'bdelete'
      end
    end, { buffer = ev.buf, silent = true, desc = 'Quit Fugitive buffer' })
  end,
})

-- Quit gitsigns diff window with `q`
vim.api.nvim_create_autocmd('OptionSet', {
  group = aug,
  pattern = 'diff',
  callback = function(e)
    vim.keymap.set('n', 'q', function()
      local has_diff = vim.wo.diff
      local target_win
      if not has_diff then
        return 'q'
      end
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        local name = vim.api.nvim_buf_get_name(buf)
        if type(name) == 'string' and name:match '^gitsigns://' then
          target_win = win
          break
        end
      end
      if target_win then
        vim.schedule(function()
          vim.api.nvim_win_close(target_win, true)
        end)
        return ''
      end
      return 'q'
    end, { expr = true, silent = true, buffer = e.buf })
  end,
})

-- Diff current line's blame commit vs its parent for THIS file only,
-- handling root commits and renames inside that commit, in its own tabpage.
function M.diff_with_blame_commit()
  local file_abs = vim.api.nvim_buf_get_name(0)
  if file_abs == '' then
    vim.notify('No file name', vim.log.levels.WARN)
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(0)[1]

  -- Blame the exact line; we also want the 'filename' header for the path-at-commit.
  local blame = vim.fn.systemlist { 'git', 'blame', '--porcelain', '-L', lnum .. ',' .. lnum, '--', file_abs }
  if vim.v.shell_error ~= 0 or #blame == 0 then
    vim.notify('git blame failed', vim.log.levels.ERROR)
    return
  end

  -- 1st line: "<sha1> <orig_lineno> <lineno> <num_lines>"
  local sha = blame[1]:match '^([0-9a-f]+) '
  if not sha or sha == string.rep('0', 40) then
    vim.notify('Line not yet committed', vim.log.levels.INFO)
    return
  end

  -- Extract the 'filename' header from blame (path as it exists in that commit)
  local path_at_commit
  for _, line in ipairs(blame) do
    local v = line:match '^filename%s+(.+)$'
    if v then
      path_at_commit = v
      break
    end
  end
  if not path_at_commit then
    path_at_commit = vim.fn.fnamemodify(file_abs, ':.')
  end

  -- Resolve parent (first parent is fine for line-introducing commits)
  vim.fn.system { 'git', 'rev-parse', '-q', '--verify', sha .. '^' }
  local has_parent = (vim.v.shell_error == 0)
  local parent = has_parent and (sha .. '^') or '4b825dc642cb6eb9a060e54bf8d69288fbee4904' -- empty tree

  -- If the commit renamed this file, use the old path on the parent side.
  local ns = vim.fn.systemlist { 'git', 'diff-tree', '--no-commit-id', '--name-status', '-r', sha }
  local parent_path = path_at_commit
  if vim.v.shell_error == 0 then
    for _, l in ipairs(ns) do
      local status, oldp, newp = l:match '^(R%d+)%s+([^\t]+)%s+([^\t]+)$'
      if status and newp == path_at_commit then
        parent_path = oldp
        break
      end
    end
  end

  -- Fetch blobs for parent and commit
  local left = vim.fn.systemlist { 'git', 'show', parent .. ':' .. parent_path }
  local left_ok = (vim.v.shell_error == 0)
  local right = vim.fn.systemlist { 'git', 'show', sha .. ':' .. path_at_commit }
  local right_ok = (vim.v.shell_error == 0)

  if not left_ok then
    left = {}
  end
  if not right_ok then
    vim.notify('Could not read file from commit ' .. sha:sub(1, 12), vim.log.levels.ERROR)
    return
  end

  local ft = vim.bo.filetype

  -- Open in a fresh tab so closing returns you to exactly where you were.
  vim.cmd 'tab split'

  -- Left buffer (parent)
  local buf_left = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf_left, ('%s (parent:%s)'):format(vim.fn.fnamemodify(path_at_commit, ':t'), has_parent and parent or 'empty-tree'))
  vim.api.nvim_buf_set_lines(buf_left, 0, -1, false, left)
  vim.bo[buf_left].buftype = 'nofile'
  vim.bo[buf_left].bufhidden = 'wipe'
  vim.bo[buf_left].buflisted = false
  vim.bo[buf_left].modifiable = false
  vim.bo[buf_left].filetype = ft
  vim.b[buf_left].__blame_diff_scratch = true

  -- Right buffer (commit)
  local buf_right = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf_right, ('%s (%s)'):format(vim.fn.fnamemodify(path_at_commit, ':t'), sha:sub(1, 12)))
  vim.api.nvim_buf_set_lines(buf_right, 0, -1, false, right)
  vim.bo[buf_right].buftype = 'nofile'
  vim.bo[buf_right].bufhidden = 'wipe'
  vim.bo[buf_right].buflisted = false
  vim.bo[buf_right].modifiable = false
  vim.bo[buf_right].filetype = ft
  vim.b[buf_right].__blame_diff_scratch = true

  -- Display diff: left | right inside the tab
  vim.cmd 'vsplit'
  local win_right = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win_right, buf_right)
  vim.cmd 'wincmd h'
  local win_left = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win_left, buf_left)

  -- Turn on diff mode
  vim.bo[buf_left].modifiable = true
  vim.cmd 'diffthis'
  vim.bo[buf_left].modifiable = false
  vim.api.nvim_set_current_win(win_right)
  vim.bo[buf_right].modifiable = true
  vim.cmd 'diffthis'
  vim.bo[buf_right].modifiable = false
  vim.api.nvim_set_current_win(win_right)

  -- Local 'q' in this tab closes the whole tab (clean exit back to your work)
  -- save these near the top of your function:
  local orig_buf = vim.api.nvim_get_current_buf()
  local orig_win = vim.api.nvim_get_current_win()

  local function map_q(buf)
    vim.keymap.set('n', 'q', function()
      pcall(vim.cmd, 'diffoff!')
      -- wipe scratch buffers
      if vim.api.nvim_buf_is_valid(buf_left) then
        pcall(vim.api.nvim_buf_delete, buf_left, { force = true })
      end
      if vim.api.nvim_buf_is_valid(buf_right) then
        pcall(vim.api.nvim_buf_delete, buf_right, { force = true })
      end

      -- If we have multiple tabs, close this tab; otherwise just restore view.
      if vim.fn.tabpagenr '$' > 1 then
        pcall(vim.cmd, 'tabclose')
      else
        -- close windows if they still exist
        if vim.api.nvim_win_is_valid(win_left) then
          pcall(vim.api.nvim_win_close, win_left, true)
        end
        if vim.api.nvim_win_is_valid(win_right) then
          pcall(vim.api.nvim_win_close, win_right, true)
        end
        -- go back to your original buffer/window if still valid
        if vim.api.nvim_win_is_valid(orig_win) then
          pcall(vim.api.nvim_set_current_win, orig_win)
        end
        if vim.api.nvim_buf_is_valid(orig_buf) then
          pcall(vim.api.nvim_set_current_buf, orig_buf)
        end
      end
    end, { buffer = buf, nowait = true, silent = true, desc = 'Quit Diff (safe)' })
  end

  map_q(buf_left)
  map_q(buf_right)

  vim.notify(string.format('Diffing %s^ (%s) → %s (%s)', sha:sub(1, 12), parent_path, sha:sub(1, 12), path_at_commit), vim.log.levels.INFO)
end

return M
