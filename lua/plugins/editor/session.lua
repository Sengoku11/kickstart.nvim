-- Prevent opening empty buffer on session restore.
local unload_fts = {
  ['copilot-chat'] = true,
  ['snacks_layout_box'] = true, -- snacks.explorer
  ['Trouble'] = true,
  ['trouble'] = true,
  ['terminal'] = true,
  ['blame'] = true,
  ['undotree'] = true,
  ['diff'] = true,
  ['neo-tree'] = true,
  ['plantuml_ascii'] = true,
}

-- Store colorschemes in sessions
require('ba.util.colorscheme').setup_session_persistence()

vim.api.nvim_create_autocmd('User', {
  pattern = 'PersistenceSavePre',
  callback = function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        local ft = vim.bo[buf].filetype
        if unload_fts[ft] then
          vim.cmd.bunload(buf)
        end
      end
    end
  end,
})

return {
  -- Session management. This saves your session in the background,
  -- keeping track of open buffers, window arrangement, and more.
  -- You can restore sessions when returning through the dashboard.
  {
    'folke/persistence.nvim',
    event = 'BufReadPre',
    opts = {},
    -- stylua: ignore
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>qS", function() require("persistence").select() end,desc = "Select Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
  },
}
