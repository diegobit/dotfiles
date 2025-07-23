local function read_api_key(path)
  local expanded = vim.fn.expand(path)

  local f, err = io.open(expanded, 'r')
  if not f then
    vim.notify(("Couldn't open API key file %s: %s"):format(expanded, err), vim.log.levels.ERROR)
    return nil
  end

  local key = f:read '*l' or '' -- protect against nil
  f:close()
  return vim.trim(key)
end

return {
  'olimorris/codecompanion.nvim',
  opts = {},
  event = 'VeryLazy',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'ravitemer/mcphub.nvim',
    'j-hui/fidget.nvim',
  },
  config = function()
    require('codecompanion').setup {
      strategies = {
        chat = {
          adapter = 'gemini',
        },
        inline = {
          adapter = 'gemini',
        },
        cmd = {
          adapter = 'gemini',
        },
      },
      adapters = {
        gemini = function()
          return require('codecompanion.adapters').extend('gemini', {
            env = {
              api_key = read_api_key '~/.gemini_api_key',
            },
            schema = {
              model = {
                default = 'gemini-2.5-flash-preview-05-20',
              },
            },
          })
        end,
      },
    }

    local function keymapOptions(desc)
      return {
        noremap = true,
        silent = true,
        nowait = true,
        desc = desc,
      }
    end

    vim.keymap.set({ 'n' }, '<leader>tc', '<cmd>CodeCompanionChat Toggle<cr>', keymapOptions 'Toggle CodeCompanion Chat')
    vim.keymap.set({ 'n' }, '<leader>al', '<cmd>CodeCompanion /lsp<cr>', keymapOptions 'Explain LSP errors in current line')
    vim.keymap.set({ 'v' }, '<leader>a', '<cmd>CodeCompanionChat Add<cr>', keymapOptions 'Add selection to CodeCompanion Chat')
  end,
  -- init = function()
  --   require('plugins.codecompanion.fidget-spinner-inline'):init()
  -- end,
}
