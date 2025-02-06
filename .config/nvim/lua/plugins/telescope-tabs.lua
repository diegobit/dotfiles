return {
  'LukasPietzschmann/telescope-tabs',
  config = function()
    require('telescope').load_extension 'telescope-tabs'
    require('telescope-tabs').setup {
      -- Your custom config :^)
    }
  end,
  vim.keymap.set('n', '<leader>T', function()
    require('telescope-tabs').list_tabs(require('telescope.themes').get_dropdown {
      previewer = false,
      -- initial_mode = 'normal',
    })
  end, { desc = 'List Tabs' }),
  lazy = true,
  dependencies = { 'nvim-telescope/telescope.nvim' },
}
