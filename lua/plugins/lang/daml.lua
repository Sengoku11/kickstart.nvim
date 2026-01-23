return {
  {
    'Sengoku11/daml.nvim',
    branch = 'dev',
    ft = 'daml',
    keys = {
      { '<leader>gt', '<cmd>DamlRunScript<cr>', desc = 'Run Daml Script' },
    },
    opts = {
      -- daml_script = { render = false },
      lsp = {
        cmd = { 'dpm', 'damlc', 'multi-ide', '--RTS', '+RTS', '-M4G', '-N' },
      },
    },
  },
}
