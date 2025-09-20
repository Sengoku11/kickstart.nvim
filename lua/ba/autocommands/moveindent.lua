-- This file is automatically loaded by ba.autocommands.init.

-- Allows to move lines up and down.
vim.api.nvim_create_autocmd('UIEnter', {
  once = true,
  callback = function()
    if #vim.api.nvim_list_uis() == 0 then
      return
    end

    -- ---- helpers (unchanged) ----
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

    local function is_visual_mode()
      return vim.fn.mode():match '[vV\22]' ~= nil
    end

    -- ---- fixed mover ----
    local function move_line(delta, visual)
      local last = vim.fn.line '$'

      if visual then
        -- Current selection (1-based)
        local s = vim.fn.getpos("'<")[2]
        local e = vim.fn.getpos("'>")[2]
        if s > e then
          s, e = e, s
        end

        -- Clamp shift so we don't run off the buffer
        local max_down = last - e
        local max_up = -(s - 1)
        local shift = delta
        if shift > max_down then
          shift = max_down
        end
        if shift < max_up then
          shift = max_up
        end
        if shift == 0 then
          return
        end

        -- Use absolute :move targets to dodge edge cases
        local cmd
        if shift > 0 then
          -- place range after line (e + shift)
          cmd = string.format(':%d,%dmove %d', s, e, e + shift)
        else
          -- place range above start: after (s + shift - 1)
          cmd = string.format(':%d,%dmove %d', s, e, s + shift - 1)
        end
        vim.cmd(cmd)

        -- Recompute new selection bounds and align
        local ns, ne = s + shift, e + shift
        align_range_to_prev(ns, ne)

        -- Reselect the moved block without using marks
        vim.fn.setpos("'<", { 0, ns, 1, 0 })
        vim.fn.setpos("'>", { 0, ne, 1, 0 })
        vim.cmd 'normal! gv'
      else
        -- Normal-mode single-line move
        local cur = vim.api.nvim_win_get_cursor(0) -- {row, col}
        local row, col = cur[1], cur[2]

        local max_down = last - row
        local max_up = -(row - 1)
        local shift = delta
        if shift > max_down then
          shift = max_down
        end
        if shift < max_up then
          shift = max_up
        end
        if shift == 0 then
          return
        end

        if shift > 0 then
          vim.cmd('move .+' .. shift)
        else
          -- For moving up by |shift|, the canonical form is .-(|shift|+1)
          vim.cmd('move .-' .. (-shift + 1))
        end

        local new_row = row + shift
        -- restore cursor without marks; clamp column to new line length
        local new_line = vim.fn.getline(new_row)
        local new_col = math.min(col, #new_line)
        vim.api.nvim_win_set_cursor(0, { new_row, new_col })

        align_line_to_prev(new_row)
      end
    end

    local function move_up()
      move_line(-1, is_visual_mode())
    end
    local function move_down()
      move_line(1, is_visual_mode())
    end

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

    -- ---- keymaps  ----
    local map, base = vim.keymap.set, { noremap = true, silent = true }
    map({ 'n', 'v' }, '<A-Up>', move_up, vim.tbl_extend('force', base, { desc = 'Move up & align' }))
    map({ 'n', 'v' }, '<A-Down>', move_down, vim.tbl_extend('force', base, { desc = 'Move down & align' }))
    map({ 'n', 'v' }, '<A-k>', move_up, vim.tbl_extend('force', base, { desc = 'Move up & align (Alt-k)' }))
    map({ 'n', 'v' }, '<A-j>', move_down, vim.tbl_extend('force', base, { desc = 'Move down & align (Alt-j)' }))

    map('i', '<A-Up>', wrap_ins(move_up), base)
    map('i', '<A-Down>', wrap_ins(move_down), base)
    map('i', '<A-k>', wrap_ins(move_up), base)
    map('i', '<A-j>', wrap_ins(move_down), base)
  end,
})
