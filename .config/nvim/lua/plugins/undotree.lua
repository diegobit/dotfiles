return {
  'mbbill/undotree',
  event = 'VeryLazy',
  keys = {
    vim.keymap.set('n', '<leader>tu', vim.cmd.UndotreeToggle, { noremap = true, silent = true, desc = '[T]oggle [U]ndotree' }),
  },
}
