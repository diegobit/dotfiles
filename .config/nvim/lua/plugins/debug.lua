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
    { 'mfussenegger/nvim-dap-python', ft = 'python' },
  },
  keys = function(_, keys)
    return {
      {
        '<leader>dr',
        function()
          require('dap').continue()
        end,
        desc = 'Run (Start/Continue) [F5]',
      },
      {
        '<F5>',
        function()
          require('dap').continue()
        end,
        desc = 'Start/Continue',
      },

      {
        '<leader>d.',
        function()
          require('dap').disconnect { terminateDebuggee = true }
          -- require('dap').close()
        end,
        desc = 'Stop',
      },

      {
        '<leader>di',
        function()
          require('dap').step_into()
        end,
        desc = 'Step Into [F8]',
      },
      {
        '<F8>',
        function()
          require('dap').step_into()
        end,
        desc = 'Step Into',
      },

      {
        '<leader>dv',
        function()
          require('dap').step_over()
        end,
        desc = 'Step oVer [F7]',
      },
      {
        '<F7>',
        function()
          require('dap').step_over()
        end,
        desc = 'Step Over',
      },

      {
        '<leader>do',
        function()
          require('dap').step_out()
        end,
        desc = 'Step Out [F9]',
      },
      {
        '<F9>',
        function()
          require('dap').step_out()
        end,
        desc = 'Step Out',
      },

      {
        '<leader>dt',
        function()
          require('dap').toggle_breakpoint()
        end,
        desc = 'Toggle Breakpoint',
      },
      {
        '<leader>db',
        function()
          require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
        end,
        desc = 'Set Breakpoint w/ Cond.',
      },
      {
        '<leader>de',
        function()
          require('dap').set_exception_breakpoints()
        end,
        desc = 'Set Exception Breakpoint',
      },
      {
        '<leader>dc',
        function()
          require('dap').clear_breakpoints()
        end,
        desc = 'Clear Breakpoints',
      },

      {
        '<leader>dk',
        function()
          require('dap').up()
        end,
        desc = 'Go Up in Stacktrace',
      },
      {
        '<leader>dj',
        function()
          require('dap').down()
        end,
        desc = 'Go Down in Stacktrace',
      },

      -- Toggle to see last session result. Without this, you can't see
      -- session output in case of unhandled exception.
      {
        '<leader>dl',
        function()
          require('dapui').toggle()
        end,
        desc = 'See Last Session',
      },
      -- {
      --   '<F7>',
      --   function()
      --     require('dapui').toggle()
      --   end,
      --   desc = 'See last session result.',
      -- },
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
    require('dap-python').setup("uv")
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
