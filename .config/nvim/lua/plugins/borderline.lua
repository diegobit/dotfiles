return {
  'mikesmithgh/borderline.nvim',
  enabled = true,
  event = 'UIEnter',
  config = function()
    require('borderline').setup {
      border = 'single',
    }
  end,
}
