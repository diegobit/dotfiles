return {
  'goerz/jupytext.nvim',
  version = '0.2.0',
  event = { 'BufReadCmd *.ipynb' },
  opts = {
    format = 'py:percent',
    -- format = 'markdown',
  },
}
