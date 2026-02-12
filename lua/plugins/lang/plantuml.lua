return {
  {
    'Sengoku11/plantuml.nvim',
    keys = {
      { '<leader>pl', '<cmd>PlantumlRenderAscii<cr>', desc = 'Render UML Ascii' },
      { '<leader>pi', '<cmd>PlantumlRenderImg<cr>', desc = 'Render UML Image' },
    },
    cmd = { 'PlantumlRender' },
    ft = { 'plantuml', 'puml', 'uml', 'markdown' },
    opts = {
      open = 'right',
    },
  },
  {
    'aklt/plantuml-syntax',
    lazy = false,
  },
}
