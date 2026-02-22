local strings = require 'ba.util.strings'

local function read_gemini_api_key()
  local path = vim.fn.expand '~/.env/.gemini'
  local file = io.open(path, 'r')
  if not file then
    return nil
  end

  local content = file:read '*a'
  file:close()
  if not content or content == '' then
    return nil
  end

  local fallback = nil
  for line in content:gmatch '[^\r\n]+' do
    local trimmed = vim.trim(line)
    if trimmed ~= '' and not trimmed:match '^#' then
      local assigned = trimmed:match '^export%s+GEMINI_API_KEY%s*=%s*(.+)$'
      if not assigned then
        assigned = trimmed:match '^GEMINI_API_KEY%s*=%s*(.+)$'
      end

      if assigned then
        return strings.strip_wrapping_quotes(vim.trim(assigned))
      end

      if not fallback then
        fallback = trimmed
      end
    end
  end

  if fallback then
    return strings.strip_wrapping_quotes(fallback)
  end

  return nil
end

local function gemini_api_key()
  local file_key = read_gemini_api_key()
  if file_key and file_key ~= '' then
    return file_key
  end

  local env_key = os.getenv 'GEMINI_API_KEY'
  if env_key and env_key ~= '' then
    return env_key
  end

  return nil
end

local function default_adapter_name()
  if gemini_api_key() then
    return 'gemini'
  end

  if vim.fn.executable 'codex-acp' == 1 then
    return 'codex'
  end

  return 'copilot'
end

local function codex_adapter()
  return require('codecompanion.adapters').extend('codex', {
    defaults = {
      auth_method = 'chatgpt',
    },
  })
end

local function gemini_adapter()
  return require('codecompanion.adapters').extend('gemini', {
    env = {
      api_key = gemini_api_key,
    },
    schema = {
      model = {
        default = os.getenv 'GEMINI_MODEL' or 'gemini-2.5-flash',
      },
    },
  })
end

local default_adapter = default_adapter_name()

return {
  {
    'olimorris/codecompanion.nvim',
    event = 'VeryLazy',
    cmd = {
      'CodeCompanion',
      'CodeCompanionActions',
      'CodeCompanionChat',
      'CodeCompanionCmd',
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    opts = {
      adapters = {
        http = {
          gemini = gemini_adapter,
        },
        acp = {
          codex = codex_adapter,
        },
      },
      strategies = {
        chat = { adapter = default_adapter },
        inline = { adapter = default_adapter },
        cmd = { adapter = default_adapter },
      },
    },
    keys = {
      { '<leader>oa', '<cmd>CodeCompanionActions<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion Actions' },
      { '<leader>oc', '<cmd>CodeCompanionChat Toggle<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion Chat' },
      { '<leader>oi', '<cmd>CodeCompanion<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion Inline' },
    },
  },
}
