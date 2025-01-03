return {
  'mfussenegger/nvim-dap',
  lazy = true,
  cmd = { 'DapContinue', 'DapInstall', 'DapLoadLunchJSON', 'DapNew' },
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',
    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',
    -- Installs the debug adapters
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
    'mfussenegger/nvim-dap-python',
  },
  keys = function(_, keys)
    return {
      {
        '<leader>cc',
        function()
          require('dap').continue()
        end,
        desc = 'Start/Continue [F5] (DAP)',
      },
      {
        '<F5>',
        function()
          require('dap').continue()
        end,
        desc = 'Start/Continue (DAP)',
      },

      {
        '<leader>c.',
        function()
          require('dap').disconnect { terminateDebuggee = true }
          -- require('dap').close()
        end,
        desc = 'Stop (DAP)',
      },

      {
        '<leader>ci',
        function()
          require('dap').step_into()
        end,
        desc = 'Step Into [F1] (DAP)',
      },
      {
        '<F1>',
        function()
          require('dap').step_into()
        end,
        desc = 'Step Into (DAP)',
      },

      {
        '<leader>cv',
        function()
          require('dap').step_over()
        end,
        desc = 'Step Over [F2] (DAP)',
      },
      {
        '<F2>',
        function()
          require('dap').step_over()
        end,
        desc = 'Step Over (DAP)',
      },

      {
        '<leader>co',
        function()
          require('dap').step_out()
        end,
        desc = 'Step Out [F3] (DAP)',
      },
      {
        '<F3>',
        function()
          require('dap').step_out()
        end,
        desc = 'Step Out (DAP)',
      },

      {
        '<leader>cb',
        function()
          require('dap').toggle_breakpoint()
        end,
        desc = 'Toggle Breakpoint (DAP)',
      },
      {
        '<leader>cB',
        function()
          require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
        end,
        desc = 'Set Breakpoint w/ Cond. (DAP)',
      },
      {
        '<leader>ce',
        function()
          require('dap').set_exception_breakpoints()
        end,
        desc = 'Set Exception Breakpoint (DAP)',
      },
      {
        '<leader>cC',
        function()
          require('dap').clear_breakpoints()
        end,
        desc = 'Clear Breakpoints (DAP)',
      },

      {
        '<leader>ck',
        function()
          require('dap').up()
        end,
        desc = 'Go Up in Stacktrace (DAP)',
      },
      {
        '<leader>cj',
        function()
          require('dap').down()
        end,
        desc = 'Go Down in Stacktrace (DAP)',
      },

      -- Toggle to see last session result. Without this, you can't see
      -- session output in case of unhandled exception.
      {
        '<leader>cl',
        function()
          require('dapui').toggle()
        end,
        desc = 'See Last Session [F7] (DAP)',
      },
      {
        '<F7>',
        function()
          require('dapui').toggle()
        end,
        desc = 'See last session result. (DAP)',
      },
      unpack(keys),
    }
  end,
  config = function()
    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        -- 'leoluz/nvim-dap-go',
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    require('dapui').setup {
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    require('dap').listeners.after.event_initialized['dapui_config'] = require('dapui').open
    require('dap').listeners.before.event_terminated['dapui_config'] = require('dapui').close
    require('dap').listeners.before.event_exited['dapui_config'] = require('dapui').close

    -- Install golang specific config
    require('dap-go').setup {
      delve = {},
    }
    require('dap-python').setup '/Users/diego/.pyenv/versions/pynvim/bin/python'
    table.insert(require('dap').configurations.python, {
      type = 'python',
      request = 'launch',
      name = 'Module',
      console = 'integratedTerminal',
      module = 'src', -- edit this to be your app's main module
      cwd = '${workspaceFolder}',
    })
  end,
}
