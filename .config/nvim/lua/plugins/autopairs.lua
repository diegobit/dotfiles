-- autopairs
-- https://github.com/windwp/nvim-autopairs

return {
  'windwp/nvim-autopairs',
  event = 'InsertEnter',
  -- Optional dependency
  dependencies = { 'hrsh7th/nvim-cmp' },
  config = function()
    local npairs = require 'nvim-autopairs'
    local Rule = require 'nvim-autopairs.rule'
    local cond = require 'nvim-autopairs.conds'

    npairs.setup {}
    npairs.add_rules({
      Rule('```', '```', {
        '-markdown',
        '-vimwiki',
        '-rmarkdown',
        '-rmd',
        '-pandoc',
        '-quarto',
        '-typst',
        '-gitcommit',
      }):with_pair(cond.not_before_char('`', 3)),
      Rule('```.*$', '```', {
        '-markdown',
        '-vimwiki',
        '-rmarkdown',
        '-rmd',
        '-pandoc',
        '-quarto',
        '-typst',
      }):only_cr():use_regex(true),
    })

    -- If you want to automatically add `(` after selecting a function or method
    local cmp_autopairs = require 'nvim-autopairs.completion.cmp'
    local cmp = require 'cmp'
    cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done())
  end,
}
