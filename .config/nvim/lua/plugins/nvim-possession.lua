return {
  'gennaro-tedesco/nvim-possession',
  dependencies = {
    'ibhagwan/fzf-lua',
  },
  config = true,
  init = function()
    local possession = require 'nvim-possession'
    possession.setup {
      post_hook = function()
        require('FTerm').open()
        require('nvim-tree').toggle(false, true)
        vim.lsp.buf.format()
      end,
    }
    vim.keymap.set('n', '<leader>spl', function()
      possession.list()
    end)
    vim.keymap.set('n', '<leader>spn', function()
      possession.new()
    end)
    vim.keymap.set('n', '<leader>spu', function()
      possession.update()
    end)
    vim.keymap.set('n', '<leader>spd', function()
      possession.delete()
    end)
  end,
}
