-- Commands for formatting, cleaning, and sorting structured list lines.

local M = {}

local roman_steps = {
  { 1000, 'M' },
  { 900, 'CM' },
  { 500, 'D' },
  { 400, 'CD' },
  { 100, 'C' },
  { 90, 'XC' },
  { 50, 'L' },
  { 40, 'XL' },
  { 10, 'X' },
  { 9, 'IX' },
  { 5, 'V' },
  { 4, 'IV' },
  { 1, 'I' },
}

local roman_values = {
  I = 1,
  V = 5,
  X = 10,
  L = 50,
  C = 100,
  D = 500,
  M = 1000,
}

local function int_to_roman(value)
  value = tonumber(value)
  if not value or value < 1 then
    return nil
  end

  value = math.floor(value)
  local parts = {}

  for _, step in ipairs(roman_steps) do
    local number, marker = step[1], step[2]
    while value >= number do
      parts[#parts + 1] = marker
      value = value - number
    end
  end

  return table.concat(parts)
end

local function roman_to_int(text)
  if type(text) ~= 'string' or text == '' then
    return nil
  end

  local total = 0
  local previous = 0
  local upper = text:upper()

  for index = #upper, 1, -1 do
    local value = roman_values[upper:sub(index, index)]
    if not value then
      return nil
    end

    if value < previous then
      total = total - value
    else
      total = total + value
      previous = value
    end
  end

  return total
end

local function int_to_alpha(value, upper)
  value = tonumber(value)
  if not value or value < 1 then
    return nil
  end

  value = math.floor(value)
  local base = upper and 65 or 97
  local parts = {}

  while value > 0 do
    value = value - 1
    table.insert(parts, 1, string.char(base + (value % 26)))
    value = math.floor(value / 26)
  end

  return table.concat(parts)
end

local function alpha_to_int(text)
  if type(text) ~= 'string' or not text:match '^[A-Za-z]+$' then
    return nil
  end

  local total = 0
  local upper = text:upper()

  for index = 1, #upper do
    total = total * 26 + upper:byte(index) - 64
  end

  return total
end

local function normalize_range(first, last)
  first = tonumber(first) or vim.fn.line '.'
  last = tonumber(last) or first

  if first > last then
    first, last = last, first
  end

  local line_count = vim.api.nvim_buf_line_count(0)
  first = math.max(1, math.min(first, line_count))
  last = math.max(1, math.min(last, line_count))

  return first, last
end

local function line_indent(line)
  return line:match '^%s*' or ''
end

local function with_comment_spacing(indent, marker, rest)
  local first = rest:sub(1, 1)
  if first ~= '' and first:match '%s' then
    return indent .. marker .. first, rest:sub(2), indent .. marker
  end

  if rest ~= '' then
    return indent .. marker .. ' ', rest, indent .. marker
  end

  return indent .. marker, rest, indent .. marker
end

local function line_comment_marker()
  local commentstring = vim.bo.commentstring or ''
  local marker, suffix = commentstring:match '^(.*)%%s(.*)$'
  if not marker or marker == '' or vim.trim(suffix) ~= '' then
    return nil
  end

  local marker_key = marker:gsub('%s+$', '')
  if marker_key == '' then
    return nil
  end

  return marker, marker_key
end

local function fallback_comment_markers(marker)
  if marker == '//' then
    return { '///', '//!', '//' }
  end

  return { marker }
end

local function commentstring_context(line)
  local marker, marker_key = line_comment_marker()
  if not marker then
    return nil
  end

  local indent, rest = line:match '^(%s*)(.*)$'
  if rest:sub(1, #marker) ~= marker then
    return nil
  end

  return {
    raw = line,
    prefix = indent .. marker,
    body = rest:sub(#marker + 1),
    is_comment = true,
    key = indent .. marker_key,
  }
end

local function fallback_comment_context(line)
  local _, marker_key = line_comment_marker()
  if not marker_key then
    return nil
  end

  local indent, rest = line:match '^(%s*)(.*)$'
  for _, marker in ipairs(fallback_comment_markers(marker_key)) do
    if rest:sub(1, #marker) == marker then
      local prefix, body, key = with_comment_spacing(indent, marker, rest:sub(#marker + 1))
      return {
        raw = line,
        prefix = prefix,
        body = body,
        is_comment = true,
        key = key,
      }
    end
  end

  return nil
end

local function line_context(line)
  return commentstring_context(line)
    or fallback_comment_context(line)
    or {
      raw = line,
      prefix = '',
      body = line,
      is_comment = false,
      key = '',
    }
end

local function context_blank(context)
  return context.body:match '^%s*$' ~= nil
end

local function same_context(left, right)
  if left.is_comment ~= right.is_comment then
    return false
  end

  if left.is_comment then
    return left.key == right.key
  end

  return true
end

local function current_block_range(current, current_context, min_indent)
  current = current or vim.fn.line '.'
  min_indent = min_indent or 0
  local line_count = vim.api.nvim_buf_line_count(0)

  if context_blank(current_context) then
    return current, current
  end

  local first = current
  while first > 1 do
    local previous = line_context(vim.fn.getline(first - 1))
    if
      context_blank(previous)
      or not same_context(current_context, previous)
      or (min_indent > 0 and #line_indent(previous.body) < min_indent)
    then
      break
    end
    first = first - 1
  end

  local last = current
  while last < line_count do
    local next_line = line_context(vim.fn.getline(last + 1))
    if
      context_blank(next_line)
      or not same_context(current_context, next_line)
      or (min_indent > 0 and #line_indent(next_line.body) < min_indent)
    then
      break
    end
    last = last + 1
  end

  return first, last
end

local function range_targets(first, last)
  first, last = normalize_range(first, last)

  local targets = {}
  for lnum = first, last do
    targets[#targets + 1] = lnum
  end

  return targets
end

local function current_indent_targets()
  local current = vim.fn.line '.'
  local current_context = line_context(vim.fn.getline(current))
  if context_blank(current_context) then
    return { current }
  end

  local current_indent = line_indent(current_context.body)
  local first, last = current_block_range(current, current_context, #current_indent)
  local targets = {}

  for lnum = first, last do
    local context = line_context(vim.fn.getline(lnum))
    if
      not context_blank(context)
      and same_context(current_context, context)
      and line_indent(context.body) == current_indent
    then
      targets[#targets + 1] = lnum
    end
  end

  return targets
end

local function current_indent_spans()
  local current = vim.fn.line '.'
  local current_context = line_context(vim.fn.getline(current))
  if context_blank(current_context) then
    return current, current, {
      {
        first = current,
        last = current,
        index = 1,
        key = current_context.body,
        lines = { current_context.raw },
      },
    }
  end

  local current_indent = line_indent(current_context.body)
  local first, last = current_block_range(current, current_context, #current_indent)
  local starts = {}

  for lnum = first, last do
    local context = line_context(vim.fn.getline(lnum))
    if
      not context_blank(context)
      and same_context(current_context, context)
      and line_indent(context.body) == current_indent
    then
      starts[#starts + 1] = lnum
    end
  end

  local spans = {}
  for index, start_line in ipairs(starts) do
    local end_line = (starts[index + 1] or (last + 1)) - 1
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    local context = line_context(lines[1] or '')
    spans[index] = {
      first = start_line,
      last = end_line,
      index = index,
      key = context.body,
      lines = lines,
    }
  end

  return first, last, spans
end

local function current_indent_span_targets()
  local _, _, spans = current_indent_spans()
  local targets = {}

  for _, span in ipairs(spans) do
    for lnum = span.first, span.last do
      targets[#targets + 1] = lnum
    end
  end

  return targets
end

local function command_targets(opts)
  if opts.range == 0 then
    return current_indent_targets()
  end

  return range_targets(opts.line1, opts.line2)
end

local function command_span_targets(opts)
  if opts.range == 0 then
    return current_indent_span_targets()
  end

  return range_targets(opts.line1, opts.line2)
end

local function target_contexts(targets)
  local lines = {}
  for index, lnum in ipairs(targets) do
    lines[index] = line_context(vim.fn.getline(lnum))
  end

  return lines
end

local function target_bodies(contexts)
  local bodies = {}
  for index, context in ipairs(contexts) do
    bodies[index] = context.body
  end

  return bodies
end

local function set_target_lines(targets, contexts, bodies)
  for index, lnum in ipairs(targets) do
    vim.fn.setline(lnum, contexts[index].prefix .. bodies[index])
  end
end

local function sort_entries(entries)
  table.sort(entries, function(left, right)
    if left.key == right.key then
      return left.index < right.index
    end

    return left.key < right.key
  end)
end

local function shift_width()
  return math.max(1, vim.fn.shiftwidth())
end

local function indent_body(body)
  if body:match '^%s*$' then
    return body
  end

  return string.rep(' ', shift_width()) .. body
end

local function outdent_body(body)
  local width = shift_width()
  local index = 1
  local removed = 0

  while index <= #body and removed < width do
    local char = body:sub(index, index)
    if char == ' ' then
      removed = removed + 1
      index = index + 1
    elseif char == '\t' then
      index = index + 1
      break
    else
      break
    end
  end

  return body:sub(index)
end

local function split_indent(line)
  local indent, text = line:match '^(%s*)(.*)$'
  return indent or '', text or ''
end

local function strip_existing_marker(line)
  local indent, text = split_indent(line)
  local stripped = text:match '^[%*%-%+]%s+(.*)$'
    or text:match '^%d+[.)]%s+(.*)$'
    or text:match '^[ivxlcdmIVXLCDM]+[.)]%s+(.*)$'
    or text:match '^[A-Za-z]+[.)]%s+(.*)$'

  return indent, stripped or text
end

local function parse_number_style(line)
  local digits, separator = line:match '^%s*(%d+)([.)])%s+'
  if digits then
    return {
      kind = 'arabic',
      start = tonumber(digits) or 1,
      separator = separator,
      width = #digits,
    }
  end

  local roman, roman_separator = line:match '^%s*([ivxlcdmIVXLCDM]+)([.)])%s+'
  local start = roman_to_int(roman)
  if start then
    return {
      kind = 'roman',
      start = start,
      separator = roman_separator,
      lower = roman == roman:lower(),
    }
  end

  return nil
end

local function parse_letter_style(line)
  local letters, separator = line:match '^%s*([A-Za-z]+)([.)])%s+'
  local start = alpha_to_int(letters)
  if start then
    return {
      kind = 'letter',
      start = start,
      separator = separator,
    }
  end

  return nil
end

local function infer_number_style(lines)
  for _, line in ipairs(lines) do
    if not line:match '^%s*$' then
      return parse_number_style(line)
        or {
          kind = 'arabic',
          start = 1,
          separator = '.',
          width = 1,
        }
    end
  end

  return {
    kind = 'arabic',
    start = 1,
    separator = '.',
    width = 1,
  }
end

local function infer_roman_style(lines)
  for _, line in ipairs(lines) do
    if not line:match '^%s*$' then
      local style = parse_number_style(line)
      if style then
        return {
          kind = 'roman',
          start = style.start,
          separator = style.separator,
          lower = style.kind == 'roman' and style.lower or false,
        }
      end

      return {
        kind = 'roman',
        start = 1,
        separator = '.',
        lower = false,
      }
    end
  end

  return {
    kind = 'roman',
    start = 1,
    separator = '.',
    lower = false,
  }
end

local function infer_letter_style(lines, upper)
  for _, line in ipairs(lines) do
    if not line:match '^%s*$' then
      local style = parse_letter_style(line) or parse_number_style(line)
      if style then
        return {
          kind = 'letter',
          start = style.start,
          separator = style.separator,
          upper = upper,
        }
      end

      return {
        kind = 'letter',
        start = 1,
        separator = '.',
        upper = upper,
      }
    end
  end

  return {
    kind = 'letter',
    start = 1,
    separator = '.',
    upper = upper,
  }
end

local function number_marker(style, value)
  if style.kind == 'roman' then
    local roman = int_to_roman(value) or tostring(value)
    if style.lower then
      roman = roman:lower()
    end
    return roman .. style.separator
  end

  if style.kind == 'letter' then
    return (int_to_alpha(value, style.upper) or tostring(value)) .. style.separator
  end

  local digits = tostring(value)
  if style.width and #digits < style.width then
    digits = string.rep('0', style.width - #digits) .. digits
  end

  return digits .. style.separator
end

function M.mark_targets(targets, marker)
  local contexts = target_contexts(targets)
  local updated = {}

  for index, context in ipairs(contexts) do
    if context_blank(context) then
      updated[index] = context.body
    else
      local indent, text = strip_existing_marker(context.body)
      updated[index] = indent .. marker .. ' ' .. text
    end
  end

  set_target_lines(targets, contexts, updated)
end

function M.mark_range(first, last, marker)
  M.mark_targets(range_targets(first, last), marker)
end

function M.clean_targets(targets)
  local contexts = target_contexts(targets)
  local updated = {}

  for index, context in ipairs(contexts) do
    if context_blank(context) then
      updated[index] = context.body
    else
      local indent, text = strip_existing_marker(context.body)
      updated[index] = indent .. text
    end
  end

  set_target_lines(targets, contexts, updated)
end

function M.clean_range(first, last)
  M.clean_targets(range_targets(first, last))
end

function M.shift_targets(targets, direction)
  local contexts = target_contexts(targets)
  local updated = {}

  for index, context in ipairs(contexts) do
    if direction > 0 then
      updated[index] = indent_body(context.body)
    else
      updated[index] = outdent_body(context.body)
    end
  end

  set_target_lines(targets, contexts, updated)
end

function M.indent_range(first, last)
  M.shift_targets(range_targets(first, last), 1)
end

function M.outdent_range(first, last)
  M.shift_targets(range_targets(first, last), -1)
end

function M.number_targets(targets)
  local contexts = target_contexts(targets)
  local style = infer_number_style(target_bodies(contexts))
  local next_number = style.start
  local updated = {}

  for index, context in ipairs(contexts) do
    if context_blank(context) then
      updated[index] = context.body
    else
      local indent, text = strip_existing_marker(context.body)
      updated[index] = indent .. number_marker(style, next_number) .. ' ' .. text
      next_number = next_number + 1
    end
  end

  set_target_lines(targets, contexts, updated)
end

function M.number_range(first, last)
  M.number_targets(range_targets(first, last))
end

function M.roman_targets(targets)
  local contexts = target_contexts(targets)
  local style = infer_roman_style(target_bodies(contexts))
  local next_number = style.start
  local updated = {}

  for index, context in ipairs(contexts) do
    if context_blank(context) then
      updated[index] = context.body
    else
      local indent, text = strip_existing_marker(context.body)
      updated[index] = indent .. number_marker(style, next_number) .. ' ' .. text
      next_number = next_number + 1
    end
  end

  set_target_lines(targets, contexts, updated)
end

function M.roman_range(first, last)
  M.roman_targets(range_targets(first, last))
end

function M.letter_targets(targets, upper)
  local contexts = target_contexts(targets)
  local style = infer_letter_style(target_bodies(contexts), upper)
  local next_number = style.start
  local updated = {}

  for index, context in ipairs(contexts) do
    if context_blank(context) then
      updated[index] = context.body
    else
      local indent, text = strip_existing_marker(context.body)
      updated[index] = indent .. number_marker(style, next_number) .. ' ' .. text
      next_number = next_number + 1
    end
  end

  set_target_lines(targets, contexts, updated)
end

function M.letter_range(first, last, upper)
  M.letter_targets(range_targets(first, last), upper)
end

function M.sort_range(first, last)
  first, last = normalize_range(first, last)

  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local entries = {}
  for index, line in ipairs(lines) do
    entries[index] = {
      index = index,
      key = line,
      lines = { line },
    }
  end

  sort_entries(entries)

  local sorted = {}
  for _, entry in ipairs(entries) do
    sorted[#sorted + 1] = entry.lines[1]
  end

  vim.api.nvim_buf_set_lines(0, first - 1, last, false, sorted)
end

function M.sort_current_indent_block()
  local first, last, spans = current_indent_spans()
  if not first or not last or #spans <= 1 then
    return
  end

  sort_entries(spans)

  local sorted = {}
  for _, span in ipairs(spans) do
    vim.list_extend(sorted, span.lines)
  end

  vim.api.nvim_buf_set_lines(0, first - 1, last, false, sorted)
end

vim.api.nvim_create_user_command('BulletLines', function(opts)
  M.mark_targets(command_targets(opts), '*')
end, { range = true, desc = 'Put * bullets on selected lines/same-indent block lines' })

vim.api.nvim_create_user_command('HyphenLines', function(opts)
  M.mark_targets(command_targets(opts), '-')
end, { range = true, desc = 'Put - bullets on selected lines/same-indent block lines' })

vim.api.nvim_create_user_command('NumberLines', function(opts)
  M.number_targets(command_targets(opts))
end, { range = true, desc = 'Renumber selected lines/same-indent block lines' })

vim.api.nvim_create_user_command('RomanLines', function(opts)
  M.roman_targets(command_targets(opts))
end, { range = true, desc = 'Renumber selected lines/same-indent block lines with Roman numerals' })

vim.api.nvim_create_user_command('LetterLines', function(opts)
  M.letter_targets(command_targets(opts), false)
end, { range = true, desc = 'Renumber selected lines/same-indent block lines with lowercase letters' })

vim.api.nvim_create_user_command('CapitalLetterLines', function(opts)
  M.letter_targets(command_targets(opts), true)
end, { range = true, desc = 'Renumber selected lines/same-indent block lines with uppercase letters' })

vim.api.nvim_create_user_command('CleanLines', function(opts)
  M.clean_targets(command_targets(opts))
end, { range = true, desc = 'Remove list markers from selected lines/same-indent block lines' })

vim.api.nvim_create_user_command('IndentLines', function(opts)
  M.shift_targets(command_span_targets(opts), 1)
end, { range = true, desc = 'Indent selected lines/same-indent block spans' })

vim.api.nvim_create_user_command('OutdentLines', function(opts)
  M.shift_targets(command_span_targets(opts), -1)
end, { range = true, desc = 'Outdent selected lines/same-indent block spans' })

vim.api.nvim_create_user_command('SortLines', function(opts)
  if opts.range == 0 then
    M.sort_current_indent_block()
    return
  end

  M.sort_range(opts.line1, opts.line2)
end, { range = true, desc = 'Sort selected lines/same-indent block spans' })

vim.keymap.set({ 'n', 'x' }, '<leader>lb', ':BulletLines<CR>', {
  desc = 'List: bullet lines',
  silent = true,
})
vim.keymap.set({ 'n', 'x' }, '<leader>lh', ':HyphenLines<CR>', {
  desc = 'List: hyphen lines',
  silent = true,
})
vim.keymap.set({ 'n', 'x' }, '<leader>ln', ':NumberLines<CR>', {
  desc = 'List: number lines',
  silent = true,
})
vim.keymap.set({ 'n', 'x' }, '<leader>lr', ':RomanLines<CR>', {
  desc = 'List: roman lines',
  silent = true,
})
vim.keymap.set({ 'n', 'x' }, '<leader>ll', ':LetterLines<CR>', {
  desc = 'List: letter lines',
  silent = true,
})
vim.keymap.set({ 'n', 'x' }, '<leader>lL', ':CapitalLetterLines<CR>', {
  desc = 'List: capital letter lines',
  silent = true,
})
vim.keymap.set({ 'n', 'x' }, '<leader>lc', ':CleanLines<CR>', {
  desc = 'List: clean markers',
  silent = true,
})
vim.keymap.set({ 'n', 'x' }, '<leader>l>', ':IndentLines<CR>', {
  desc = 'List: indent lines',
  silent = true,
})
vim.keymap.set({ 'n', 'x' }, '<leader>l<', ':OutdentLines<CR>', {
  desc = 'List: outdent lines',
  silent = true,
})
vim.keymap.set({ 'n', 'x' }, '<leader>ls', ':SortLines<CR>', {
  desc = 'List: sort lines',
  silent = true,
})

return M
