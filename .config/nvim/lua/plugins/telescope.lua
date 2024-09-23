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
              ['<C-p>'] = require('telescope.actions.layout').toggle_preview,
              ['<C-d>'] = require('telescope.actions').delete_buffer,
            },
            n = {
              ['<C-p>'] = require('telescope.actions.layout').toggle_preview,
              ['<C-d>'] = require('telescope.actions').delete_buffer,
            },
          },
          layout_config = {
            horizontal = {
              preview_cutoff = 120,
            },
          },
        },
        pickers = {
          find_files = {
            follow = true,
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

      -- See `:help telescope.builtin`
      local builtin = require 'telescope.builtin'
      vim.keymap.set('n', '<leader>sc', builtin.builtin, { desc = 'Telescope [C]ommands' })
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[K]eymaps' })
      -- files
      -- vim.keymap.set('n', '<leader>f', builtin.find_files, { desc = 'Find [F]ile by Name' })
      vim.keymap.set('n', '<leader>F', builtin.git_files, { desc = 'Find git [F]ile by Name' })
      -- vim.api.nvim_set_keymap('n', '<Leader>F', ':lua require"telescope.builtin".find_files({ hidden = true })<CR>', {noremap = true, silent = true, desc = 'Find [F]ile by name (w/ hidden)'})
      vim.keymap.set('n', '<Leader>f', function()
        require('telescope.builtin').find_files { hidden = true }
      end, { desc = 'Find [F]ile by Name' })

      vim.keymap.set('n', '<leader>sr', builtin.oldfiles, { desc = '[R]ecently opened Files' })
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[N]eovim Files' })
      -- grep
      vim.keymap.set('n', '<leader>sw', function()
        local word = vim.fn.expand '<cword>'
        builtin.grep_string { search = word }
      end, { desc = 'Grep word in Project Files' })
      vim.keymap.set('n', '<leader>sW', function()
        local word = vim.fn.expand '<cWORD>'
        builtin.grep_string { search = word }
      end, { desc = 'Grep WORD in Project Files' })
      -- vim.keymap.set('n', '<leader>*', builtin.grep_string, { desc = 'Grep Selection in Project Files' })
      vim.keymap.set('n', '<leader>G', builtin.live_grep, { desc = '[G]rep in Project Files' })
      vim.keymap.set('n', '<leader>g', function()
        builtin.live_grep { file_ignore_patterns = file_ignore_patterns, additional_args = { '-uu' }, prompt_title = 'Live Grep (w/ Hidden)' }
      end, { desc = '[G]rep in Project Files (w/ Hidden)' })
      vim.keymap.set('n', '<leader>.', builtin.resume, { desc = 'Resume last search' })
      -- vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] List opened Buffers' })
      vim.keymap.set('n', '<leader>b', builtin.buffers, { desc = 'List opened [B]uffers' })
      vim.keymap.set('n', '<leader>/', function()
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          previewer = false,
        })
      end, { desc = 'Fuzzy search in Current Buffer' })
      vim.keymap.set('n', '<leader>sb', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open [B]uffers',
        }
      end, { desc = 'Grep in Open Buffers' })

      -- Diagnostics:
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[D]iagnostics' })
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
