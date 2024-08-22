-- NOTE: Plugins can specify dependencies.
--
-- The dependencies are proper plugin specifications as well - anything
-- you do for a plugin at the top level, you can do for a dependency.
--
-- Use the `dependencies` key to specify the dependencies of a particular plugin

return {
  { -- Fuzzy Finder (files, lsp, etc)
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      { -- If encountering errors, see telescope-fzf-native README for installation instructions
        'nvim-telescope/telescope-fzf-native.nvim',

        -- `build` is used to run some command when the plugin is installed/updated.
        -- This is only run then, not every time Neovim starts up.
        build = 'make',

        -- `cond` is a condition used to determine whether this plugin should be
        -- installed and loaded.
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      -- Useful for getting pretty icons, but requires a Nerd Font.
      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      -- Telescope is a fuzzy finder that comes with a lot of different things that
      -- it can fuzzy find! It's more than just a "file finder", it can search
      -- many different aspects of Neovim, your workspace, LSP, and more!
      --
      -- The easiest way to use Telescope, is to start by doing something like:
      --  :Telescope help_tags
      --
      -- After running this command, a window will open up and you're able to
      -- type in the prompt window. You'll see a list of `help_tags` options and
      -- a corresponding preview of the help.
      --
      -- Two important keymaps to use while in Telescope are:
      --  - Insert mode: <c-/>
      --  - Normal mode: ?
      --
      -- This opens a window that shows you all of the keymaps for the current
      -- Telescope picker. This is really useful to discover what Telescope can
      -- do as well as how to actually do it!

      -- [[ Configure Telescope ]]
      -- See `:help telescope` and `:help telescope.setup()`
      require('telescope').setup {
        -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        defaults = {
          mappings = {
            i = {
              ['<C-Enter>'] = 'to_fuzzy_refine',
              ['<C-p>'] = require('telescope.actions.layout').toggle_preview,
            },
            n = {
              ['<C-p>'] = require('telescope.actions.layout').toggle_preview,
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
      vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[s]earch [f]iles by name' })
      vim.keymap.set('n', '<leader>sF', builtin.git_files, { desc = '[s]earch [F]iles on Git by name' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[s]earch grep /w current [W]ord' })
      vim.keymap.set('n', '<leader>sG', function()
        builtin.live_grep { additional_args = { '-uu' } }
      end, { desc = '[s]earch [G]rep in All Files w/ hidden' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[s]earch [g]rep in All Files' })
      vim.keymap.set('n', '<leader>st', builtin.builtin, { desc = '[s]earch [t]elescope commands' })
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[s]earch [h]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[s]earch [k]eymaps' })
      vim.keymap.set('n', '<leader>sD', builtin.diagnostics, { desc = '[s]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[s]earch [r]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[s]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] List existing buffers' })

      -- Show all diagnostics on current line in floating window
      vim.api.nvim_set_keymap('n', '<Leader>sd', ':lua vim.diagnostic.open_float()<CR>', { noremap = true, silent = true, desc = '[show] line [d]iagnostics' })
      -- Go to next diagnostic (if there are multiple on the same line, only shows
      -- one at a time in the floating window)
      vim.api.nvim_set_keymap('n', '<Leader>n', ':lua vim.diagnostic.goto_next()<CR>', { noremap = true, silent = true })
      -- Go to prev diagnostic (if there are multiple on the same line, only shows
      -- one at a time in the floating window)
      vim.api.nvim_set_keymap('n', '<Leader>p', ':lua vim.diagnostic.goto_prev()<CR>', { noremap = true, silent = true })
      -- Slightly advanced example of overriding default behavior and theme
      vim.keymap.set('n', '<leader>/', function()
        -- You can pass additional configuration to Telescope to change the theme, layout, etc.
        builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          previewer = false,
        })
      end, { desc = '[/] Fuzzily search in current buffer' })

      -- It's also possible to pass additional configuration options.
      --  See `:help telescope.builtin.live_grep()` for information about particular keys
      vim.keymap.set('n', '<leader>s/', function()
        builtin.live_grep {
          grep_open_files = true,
          prompt_title = 'Live Grep in Open Files',
        }
      end, { desc = '[s]earch [/] grep in Open Files' })

      -- Shortcut for searching your Neovim configuration files
      vim.keymap.set('n', '<leader>sn', function()
        builtin.find_files { cwd = vim.fn.stdpath 'config' }
      end, { desc = '[s]earch [N]eovim files' })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
