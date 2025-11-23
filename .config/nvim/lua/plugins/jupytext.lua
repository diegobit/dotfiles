return {
  'goerz/jupytext.nvim',
  version = '0.2.0',
  event = { 'BufReadCmd *.ipynb', 'BufWriteCmd *.ipynb' },
  opts = {
    -- format = 'py:percent',
  }, -- see Options
}
