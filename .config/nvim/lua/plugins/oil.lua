return {
  'stevearc/oil.nvim',
  opts = {},
  event = 'VeryLazy',
  -- Optional dependencies
  -- dependencies = { { 'echasnovski/mini.icons', opts = {} } },
  dependencies = { 'nvim-tree/nvim-web-devicons' }, -- use if prefer nvim-web-devicons
  config = function()
    require('oil').setup {
      columns = { 'icon' },
      keymaps = {
        ['<C-h>'] = false,
        ['<C-l>'] = false,
        ['<C-s>'] = { 'actions.select', opts = { horizontal = true, vertical = false }, desc = 'Open the entry in a horizontal split' },
        ['<C-enter>'] = { 'actions.select', opts = { vertical = true }, desc = 'Open the entry in a vertical split' },
        ['<C-r>'] = { 'actions.refresh', desc = 'Refresh the tree' },
      },
      view_options = {
        show_hidden = true,
      },
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
    }
    vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })

    -- Replace Netrw commands
    local explore = function()
      require('oil').open()
    end

    local vexplore = function(opts)
      local size = tonumber(opts.args)
      -- local current_win = vim.api.nvim_get_current_win()
      vim.cmd 'vsplit'
      -- vim.cmd 'wincmd H'
      if size ~= nil then
        vim.cmd('vertical resize ' .. size)
      end
      require('oil').open()
      -- vim.api.nvim_set_current_win(current_win)
    end

    local sexplore = function(opts)
      local size = tonumber(opts.args)
      -- local current_win = vim.api.nvim_get_current_win()
      vim.cmd 'split'
      -- vim.cmd 'wincmd K'
      if size ~= nil then
        vim.cmd('horizontal resize ' .. size)
      end
      require('oil').open()
      -- vim.api.nvim_set_current_win(current_win)
    end

    vim.api.nvim_create_user_command('Ex', explore, {})
    vim.api.nvim_create_user_command('Explore', explore, {})

    vim.api.nvim_create_user_command('Vex', vexplore, {})
    vim.api.nvim_create_user_command('Vexplore', vexplore, {})

    vim.api.nvim_create_user_command('Sex', sexplore, {})
    vim.api.nvim_create_user_command('Sexplore', sexplore, {})

    vim.keymap.set('n', '<leader>sf', function()
      require('telescope.builtin').find_files {
        cwd = require('oil').get_current_dir(),
        hidden = true,
      }
    end, { desc = '[F]ind files in explorer cwd (Oil)' })
    local file_ignore_patterns = { 'node_modules', '.git' }
    vim.keymap.set('n', '<leader>sg', function()
      require('telescope.builtin').live_grep {
        cwd = require('oil').get_current_dir(),
        file_ignore_patterns = file_ignore_patterns,
        additional_args = { '-uu' },
        prompt_title = 'Live Grep in cwd',
      }
    end, { desc = 'Grep in explorer cwd (Oil)' })
  end,
}
