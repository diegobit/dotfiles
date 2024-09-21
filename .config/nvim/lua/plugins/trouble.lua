return {
  'folke/trouble.nvim',
  opts = {
    symbols = {
      desc = 'document symbols',
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
      desc = '[D]iagnostics (Trouble)',
    },
    {
      '<leader>tD',
      '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
      desc = 'Buffer [D]iagnostics (Trouble)',
    },
    {
      '<leader>ts',
      '<cmd>Trouble symbols toggle focus=false<cr>',
      desc = '[S]ymbols (Trouble)',
    },
    {
      '<leader>tl',
      '<cmd>Trouble lsp toggle focus=false win.position=right<cr>',
      desc = '[L]SP defs/refs/... (Trouble)',
    },
    {
      '<leader>tL',
      '<cmd>Trouble loclist toggle<cr>',
      desc = '[L]ocation List (Trouble)',
    },
    {
      '<leader>tq',
      '<cmd>Trouble qflist toggle<cr>',
      desc = '[Q]uickfix List (Trouble)',
    },
  },
}
