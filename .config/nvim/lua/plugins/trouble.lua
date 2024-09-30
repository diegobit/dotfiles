return {
  'folke/trouble.nvim',
  opts = {
    symbols = {
      desc = 'document symbols',
      version = '*',
      mode = 'lsp_document_symbols',
      focus = false,
      win = { position = 'right' },
      filter = {
        -- remove Package since luals uses it for control flow structures
        ['not'] = { ft = 'lua', kind = 'Package' },
        any = {
          -- all symbol kinds for help / markdown files
          ft = { 'help', 'markdown' },
          -- default set of symbol kinds
          kind = {
            'Class',
            'Constructor',
            'Enum',
            'Field',
            'Function',
            'Interface',
            'Method',
            'Module',
            'Namespace',
            'Package',
            'Property',
            'Struct',
            'Trait',
          },
        },
      },
    },
  }, -- for default options, refer to the configuration section for custom setup.
  cmd = 'Trouble',
  keys = {
    {
      '<leader>td',
      '<cmd>Trouble diagnostics toggle<cr>',
      desc = 'Diagnostics (Trouble)',
      mode = 'n',
    },
    {
      '<leader>tD',
      '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
      desc = 'Diagnostics Buffer (Trouble)',
      mode = 'n',
    },
    {
      '<leader>tS',
      '<cmd>Trouble symbols toggle focus=false<cr>',
      desc = 'Symbols (Trouble)',
      mode = 'n',
    },
    {
      '<leader>tl',
      '<cmd>Trouble lsp toggle focus=false win.position=right<cr>',
      desc = 'LSP defs/refs/... (Trouble)',
      mode = 'n',
    },
    {
      '<leader>tL',
      '<cmd>Trouble loclist toggle<cr>',
      desc = 'Location List (Trouble)',
      mode = 'n',
    },
    {
      '<leader>tq',
      '<cmd>Trouble qflist toggle<cr>',
      desc = 'Quickfix List (Trouble)',
      mode = 'n',
    },
  },
}
