-- zen-mode

return {
  'folke/zen-mode.nvim',
  opts = {
    window = {
      width = 140,
      backdrop = 0.85,
    },
    plugins = {
      options = {
        laststatus = 3,
      },
    },
    -- or leave it empty to use the default settings
    -- refer to the configuration section below
  },
}
