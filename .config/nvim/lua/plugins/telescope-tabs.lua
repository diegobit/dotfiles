return {
  'LukasPietzschmann/telescope-tabs',
  config = function()
    require('telescope').load_extension 'telescope-tabs'
    require('telescope-tabs').setup {
      -- Your custom config :^)
    }
  end,
  vim.keymap.set('n', '<leader>T', function()
    require('telescope-tabs').list_tabs()
  end, { desc = '[T]abs' }),
  lazy = true,
  dependencies = { 'nvim-telescope/telescope.nvim' },
}
