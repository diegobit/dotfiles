return {
  'ibhagwan/fzf-lua',
  event = 'VimEnter',
  dependencies = {
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    local fzf = require 'fzf-lua'
    local actions = require 'fzf-lua.actions'

    fzf.setup {
      ui_select = true,
      winopts = {
        height = 0.9,
        width = 0.85,
        preview = {
          layout = 'vertical',
          vertical = 'down:45%',
        },
      },
      files = {
        hidden = true,
        follow = true,
        fd_opts = [[--color=never --type f --type l --hidden --follow --exclude .git --exclude node_modules --exclude .obsidian]],
        rg_opts = [[--color=never --files --hidden --follow -g '!.git' -g '!node_modules' -g '!.obsidian']],
      },
      grep = {
        rg_opts = [[--column --line-number --no-heading --color=always --smart-case --max-columns=4096 --glob '!.git' --glob '!node_modules' --glob '!.obsidian' -e]],
      },
      buffers = {
        actions = {
          ['ctrl-x'] = { fn = actions.buf_del, reload = true },
        },
      },
    }

    -- Keep the outer keymaps stable and accept fzf-lua's own picker UX.
    vim.keymap.set('n', '<leader><leader>', fzf.builtin, { desc = 'FzfLua Builtins' })
    vim.keymap.set('n', '<leader>.', fzf.resume, { desc = 'Resume Last Search' })
    vim.keymap.set('n', '<leader>:', fzf.command_history, { desc = 'Command History' })

    vim.keymap.set('n', '<leader>f', function()
      fzf.files {
        hidden = true,
      }
    end, { desc = 'Find Project Files' })
    vim.keymap.set('n', '<leader>F', function()
      fzf.files {
        hidden = true,
        no_ignore = true,
      }
    end, { desc = 'Find Project Files (All)' })
    vim.keymap.set('n', '<leader>vf', fzf.vcs_files, { desc = 'Find VCS files' })
    vim.keymap.set('n', '<leader>vs', fzf.git_status, { desc = 'Git Status' })
    vim.keymap.set('n', '<leader>r', fzf.oldfiles, { desc = 'Recently Opened Files' })

    vim.keymap.set('n', '<leader>w', fzf.grep_cword, { desc = 'Grep word in Project Files' })
    vim.keymap.set('n', '<leader>W', fzf.grep_cWORD, { desc = 'Grep WORD in Project Files' })
    vim.keymap.set('n', '<leader>g', function()
      fzf.live_grep {
        hidden = true,
      }
    end, { desc = 'Grep in Project Files' })
    vim.keymap.set('n', '<leader>G', function()
      fzf.live_grep {
        hidden = true,
        no_ignore = true,
      }
    end, { desc = 'Grep in Project Files (all)' })

    vim.keymap.set('n', '<leader>b', fzf.buffers, { desc = 'Buffers' })
    vim.keymap.set('n', '<leader>D', fzf.diagnostics_workspace, { desc = 'Diagnostics' })
    vim.keymap.set('n', '<leader>T', fzf.tabs, { desc = 'Tabs' })
  end,
}
