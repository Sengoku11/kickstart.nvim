-- after/moveindent/moveindent.lua
-- Move lines/blocks up & down and align indentation to context above.
-- Also includes "paste without clobbering yank" mappings.

-- ---- indent behavior: keep file's style predictable ----
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.copyindent = true
vim.opt.preserveindent = true

-- ---- helpers ----
local function prev_indent_str(lnum)
  local prev = vim.fn.prevnonblank(lnum - 1)
  if prev == 0 then
    return nil
  end
  return (vim.fn.getline(prev):match '^%s*' or '')
end

local function align_line_to_prev(lnum)
  local indent = prev_indent_str(lnum)
  if not indent then
    return
  end
  local line = vim.fn.getline(lnum)
  local content = line:gsub('^%s*', '', 1)
  vim.fn.setline(lnum, indent .. content)
end

local function align_range_to_prev(sline, eline)
  if sline > eline then
    sline, eline = eline, sline
  end
  for l = sline, eline do
    align_line_to_prev(l)
  end
end

local function move_line(delta, visual)
  if visual then
    local s = vim.fn.getpos("'<")[2]
    local e = vim.fn.getpos("'>")[2]
    if delta > 0 then
      vim.cmd(":'<,'>move '>+" .. delta)
    else
      vim.cmd(":'<,'>move '<-" .. -delta)
    end
    vim.cmd 'normal! gv'
    -- selection moved; recompute range and align
    s = vim.fn.getpos("'<")[2]
    e = vim.fn.getpos("'>")[2]
    align_range_to_prev(s, e)
    vim.cmd 'normal! gv'
  else
    vim.cmd 'normal! mz'
    if delta > 0 then
      vim.cmd('move .+' .. delta)
    else
      vim.cmd('move .-' .. (-delta + 1))
    end
    align_line_to_prev(vim.api.nvim_win_get_cursor(0)[1])
    vim.cmd 'normal! `z'
  end
end

local function move_up()
  move_line(-1, vim.fn.mode():match '[vV\22]' ~= nil)
end
local function move_down()
  move_line(1, vim.fn.mode():match '[vV\22]' ~= nil)
end

-- insert-mode wrapper so you return to insert at same spot
local function wrap_ins(fn)
  return function()
    if vim.fn.mode() == 'i' then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true)
      fn()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('gi', true, false, true), 'n', true)
    else
      fn()
    end
  end
end

-- ---- keymaps ----
local map, opts = vim.keymap.set, { noremap = true, silent = true, desc = 'Move line/block and align indent' }

map({ 'n', 'v' }, '<A-Up>', move_up, opts)
map({ 'n', 'v' }, '<A-Down>', move_down, opts)
map({ 'n', 'v' }, '<A-k>', move_up, opts) -- fallback if Alt+Arrows aren't sent
map({ 'n', 'v' }, '<A-j>', move_down, opts)

map('i', '<A-Up>', wrap_ins(move_up), opts)
map('i', '<A-Down>', wrap_ins(move_down), opts)
map('i', '<A-k>', wrap_ins(move_up), opts)
map('i', '<A-j>', wrap_ins(move_down), opts)
