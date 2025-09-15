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
  diagnostics = {
    Error = I(' ', 'E'),
    Warn  = I(' ', 'W'),
    Hint  = I(' ', 'H'),
    Info  = I(' ', 'I'),
  },
  git = {
    added    = I(' ', '++'),
    modified = I(' ', '~~'),
    removed  = I(' ', '--'),
    github   = I('', 'GH'),
    branch   = I('', 'ᛉ '),
  },
  lualine = {
    component_separators = { left = I('', '|'), right = I('', '|')},
    section_separators = { left = I('', ' '), right = I('', ' ')},
  },
  kinds = {
    Array         = I(' ', '[]'),
    Boolean       = I('󰨙 ', 'bool'),
    Class         = I(' ', 'class'),
    Clock         = I(' ', '🕒'),
    Codeium       = I('󰘦 ', 'AI'),
    Color         = I(' ', '#'),
    Control       = I(' ', 'ctl'),
    Collapsed     = I(' ', '>'),
    Constant      = I('󰏿 ', 'cons'),
    Constructor   = I(' ', 'new'),
    Copilot       = I(' ', 'AI'),
    Enum          = I(' ', 'enum'),
    EnumMember    = I(' ', 'enm'),
    Event         = I(' ', 'evt'),
    Field         = I(' ', 'fld'),
    File          = I(' ', 'file'),
    Folder        = I(' ', 'dir'),
    Function      = I('󰊕 ', 'fn'),
    Interface     = I(' ', 'iface'),
    Key           = I(' ', 'key'),
    Keyword       = I(' ', 'kw'),
    Method        = I('󰊕 ', 'fn'),
    Module        = I(' ', 'mod'),
    Namespace     = I('󰦮 ', 'ns'),
    Null          = I(' ', 'null'),
    Number        = I('󰎠 ', '#'),
    Object        = I(' ', 'ob'),
    Operator      = I(' ', 'o'),
    Package       = I(' ', 'pkg'),
    Property      = I(' ', 'prop'),
    Reference     = I(' ', 'ref'),
    Snippet       = I('󱄽 ', 'snip'),
    String        = I(' ', 'str'),
    Struct        = I('󰆼 ', 'struct'),
    Supermaven    = I(' ', 'AI'),
    TabNine       = I('󰏚 ', 'AI'),
    Text          = I(' ', 'txt'),
    TypeParameter = I(' ', 'T'),
    Unit          = I(' ', 'u'),
    Value         = I(' ', 'val'),
    Variable      = I('󰀫 ', 'var'),
  },
}
