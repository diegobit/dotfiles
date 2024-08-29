return {
  'mikesmithgh/borderline.nvim',
  enabled = true,
  lazy = true,
  config = function()
    require('borderline').setup {
      border = 'single',
    }
  end,
}
