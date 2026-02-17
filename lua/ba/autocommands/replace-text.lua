local MAX_PROMPT_PREVIEW_CHARS = 80

-- Render a short, single-line preview for prompts (safe for long/sensitive selections).
local function prompt_preview(text)
  local s = tostring(text or '')
  s = s:gsub('\r\n', '\n')
  s = s:gsub('\r', '\n')
  s = s:gsub('\n', [[\n]])
  s = s:gsub('\t', [[\t]])
  s = s:gsub('%c', '?')
  s = vim.trim(s)
  if s == '' then
    return '[empty]'
  end

  if vim.fn.strchars(s) > MAX_PROMPT_PREVIEW_CHARS then
    s = vim.fn.strcharpart(s, 0, MAX_PROMPT_PREVIEW_CHARS - 3) .. '...'
  end

  return s:gsub('"', '\\"')
end

-- Replace word under cursor across the whole buffer, confirm each match.
vim.keymap.set('n', '<leader>rw', function()
  local word = vim.fn.expand '<cword>'
  if word == '' then
    return
  end

  vim.ui.input({
    prompt = ('Replace "%s" with: '):format(prompt_preview(word)),
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

-- Get text between two positions in the right "mode" (char/line).
local function region_text(pos1, pos2, regtype)
  if (pos1[2] or 0) < 1 or (pos2[2] or 0) < 1 then
    return ''
  end

  local ok, lines = pcall(vim.fn.getregion, pos1, pos2, { type = regtype })
  if not ok or type(lines) ~= 'table' then
    return ''
  end

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

  local prompt = ('Replace "%s" with: '):format(prompt_preview(needle))
  vim.ui.input({ prompt = prompt, default = '' }, function(repl)
    if repl == nil then
      return
    end

    local pat = pat_prefix .. esc_pat(needle)
    local rep = vim.fn.escape(repl, [[\/\&]])

    -- {range}s/{pat}/{rep}/gc
    vim.cmd(('%ss/%s/%s/gc'):format(range, pat, rep))
  end)
end

-- Replace selected text across the whole buffer, confirm each match.
vim.keymap.set('x', '<leader>rw', function()
  local mode = vim.fn.visualmode()
  if mode == '\22' then
    return
  end

  local regtype = (mode == 'V') and 'V' or 'v'
  local needle = region_text(vim.fn.getpos 'v', vim.fn.getpos '.', regtype)
  if needle == '' then
    needle = region_text(vim.fn.getpos "'<", vim.fn.getpos "'>", regtype)
  end
  if needle == '' then
    return
  end

  do_replace('%', [[\V]], needle)
end, { desc = 'Replace visual selection (confirm)' })

-- Operatorfunc: replace inside motion range (the text you target with g@{motion})
function _G.ReplaceOperator(optype)
  if optype == 'block' then
    return
  end

  local regtype = (optype == 'line') and 'V' or 'v'
  local start_pos = vim.fn.getpos "'["
  local end_pos = vim.fn.getpos "']"
  local needle = region_text(start_pos, end_pos, regtype)
  if needle == '' then
    return
  end

  -- Freeze the line range immediately (before the async input callback)
  local srow = start_pos[2]
  local erow = end_pos[2]
  if srow < 1 or erow < 1 then
    return
  end
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
