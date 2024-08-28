return {
  'LukasPietzschmann/telescope-tabs',
  config = function()
    require('telescope').load_extension 'telescope-tabs'
    require('telescope-tabs').setup {
      -- Your custom config :^)
    }
    vim.keymap.set('n', '<leader>st', function()
      require('telescope-tabs').list_tabs()
    end, { desc = '[S]earch [T]abs' })
  end,
  event = 'VeryLazy',
  dependencies = { 'nvim-telescope/telescope.nvim' },
}
