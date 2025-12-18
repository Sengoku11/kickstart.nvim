-- Replace word under cursor across the whole buffer, confirm each match.
vim.keymap.set('n', '<leader>rw', function()
  local word = vim.fn.expand '<cword>'
  if word == '' then
    return
  end

  vim.ui.input({
    prompt = ('Replace "%s" with: '):format(word),
    default = '',
  }, function(repl)
    if repl == nil then
      return
    end

    -- \V = "very nomagic" (treat pattern mostly as literal); \< \> = word boundaries
    local pat = [[\V\<]] .. vim.fn.escape(word, [[\/\]]) .. [[\>]]
    -- escape replacement meta-chars (\ and &) and the delimiter (/)
    local rep = vim.fn.escape(repl, [[\/\&]])

    vim.cmd(('%s/%s/%s/gc'):format('%s', pat, rep))
  end)
end, { desc = 'Replace word under cursor (confirm)' })

-- Get the text covered by operator marks ('[ and ']) in the right "mode" (char/line)
local function region_text(from_mark, to_mark, regtype)
  local lines = vim.fn.getregion(vim.fn.getpos(from_mark), vim.fn.getpos(to_mark), { type = regtype })
  return vim.trim(table.concat(lines, '\n'))
end

-- Escape a literal pattern snippet and make newlines matchable inside :substitute
local function esc_pat(text)
  local s = vim.fn.escape(text, [[\/\]])
  return s:gsub('\n', [[\n]])
end

-- Prompt for replacement and run a range-limited substitute with confirm (`gc`)
local function do_replace(range, pat_prefix, needle)
  needle = vim.trim(needle or '')
  if needle == '' then
    return
  end

  vim.ui.input({ prompt = 'Replace with: ', default = '' }, function(repl)
    if repl == nil then
      return
    end

    local pat = pat_prefix .. esc_pat(needle)
    local rep = vim.fn.escape(repl, [[\/\&]])

    -- {range}s/{pat}/{rep}/gc
    vim.cmd(('%ss/%s/%s/gc'):format(range, pat, rep))
  end)
end

-- Operatorfunc: replace inside motion range (the text you target with g@{motion})
function _G.ReplaceOperator(optype)
  if optype == 'block' then
    return
  end

  local regtype = (optype == 'line') and 'V' or 'v'
  local needle = region_text("'[", "']", regtype)
  if needle == '' then
    return
  end

  -- Freeze the line range immediately (before the async input callback)
  local srow = vim.fn.getpos("'[")[2]
  local erow = vim.fn.getpos("']")[2]
  if srow > erow then
    srow, erow = erow, srow
  end

  do_replace(('%d,%d'):format(srow, erow), [[\V]], needle)
end

-- Usage: <leader>r then a motion (iw, ap, }, etc.)
vim.keymap.set('n', '<leader>r', function()
  vim.go.operatorfunc = 'v:lua.ReplaceOperator'
  return 'g@'
end, { expr = true, desc = 'Replace with motion (confirm, in-range)' })
