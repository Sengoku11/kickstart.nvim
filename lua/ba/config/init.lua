local M = {}

-- Load options, scripts and other configs.
require 'ba.config.clipboard'

-- Load and store icons in the singleton config.
M.icons = require 'ba.config.icons'

return M
