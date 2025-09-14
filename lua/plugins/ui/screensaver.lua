return {
  {
    'folke/drop.nvim',
    enabled = false,
    opts = {
      theme = 'auto', -- when auto, it will choose a theme based on the date
      screensaver = 1000 * 60 * 5, -- show after 5 minutes. Set to false, to disable
      filetypes = { 'dashboard' },
      themes = {
        { theme = 'new_year', month = 1, day = 1 },
        { theme = 'valentines_day', month = 2, day = 14 },
        { theme = 'st_patricks_day', month = 3, day = 17 },
        { theme = 'easter', holiday = 'easter' },
        { theme = 'april_fools', month = 4, day = 1 },
        { theme = 'us_independence_day', month = 7, day = 4 },
        { theme = 'halloween', month = 10, day = 31 },
        { theme = 'us_thanksgiving', holiday = 'us_thanksgiving' },
        { theme = 'xmas', month = 12, day = 25 },
        { theme = 'spring', from = { month = 3, day = 20 }, to = { month = 6, day = 20 } },
        { theme = 'summer', from = { month = 6, day = 21 }, to = { month = 9, day = 11 } },
        { theme = 'leaves', from = { month = 9, day = 12 }, to = { month = 10, day = 20 } },
        { theme = 'snow', from = { month = 10, day = 21 }, to = { month = 3, day = 19 } },
      },
    },
  },
}
