-- This file is automatically loaded by ba.config.init.

-- Tiny helper: pick Nerd Font or ASCII fallback
local function I(nerd, ascii)
  return (vim.g.have_nerd_font and nerd) or ascii
end

-- icons used by other plugins
-- stylua: ignore
return {
  misc = {
    dots = I('󰇘', '…'),
  },
  todo = {
    fix  = I(' ', '🚩'),
    todo = I(' ', '✔ '),
    hack = I(' ', 'ঌ '),
    warn = I(' ', '⚠️'),
    perf = I(' ', '⏱ '),
    note = I(' ', 'ⓘ '),
    test = I('⏲ ', '⏲ '),
  },
  bufferline = {
    buffer_close_icon  = I('󰅖', 'x'),
    modified_icon      = I('● ', '●'),
    close_icon         = I(' ', 'ㄨ'),
    left_trunc_marker  = I(' ', '←'),
    right_trunc_marker = I(' ', '→'),
  },
  diagnostics = {
    Error = I(' ', '❗'), -- '󰅚 ', ' '
    Warn  = I(' ', '▲ '), -- '󰀪 ', ' ', '▼'
    Hint  = I(' ', '𝒾 '), -- '󰌶 ', ' '
    Info  = I(' ', 'ⓘ '), -- '󰋽 ', ' '
  },
  dashboard = {
    find     = I(' ', '●'), -- '🔍'),
    new_file = I(' ', '●'), -- '📄'),
    grep     = I(' ', '●'), -- '📖'),
    projects = I(' ', '●'), -- '📂'),
    recent   = I(' ', '●'), -- '📑'),
    config   = I(' ', '●'), -- '⚙️'),
    restore  = I(' ', '●'), -- '↪️'),
    lazy     = I('󰒲 ', '●'), -- '𝗓ᶻ'),
    quit     = I(' ', '●'), -- '🚪'),
  },
  git = {
    added     = I(' ', '+'),
    modified  = I(' ', '~'),
    removed   = I(' ', '-'),
    deleted   = I('✖', '✖'),
    renamed   = I('󰁕', '→'),
    untracked = I('', '?'),
    ignored   = I('', '☐'),
    unstaged  = I('󰄱', '☐'),
    staged    = I('', '☑'),
    conflict  = I('', '☒'),
    branch    = I('', ''), -- don't use 𖦥 for replacement, breaks statusline lol
    github    = I('', 'GH'),
  },
  lualine = {
    component_separators = { left = I('', '|'), right = I('', '|')},
    section_separators = { left = I('', ''), right = I('', '')},
  },
  kinds = {
    Array         = I(' ', '[]'),
    Boolean       = I('󰨙 ', '🚦'),
    Class         = I(' ', '🏛️'),
    Clock         = I(' ', ''),
    Codeium       = I('󰘦 ', '{…}'),
    Color         = I(' ', '🎨'),
    Control       = I(' ', 'ctl'),
    Collapsed     = I(' ', '❯'),
    Constant      = I('󰏿 ', 'π'),
    Constructor   = I(' ', '⚙️'),
    Copilot       = I(' ', '🤖'),
    Expanded      = I(' ', '⌄'),
    Enum          = I(' ', '🔢'),
    EnumMember    = I(' ', '🔹'),
    Event         = I(' ', '⚡︎'),
    Field         = I(' ', '🏷️'),
    File          = I(' ', '📋'),
    Folder        = I(' ', '▨'),
    FolderOpen    = I(' ', '⬚'),
    FolderEmpty   = I('󰜌 ', '⬚'),
    Function      = I('󰊕 ', 'ⓕ '),
    Interface     = I(' ', '🔌'),
    Key           = I(' ', '🔑'),
    Keyword       = I(' ', '🔤'),
    Method        = I('󰊕 ', 'ⓕ '),
    Module        = I(' ', '➜'),
    Namespace     = I('󰦮 ', '🗂️'),
    Null          = I(' ', 'Ø'),
    Number        = I('󰎠 ', '🔢'),
    Object        = I(' ', '{}'),
    Operator      = I(' ', '➕'),
    Package       = I(' ', '➜'),
    Property      = I(' ', '🏷️'),
    Reference     = I(' ', '🔗'),
    Snippet       = I('󱄽 ', '✂️'),
    String        = I(' ', '🔤'),
    Struct        = I('󰆼 ', '⛁'),
    Supermaven    = I(' ', '★'),
    TabNine       = I('󰏚 ', '🤖'),
    Text          = I(' ', '📝'),
    TypeParameter = I(' ', 'T'),
    Unit          = I(' ', '📏'),
    Value         = I(' ', 'Aa'),
    Variable      = I('󰀫 ', '𝛂'),
  },
}
