return {
  {
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
      -- { 'echasnovski/mini.icons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- To know all available keymaps inside Telescope:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      local file_ignore_patterns = { 'node_modules', '.git' }

      require('telescope').setup {
        defaults = {
          file_ignore_patterns = file_ignore_patterns,
          mappings = {
            i = {
              ['<C-Enter>'] = 'to_fuzzy_refine',
              -- ['<C-p>'] = require('telescope.actions.layout').toggle_preview,
              ['<C-d>'] = require('telescope.actions').delete_buffer,
            },
            n = {
              ['<C-p>'] = require('telescope.actions.layout').toggle_preview,
              ['<C-d>'] = require('telescope.actions').delete_buffer,
            },
          },
          layout_config = {
            horizontal = {
              preview_cutoff = 150,
            },
          },
        },
        pickers = {
          buffers = {
            theme = 'dropdown',
            path_display = { 'smart' },
          },
          find_files = {
            follow = true,
          },
          grep_string = {
            layout_strategy = 'vertical',
          },
          live_grep = {
            layout_strategy = 'vertical',
          },
        },
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      -- Enable Telescope extensions if they are installed
      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')

      -- builtin and utils
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sc', builtin.builtin, { desc = 'Telescope Commands' })
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = 'Help' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = 'Keymaps' })
      vim.keymap.set('n', '<leader>s.', builtin.resume, { desc = 'Resume last search' })
      -- builtin.command_history,
      vim.keymap.set('n', '<leader>:', function()
        builtin.command_history(require('telescope.themes').get_dropdown {})
      end, { desc = 'Command History' })

      -- files
      vim.keymap.set('n', '<Leader>f', function()
        require('telescope.builtin').find_files { hidden = true }
      end, { desc = 'Find Project files' })
      vim.keymap.set('n', '<leader>F', builtin.git_files, { desc = 'Find Git files' })

      vim.keymap.set('n', '<leader>sr', function()
        builtin.oldfiles { layout_strategy = 'vertical' }
      end, { desc = 'Recently opened Files' })
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = 'Neovim Files' })

      -- grep
      vim.keymap.set('n', '<leader>sw', function()
        local word = vim.fn.expand '<cword>'
        builtin.grep_string { search = word }
      end, { desc = 'Grep word in Project Files' })
      vim.keymap.set('n', '<leader>sW', function()
        local word = vim.fn.expand '<cWORD>'
        builtin.grep_string { search = word }
      end, { desc = 'Grep WORD in Project Files' })
      vim.keymap.set('n', '<leader>g', function()
        builtin.live_grep { file_ignore_patterns = file_ignore_patterns, additional_args = { '-uu' } }
      end, { desc = 'Grep in Project Files' })
      vim.keymap.set('n', '<leader>G', function()
        builtin.live_grep { prompt_title = 'Live Grep [respect hidden]' }
      end, { desc = 'Grep in Project Files (nohid)' })

      -- buffer
      vim.keymap.set('n', '<leader>b', function()
        -- builtin.buffers(require('telescope.themes').get_dropdown {
        --   previewer = true,
        --   initial_mode = 'normal',
        --   show_all_buffers = true,
        -- })
        -- builtin.buffers { layout_strategy = 'vertical', layout_config = { width = 0.5 }, initial_mode = 'normal' }
        builtin.buffers {
          show_all_buffers = true,
          -- initial_mode = 'normal',
        }
      end, { desc = 'List opened Buffers' })
      vim.keymap.set('n', '<leader>s/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          previewer = false,
        })
      end, { desc = 'Fuzzy search in Current Buffer' })
      vim.keymap.set('n', '<leader>sb', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Buffers',
        }
      end, { desc = 'Grep in Open Buffers' })

      -- Diagnostics:
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = 'Diagnostics' })
      -- Natively we have:
      --  `]d`/`[d` to go to next/prev diagnostic (w/o opening floating window)
      --  `<C-w>d` to open floating window
      -- Let's add a keymap to navigate AND open the floating window
      vim.api.nvim_set_keymap('n', '[D', ':lua vim.diagnostic.goto_prev()<CR>', { noremap = true, silent = true, desc = 'Jump and show previous diagnostic)' })
      vim.api.nvim_set_keymap('n', ']D', ':lua vim.diagnostic.goto_next()<CR>', { noremap = true, silent = true, desc = 'Jump and show next diagnostic' })
    end,
  },
}

-- vim: ts=2 sts=2 sw=2 et
