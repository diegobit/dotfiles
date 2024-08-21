return {
  { -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- See `:help ibl`
    main = 'ibl',
    opts = {},
    config = function(_, opts)
      require('ibl').setup(opts)
    end,
  },
}
