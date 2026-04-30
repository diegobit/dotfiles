return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      local filetypes = {
        'bash',
        'diff',
        'lua',
        'markdown',
        'vim',
        'python',
        'ruby',
        'rust',
        'go',
        'javascript',
        'typescript',
        'http',
      }

      require('nvim-treesitter').setup {
        install_dir = vim.fn.stdpath('data') .. '/site',
      }

      require('nvim-treesitter').install(filetypes)

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('kickstart-treesitter-start', { clear = true }),
        pattern = filetypes,
        callback = function(event)
          pcall(vim.treesitter.start, event.buf)
        end,
      })

      -- There are additional nvim-treesitter modules that you can use to interact
      -- with nvim-treesitter. You should go explore a few and see what interests you:
      --
      --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
      --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
      --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
      vim.api.nvim_set_hl(0, '@string.documentation', { link = 'Comment' })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
