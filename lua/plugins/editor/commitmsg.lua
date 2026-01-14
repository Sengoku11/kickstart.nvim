return {
  {
    'MunifTanjim/nui.nvim',

    -- Lazy-load NUI when you trigger your UI
    cmd = { 'CommitMsg' },
    keys = {
      {
        '<leader>gc',
        function()
          require('ba.plugins.commitmsg.ui').open()
        end,
        desc = 'Commit message popup',
      },
    },

    init = function()
      -- Define the command early; it will auto-load nui.nvim on use because of cmd=...
      vim.api.nvim_create_user_command('CommitMsg', function()
        require('ba.plugins.commitmsg.ui').open()
      end, {})
    end,
  },
}
