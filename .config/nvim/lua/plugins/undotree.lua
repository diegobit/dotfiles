return {
  'mbbill/undotree',
  lazy = true,
  cmd = { 'UndotreeToggle' },
  keys = {
    vim.keymap.set('n', '<leader>tu', vim.cmd.UndotreeToggle, { noremap = true, silent = true, desc = 'Undotree' }),
  },
}
