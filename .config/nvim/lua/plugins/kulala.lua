return {
  'mistweaverco/kulala.nvim',
  ft = { 'http', 'rest' },
  opts = {},
  keys = {
    { '<leader>xr', function() require('kulala').run() end, desc = 'Run Request', ft = { 'http', 'rest' } },
    { '<leader>xa', function() require('kulala').run_all() end, desc = 'Run All in File', ft = { 'http', 'rest' } },
    { '<leader>xn', function() require('kulala').jump_next() end, desc = 'Next Request', ft = { 'http', 'rest' } },
    { '<leader>xp', function() require('kulala').jump_prev() end, desc = 'Prev Request', ft = { 'http', 'rest' } },
    { '<leader>xc', function() require('kulala').copy() end, desc = 'Copy as cURL', ft = { 'http', 'rest' } },
    { '<leader>xC', function() require('kulala').from_curl() end, desc = 'Paste from cURL', ft = { 'http', 'rest' } },
    { '<leader>xe', function() require('kulala').set_selected_env() end, desc = 'Select Env', ft = { 'http', 'rest' } },
    { '<leader>xR', function() require('kulala').replay() end, desc = 'Replay Last Request', ft = { 'http', 'rest' } },
  },
}
