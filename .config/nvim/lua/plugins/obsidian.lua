local vault_path = vim.fn.expand '~' .. '/notes'

return {
  'epwalsh/obsidian.nvim',
  version = '*',
  lazy = true,
  ft = 'markdown',
  event = {
    'BufReadPre ' .. vault_path .. '/*.md',
    'BufNewFile ' .. vault_path .. '/*.md',
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'bullets-vim/bullets.vim',
  },
  opts = {
    workspaces = {
      {
        name = 'notes',
        path = vault_path,
      },
    },
  },
  config = function()
    vim.o.conceallevel = 2
  end,
}
