return {
  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    version = '*',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500, event = 'VeryLazy' }
      -- replacement of gitsigns and diff
      require('mini.diff').setup {
        event = 'VeryLazy',
        view = { style = 'sign', signs = { add = '┃', change = '┃', delete = '▁' } },
        keys = { vim.keymap.set('n', '<leader>td', require('mini.diff').toggle_overlay, { desc = '[T]oggle [D]iff Overlay' }) },
      }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup {
        event = 'VeryLazy',
      }
      -- disable s to avoid the timeout to use s alone (vim-surround)
      vim.keymap.set({ 'n', 'x' }, 's', '<Nop>')

      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }

      -- statusline.section_location = function()
      --   return '%2l:%-2v'
      -- end
      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function(args)
        -- Use virtual column number to allow update when past last column
        if MiniStatusline.is_truncated(args.trunc_width) then return '%2l:%-2v' end
        -- Use `virtcol()` to correctly handle multi-byte characters
        return '%2v:%l/%L'
      end

      -- Disable search count: it's already in the cmdline
      statusline.section_searchcount = function()
        return ''
      end

      -- Add tab number to statusline. section_filename logic from source
      local function tab_text(is_truncated)
        local title = is_truncated and '' or 'Tab:'
        local tab_max = vim.fn.tabpagenr '$'
        if tab_max > 1 then
          return '[' .. title .. vim.fn.tabpagenr() .. '/' .. tab_max .. '] '
        else
          return ''
        end
      end

      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_filename = function(args)
        -- In terminal always use plain name
        if vim.bo.buftype == 'terminal' then
          return tab_text(false) .. '%t'
        elseif MiniStatusline.is_truncated(args.trunc_width) then
          -- File name with 'truncate', 'modified', 'readonly' flags
          -- Use relative path if truncated
          return tab_text(true) .. '%f%m%r'
        else
          -- Use fullpath if not truncated
          return tab_text(false) .. '%F%m%r'
        end
      end
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
