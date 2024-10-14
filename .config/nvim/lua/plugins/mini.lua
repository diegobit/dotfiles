return {
  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    version = '*',
    config = function()
      --------------------------------------
      -- mini.ai: Better Around/Inside textobjects
      --------------------------------------
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup {
        n_lines = 500,
        event = 'VeryLazy',
      }

      --------------------------------------
      -- mini.diff: replacement of gitsigns and diff
      --------------------------------------
      require('mini.diff').setup {
        event = 'VeryLazy',
        view = { style = 'sign', signs = { add = '┃', change = '┃', delete = '▁' } },
        keys = { vim.keymap.set('n', '<leader>tg', require('mini.diff').toggle_overlay, { desc = 'Git Diff Overlay' }) },
      }

      --------------------------------------
      -- mini.surround: Add/delete/replace surroundings (brackets, quotes, etc.)
      --------------------------------------
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup {
        event = 'VeryLazy',
      }
      -- disable s to avoid the timeout to use s alone (vim-surround)
      vim.keymap.set({ 'n', 'x' }, 's', '<Nop>')

      -- Animate scrolling
      -- local animate = require('mini.animate')
      -- animate.setup {
      --   scroll = {
      --     timing = animate.gen_timing.linear({ duration = 80, unit = 'total' }),
      --     subscroll = animate.gen_subscroll.equal({ max_output_steps = 5 }),
      --   }
      -- }

      --------------------------------------
      -- mini.statusline: Better statusline
      --------------------------------------
      local statusline = require 'mini.statusline'
      vim.api.nvim_set_hl(0, 'MiniStatuslineTab', { fg = '#ff9e64', bg = '#292e42', default = true })
      -- vim.api.nvim_set_hl(0, 'MiniStatuslineTab', { link = 'IncSearch', default = true })
      -- vim.api.nvim_set_hl(0, 'MiniStatuslineTab', { link = 'CurSearch', default = true })

      local my_section_tab = function(args)
        local tab_max = vim.fn.tabpagenr '$'
        if tab_max > 1 then
          -- if statusline.is_truncated(args.trunc_width) then
          --   return ' ' .. vim.fn.tabpagenr()
          -- else
          --   return ' ' .. vim.fn.tabpagenr() .. '/' .. tab_max
          if statusline.is_truncated(args.trunc_width) then
            return '' .. vim.fn.tabpagenr()
          else
            return ' ' .. vim.fn.tabpagenr()
          end
        else
          return ''
        end
      end

      local my_section_location = function(args)
        -- Use virtual column number to allow update when past last column
        if statusline.is_truncated(args.trunc_width) then
          return '%l│%v'
          -- return '%v:%-l'
        end
        -- Use `virtcol()` to correctly handle multi-byte characters
        -- return '%2v:%l/%L'
        return '%2l/%L│%2v'
      end

      local my_active_content = function()
        local mode, mode_hl = MiniStatusline.section_mode { trunc_width = 120 }
        local tab = my_section_tab { trunc_width = 75 }
        local git = MiniStatusline.section_git { trunc_width = 40 }
        local diff = MiniStatusline.section_diff { trunc_width = 75 }
        local diagnostics = MiniStatusline.section_diagnostics { trunc_width = 75 }
        local lsp = MiniStatusline.section_lsp { trunc_width = 75 }
        local filename = MiniStatusline.section_filename { trunc_width = 140 }
        local fileinfo = MiniStatusline.section_fileinfo { trunc_width = 120 }
        local location = my_section_location { trunc_width = 90 }

        return MiniStatusline.combine_groups {
          { hl = mode_hl, strings = { mode } },
          { hl = 'MiniStatuslineDevinfo', strings = { git, diff, diagnostics, lsp } },
          { hl = 'MiniStatuslineTab', strings = { tab } },
          '%<', -- Mark general truncate point
          { hl = 'MiniStatuslineFilename', strings = { filename } },
          '%=', -- End left alignment
          { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
          { hl = mode_hl, strings = { location } },
        }
      end
      statusline.setup { content = { active = my_active_content }, use_icons = vim.g.have_nerd_font }
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
