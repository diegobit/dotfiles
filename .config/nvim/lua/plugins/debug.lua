return {
  'mfussenegger/nvim-dap',
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',
    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',
    -- Installs the debug adapters
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    -- 'leoluz/nvim-dap-go',
  },
  keys = function(_, keys)
    local dap = require 'dap'
    local dapui = require 'dapui'
    return {
      { '<leader>cc', dap.continue, desc = 'Start/Continue (F5)' },
      { '<F5>', dap.continue, desc = 'Debug: Start/Continue' },
      { '<leader>ci', dap.step_into, desc = 'Step Into (F1)' },
      { '<F1>', dap.step_into, desc = 'Debug: Step Into' },
      { '<leader>cv', dap.step_over, desc = 'Step over (F2)' },
      { '<F2>', dap.step_over, desc = 'Debug: Step Over' },
      { '<leader>co', dap.step_out, desc = 'Step Out (F3)' },
      { '<F3>', dap.step_out, desc = 'Debug: Step Out' },
      { '<leader>cb', dap.toggle_breakpoint, desc = 'Toggle Breakpoint' },
      {
        '<leader>db',
        function()
          dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
        end,
        desc = 'Set Breakpoint',
      },
      -- Toggle to see last session result. Without this, you can't see
      -- session output in case of unhandled exception.
      { '<leader>cl', dapui.toggle, desc = 'See Last session result (F7)' },
      { '<F7>', dapui.toggle, desc = 'Debug: See last session result.' },
      unpack(keys),
    }
  end,
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'delve',
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
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

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Install golang specific config
    require('dap-go').setup {
      delve = {},
    }
  end,
}
