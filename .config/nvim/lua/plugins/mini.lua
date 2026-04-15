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

      --------------------------------------
      -- mini.files: File explorer
      --------------------------------------
      require('mini.files').setup {
        options = {
          use_as_default_explorer = true,
        },
        windows = {
          preview = false,
          width_preview = 40,
        },
      }

      local function get_mini_files_path()
        if vim.bo.filetype == 'minifiles' then
          local state = require('mini.files').get_explorer_state()
          return state and state.anchor or vim.fn.getcwd()
        end

        local path = vim.api.nvim_buf_get_name(0)
        if path == '' then
          return vim.fn.getcwd()
        end

        return path
      end

      local function open_mini_files()
        require('mini.files').open(get_mini_files_path())
      end

      local function toggle_mini_files()
        if vim.bo.filetype == 'minifiles' then
          require('mini.files').close()
          return
        end

        open_mini_files()
      end

      vim.keymap.set('n', '-', function()
        toggle_mini_files()
      end, { desc = 'Open File Explorer' })

      vim.api.nvim_create_user_command('Ex', function()
        open_mini_files()
      end, {})

      vim.api.nvim_create_user_command('Explorer', function()
        open_mini_files()
      end, {})

      vim.api.nvim_create_autocmd('User', {
        pattern = 'MiniFilesBufferCreate',
        callback = function(args)
          vim.keymap.set('n', '<CR>', function()
            local mini_files = require('mini.files')
            local entry = mini_files.get_fs_entry()
            if not entry then
              return
            end

            if entry.fs_type == 'directory' then
              vim.cmd.cd(vim.fn.fnameescape(entry.path))
              vim.cmd.pwd()
              mini_files.reveal_cwd()
              return
            end

            mini_files.go_in { close_on_file = true }
          end, {
            buffer = args.data.buf_id,
            desc = 'Open File or Set Local CWD',
          })
        end,
      })

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

      -- color for tokyonight
      vim.api.nvim_set_hl(0, 'MiniStatuslineTab', { fg = '#ff9e64', bg = '#2f334d', default = true })
      -- harpoon section: yellow-ish, same bg as tab
      vim.api.nvim_set_hl(0, 'MiniStatuslineHarpoon', { fg = '#e0af68', bg = '#2f334d', default = true })

      local function my_section_tab(args)
        local tab_max = vim.fn.tabpagenr '$'
        local icon = '󰓩'
        if tab_max > 1 then
          if statusline.is_truncated(args.trunc_width) then
            return '' .. vim.fn.tabpagenr()
          else
            return icon .. ' ' .. vim.fn.tabpagenr()
          end
        else
          return ''
        end
      end

      local function my_section_harpoon(args)
        local ok, harpoon = pcall(require, 'harpoon')
        if not ok then
          return ''
        end

        local list = harpoon:list()
        local items = list.items or {}
        local total = #items
        if total == 0 then
          return ''
        end

        local icon = '󰛢'

        -- normalize to absolute paths using Vim's path logic
        local function normalize(path)
          if not path or path == '' then
            return nil
          end
          -- :p => full path, resolves "setup.py" -> "/Users/.../setup.py" from cwd
          return vim.fn.fnamemodify(path, ':p')
        end

        local current_path = vim.api.nvim_buf_get_name(0)
        local current_abs = normalize(current_path)
        if not current_abs then
          return ''
        end

        -- find current buffer in Harpoon list
        local current_idx
        for idx, item in ipairs(items) do
          local item_abs = normalize(item.value)
          if item_abs == current_abs then
            current_idx = idx
            break
          end
        end

        -- truncated: show less info
        if statusline.is_truncated(args.trunc_width) then
          if current_idx then
            return string.format('%s %d', icon, current_idx)
          end
        end

        -- full: index/total if current file is in Harpoon, otherwise just count
        if current_idx then
          return string.format('%s %d', icon, current_idx, total)
        end
      end

      local function my_section_location(args)
        if statusline.is_truncated(args.trunc_width) then
          return '%l│%v'
        end
        return '%2l/%L│%2v'
      end

      local function my_active_content()
        -- `MiniStatusline` global is set by the plugin, but we already have `statusline`
        local mode, mode_hl = statusline.section_mode { trunc_width = 120 }
        local tab = my_section_tab { trunc_width = 75 }
        local harpoon = my_section_harpoon { trunc_width = 75 }
        local git = statusline.section_git { trunc_width = 40 }
        local diff = statusline.section_diff { trunc_width = 75 }
        local diagnostics = statusline.section_diagnostics { trunc_width = 75 }
        local lsp = statusline.section_lsp { trunc_width = 75 }
        local filename = statusline.section_filename { trunc_width = 140 }
        local fileinfo = statusline.section_fileinfo { trunc_width = 120 }
        local location = my_section_location { trunc_width = 90 }

        return statusline.combine_groups {
          { hl = mode_hl, strings = { mode } },
          { hl = 'MiniStatuslineDevinfo', strings = { git, diff, diagnostics, lsp } },
          { hl = 'MiniStatuslineTab', strings = { tab } },
          { hl = 'MiniStatuslineHarpoon', strings = { harpoon } },
          '%<', -- Mark general truncate point
          { hl = 'MiniStatuslineFilename', strings = { filename } },
          '%=', -- End left alignment
          { hl = 'MiniStatuslineFileinfo', strings = { fileinfo } },
          { hl = mode_hl, strings = { location } },
        }
      end

      statusline.setup {
        content = { active = my_active_content },
        use_icons = vim.g.have_nerd_font,
      }
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
