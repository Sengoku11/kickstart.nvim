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
      window = {
        right_width_pct = 0.8, -- ratio 0.0..1.0 (0.0 means no forced sizing)
        bottom_height_pct = 0.0, -- ratio 0.0..1.0 (0.0 means no forced sizing)
      },
    },
  },
  {
    'aklt/plantuml-syntax',
    lazy = false,
  },
}
