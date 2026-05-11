---@module 'snacks'
local function focus_terminal()
  local term = Snacks.terminal.focus(nil, { win = { enter = true } })

  vim.schedule(function()
    if term and term.win and vim.api.nvim_win_is_valid(term.win) then
      vim.api.nvim_set_current_win(term.win)
    end
    if vim.bo.buftype == 'terminal' then
      vim.cmd.startinsert { bang = true }
    end
  end)
end

return {
  {
    'folke/snacks.nvim',
    event = 'VeryLazy',
    ---@type snacks.Config
    opts = {
      terminal = {
        win = {
          enter = true,
          keys = {
            term_normal = false,
          },
        },
      },
    },
    keys = {
      -- stylua: ignore
      {'<leader>tt', focus_terminal, desc = "Terminal (cwd)" },
    },
  },
}
