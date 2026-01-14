local M = {}

function M.setup()
  vim.api.nvim_create_user_command('CommitMsg', function()
    require('ba.plugins.commitmsg.ui').open()
  end, {})
end

return M
