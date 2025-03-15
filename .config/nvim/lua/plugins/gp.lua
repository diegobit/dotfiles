return {
  'robitx/gp.nvim',
  event = 'VeryLazy',
  config = function()
    local function trim(s)
      return s:gsub('^%s*(.-)%s*$', '%1')
    end

    local system_prompt_code = trim [[
    You are the best AI working as a code editor.
      - Strive for excellent code, as simple as possible, both in reading it for a human, and in executing it in a computer (eg. non-pessimization). Avoid overengineering.
      - If I ask you for simple changes or to add something, try to make the smallest change to the existing code.
      - Please AVOID COMMENTARY OUTSIDE OF THE SNIPPET RESPONSE.
      - START AND END YOUR ANSWER WITH:\n\n```
    ]]

    local system_prompt_chat = trim [[
    You are the best general AI assistant answering code related questions.

    Your guidelines:
      - Ask question if you need clarification to provide better answer.
      - You strive for code to be excellent.
      - Code should be be as simple as possible, both in reading it for a human, and in executing it in a computer. Avoid overengineering. Eg. non-pessimization is a good principle.
      - Your answers are concise. Don't repeat yourself.
    ]]

    local system_prompt_chat_cot = trim [[
    You are the best general AI assistant answering code related questions.

    Your guidelines:
      - Ask question if you need clarification to provide better answer.
      - Think deeply and carefully from first principles step by step. Enclose your reasoning between <think> </think> tags. Zoom out first to see the big picture and then zoom in to details.
      - You strive for code to be excellent.
      - Code should be be as simple as possible, both in reading it for a human, and in executing it in a computer. Avoid overengineering. Eg. non-pessimization is a good principle.
    ]]

    local conf = {
      -- For customization, refer to Install > Configuration in the Documentation/Readme
      -- default agent names set during startup, if nil last used agent is used
      default_command_agent = 'Gemini Chat Pro',
      default_chat_agent = 'Gemini Code Flash',

      agents = {
        {
          name = 'ChatGPT4o-mini',
          disable = true,
        },
        {
          name = 'ChatGPT4o',
          disable = true,
        },
        {
          name = 'CodeGPT4o-mini',
          disable = true,
        },
        {
          name = 'CodeGPT4o',
          disable = true,
        },
        {
          name = 'ChatGemini',
          disable = true,
        },
        {
          name = 'CodeGemini',
          disable = true,
        },
        {
          provider = 'googleai',
          name = 'Gemini Code Flash',
          chat = false,
          command = true,
          model = { model = 'gemini-2.0-flash-exp', temperature = 0.0, top_p = 1 },
          system_prompt = system_prompt_code, --require('gp.defaults').code_system_prompt,
        },
        {
          provider = 'googleai',
          name = 'Gemini Code Pro',
          chat = false,
          command = true,
          model = { model = 'gemini-2.0-pro-exp', temperature = 0.0, top_p = 1 },
          system_prompt = system_prompt_code, --require('gp.defaults').code_system_prompt,
        },
        {
          provider = 'googleai',
          name = 'Gemini Chat Flash',
          chat = true,
          command = false,
          model = { model = 'gemini-2.0-flash-exp', temperature = 0.0, top_p = 1 },
          system_prompt = system_prompt_chat, -- require('gp.defaults').chat_system_prompt,
        },
        {
          provider = 'googleai',
          name = 'Gemini Chat Pro-CoT',
          chat = true,
          command = false,
          model = { model = 'gemini-2.0-pro-exp', temperature = 0.0, top_p = 1 },
          system_prompt = system_prompt_chat_cot, -- require('gp.defaults').chat_system_prompt,
        },
      },

      providers = {
        googleai = {
          endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/{{model}}:streamGenerateContent?key={{secret}}',
          secret = os.getenv 'GOOGLE_API_KEY',
        },
      },

      -- chat_shortcut_respond = { modes = { 'n', 'v', 'x' }, shortcut = '<leader>ag' },
      -- chat_shortcut_delete = { modes = { 'n', 'v', 'x' }, shortcut = '<leader>ad' },
      -- chat_shortcut_stop = { modes = { 'n', 'v', 'x' }, shortcut = '<leader>a.' },
      -- chat_shortcut_new = { modes = { 'n', 'v', 'x' }, shortcut = '<leader>ac' },
      ---- the <leader>key work in normal mode
      chat_shortcut_respond = { modes = { 'i' }, shortcut = '<C-g>' },
      chat_shortcut_delete = { modes = { 'i' }, shortcut = '<C-d>' },
      chat_shortcut_stop = { modes = { 'i' }, shortcut = '<C-.>' },
      chat_shortcut_new = { modes = { 'i' }, shortcut = '<C-c>' },
    }
    require('gp').setup(conf)

    -- Setup shortcuts here (see Usage > Shortcuts in the Documentation/Readme)
    local function keymapOptions(desc)
      return {
        noremap = true,
        silent = true,
        nowait = true,
        desc = 'GPT prompt ' .. desc,
      }
    end

    -- Chat commands
    vim.keymap.set({ 'n' }, '<leader>ac', '<cmd>GpChatNew<cr>', keymapOptions 'New Chat')
    vim.keymap.set({ 'n' }, '<leader>tc', '<cmd>GpChatToggle<cr>', keymapOptions 'AI Chat (gp)')
    vim.keymap.set({ 'n' }, '<leader>af', '<cmd>GpChatFinder<cr>', keymapOptions 'Find in past chats')

    vim.keymap.set('v', '<leader>ac', ":<C-u>'<,'>GpChatNew<cr>", keymapOptions 'Visual Chat New')
    vim.keymap.set('v', '<leader>ap', ":<C-u>'<,'>GpChatPaste<cr>", keymapOptions 'Visual Chat Paste')
    vim.keymap.set('v', '<leader>tc', ":<C-u>'<,'>GpChatToggle<cr>", keymapOptions 'Visual AI Chat (gp)')

    vim.keymap.set({ 'n' }, '<leader>as', '<cmd>GpChatNew split<cr>', keymapOptions 'New Chat split')
    vim.keymap.set({ 'n' }, '<leader>av', '<cmd>GpChatNew vsplit<cr>', keymapOptions 'New Chat vsplit')
    vim.keymap.set({ 'n' }, '<leader>at', '<cmd>GpChatNew tabnew<cr>', keymapOptions 'New Chat tabnew')

    vim.keymap.set('v', '<leader>as', ":<C-u>'<,'>GpChatNew split<cr>", keymapOptions 'Visual Chat New split')
    vim.keymap.set('v', '<leader>av', ":<C-u>'<,'>GpChatNew vsplit<cr>", keymapOptions 'Visual Chat New vsplit')
    vim.keymap.set('v', '<leader>at', ":<C-u>'<,'>GpChatNew tabnew<cr>", keymapOptions 'Visual Chat New tabnew')

    -- Prompt commands
    vim.keymap.set({ 'n' }, '<leader>ar', '<cmd>GpRewrite<cr>', keymapOptions 'Inline Rewrite')
    vim.keymap.set({ 'n' }, '<leader>aa', '<cmd>GpAppend<cr>', keymapOptions 'Append (after)')
    vim.keymap.set({ 'n' }, '<leader>ab', '<cmd>GpPrepend<cr>', keymapOptions 'Prepend (before)')

    vim.keymap.set('v', '<leader>ar', ":<C-u>'<,'>GpRewrite<cr>", keymapOptions 'Visual Rewrite')
    vim.keymap.set('v', '<leader>aa', ":<C-u>'<,'>GpAppend<cr>", keymapOptions 'Visual Append (after)')
    vim.keymap.set('v', '<leader>ab', ":<C-u>'<,'>GpPrepend<cr>", keymapOptions 'Visual Prepend (before)')
    vim.keymap.set('v', '<leader>ai', ":<C-u>'<,'>GpImplement<cr>", keymapOptions 'Implement selection')

    vim.keymap.set({ 'n' }, '<leader>aip', '<cmd>GpPopup<cr>', keymapOptions 'New Popup (GpPopup)')
    vim.keymap.set({ 'n' }, '<leader>aie', '<cmd>GpEnew<cr>', keymapOptions 'This window (GpEnew)')
    vim.keymap.set({ 'n' }, '<leader>ain', '<cmd>GpNew<cr>', keymapOptions 'New split window (GpNew)')
    vim.keymap.set({ 'n' }, '<leader>aiv', '<cmd>GpVnew<cr>', keymapOptions 'New vertical split (GpVnew)')
    vim.keymap.set({ 'n' }, '<leader>ait', '<cmd>GpTabnew<cr>', keymapOptions 'New tab (GpTabnew)')

    vim.keymap.set('v', '<leader>aip', ":<C-u>'<,'>GpPopup<cr>", keymapOptions 'Visual New Popup (GpPopup)')
    vim.keymap.set('v', '<leader>aie', ":<C-u>'<,'>GpEnew<cr>", keymapOptions 'Visual This window (GpEnew)')
    vim.keymap.set('v', '<leader>ain', ":<C-u>'<,'>GpNew<cr>", keymapOptions 'Visual New split window (GpNew)')
    vim.keymap.set('v', '<leader>aiv', ":<C-u>'<,'>GpVnew<cr>", keymapOptions 'Visual New vertical split (GpVnew)')
    vim.keymap.set('v', '<leader>ait', ":<C-u>'<,'>GpTabnew<cr>", keymapOptions 'Visual New tab (GpTabnew)')

    vim.keymap.set({ 'n' }, '<leader>ax', '<cmd>GpContext<cr>', keymapOptions 'Edit Context')
    vim.keymap.set('v', '<leader>ax', ":<C-u>'<,'>GpContext<cr>", keymapOptions 'Visual Edit Context')

    vim.keymap.set({ 'n', 'v', 'x' }, '<leader>a.', '<cmd>GpStop<cr>', keymapOptions 'Stop')
    vim.keymap.set({ 'n', 'v', 'x' }, '<leader>an', '<cmd>GpNextAgent<cr>', keymapOptions 'Next Agent')

    -- Inside Chat commands
    vim.keymap.set({ 'n', 'v' }, '<leader>ag', '<cmd>GpChatRespond<cr>', keymapOptions 'Generate Response')
    vim.keymap.set({ 'n', 'v' }, '<leader>ad', '<cmd>GpChatDelete<cr>', keymapOptions 'Delete Chat')

    -- optional Whisper commands with prefix <leader>aw
    -- vim.keymap.set({ 'n', 'i' }, '<leader>aww', '<cmd>GpWhisper<cr>', keymapOptions 'Whisper')
    -- vim.keymap.set('v', '<leader>aww', ":<C-u>'<,'>GpWhisper<cr>", keymapOptions 'Visual Whisper')
    --
    -- vim.keymap.set({ 'n', 'i' }, '<leader>awr', '<cmd>GpWhisperRewrite<cr>', keymapOptions 'Whisper Inline Rewrite')
    -- vim.keymap.set({ 'n', 'i' }, '<leader>awa', '<cmd>GpWhisperAppend<cr>', keymapOptions 'Whisper Append (after)')
    -- vim.keymap.set({ 'n', 'i' }, '<leader>awb', '<cmd>GpWhisperPrepend<cr>', keymapOptions 'Whisper Prepend (before) ')
    --
    -- vim.keymap.set('v', '<leader>awr', ":<C-u>'<,'>GpWhisperRewrite<cr>", keymapOptions 'Visual Whisper Rewrite')
    -- vim.keymap.set('v', '<leader>awa', ":<C-u>'<,'>GpWhisperAppend<cr>", keymapOptions 'Visual Whisper Append (after)')
    -- vim.keymap.set('v', '<leader>awb', ":<C-u>'<,'>GpWhisperPrepend<cr>", keymapOptions 'Visual Whisper Prepend (before)')
    --
    -- vim.keymap.set({ 'n', 'i' }, '<leader>awp', '<cmd>GpWhisperPopup<cr>', keymapOptions 'Whisper Popup')
    -- vim.keymap.set({ 'n', 'i' }, '<leader>awe', '<cmd>GpWhisperEnew<cr>', keymapOptions 'Whisper Enew')
    -- vim.keymap.set({ 'n', 'i' }, '<leader>awn', '<cmd>GpWhisperNew<cr>', keymapOptions 'Whisper New')
    -- vim.keymap.set({ 'n', 'i' }, '<leader>awv', '<cmd>GpWhisperVnew<cr>', keymapOptions 'Whisper Vnew')
    -- vim.keymap.set({ 'n', 'i' }, '<leader>awt', '<cmd>GpWhisperTabnew<cr>', keymapOptions 'Whisper Tabnew')
    --
    -- vim.keymap.set('v', '<leader>awp', ":<C-u>'<,'>GpWhisperPopup<cr>", keymapOptions 'Visual Whisper Popup')
    -- vim.keymap.set('v', '<leader>awe', ":<C-u>'<,'>GpWhisperEnew<cr>", keymapOptions 'Visual Whisper Enew')
    -- vim.keymap.set('v', '<leader>awn', ":<C-u>'<,'>GpWhisperNew<cr>", keymapOptions 'Visual Whisper New')
    -- vim.keymap.set('v', '<leader>awv', ":<C-u>'<,'>GpWhisperVnew<cr>", keymapOptions 'Visual Whisper Vnew')
    -- vim.keymap.set('v', '<leader>awt', ":<C-u>'<,'>GpWhisperTabnew<cr>", keymapOptions 'Visual Whisper Tabnew')

    require('which-key').add {
      -- VISUAL mode mappings
      -- s, x, v modes are handled the same way by which_key
      {
        mode = { 'v' },
        nowait = true,
        remap = false,
        { '<leader>a', group = 'AI Assistant' },
        { '<leader>at', desc = 'ChatNew tabnew' },
        { '<leader>av', desc = 'ChatNew vsplit' },
        { '<leader>as', desc = 'ChatNew split' },
        { '<leader>aa', desc = 'Visual Append (after)' },
        { '<leader>ab', desc = 'Visual Prepend (before)' },
        { '<leader>ac', desc = 'Visual Chat New' },
        { '<leader>ai', group = 'generate into new ..' },
        { '<leader>aie', desc = 'Visual This window (GpEnew)' },
        { '<leader>ain', desc = 'Visual New split window (GpNew)' },
        { '<leader>aip', desc = 'Visual popup (Popup)' },
        { '<leader>ait', desc = 'Visual New tab (GpTabnew)' },
        { '<leader>aiv', desc = 'Visual New vertical split (GpVnew)' },
        { '<leader>ai', desc = 'Implement selection' },
        { '<leader>an', desc = 'Next Agent' },
        { '<leader>ap', desc = 'Visual Chat Paste' },
        { '<leader>ar', desc = 'Visual Rewrite' },
        { '<leader>a.', desc = 'Stop execution (GpStop)' },
        { '<leader>tc', desc = 'Visual AI Chat (gp)' },
        -- { '<leader>aw', group = 'Whisper' },
        -- { '<leader>awa', ":<C-u>'<,'>GpWhisperAppend<cr>", desc = 'Whisper Append' },
        -- { '<leader>awb', ":<C-u>'<,'>GpWhisperPrepend<cr>", desc = 'Whisper Prepend' },
        -- { '<leader>awe', ":<C-u>'<,'>GpWhisperEnew<cr>", desc = 'Whisper Enew' },
        -- { '<leader>awn', ":<C-u>'<,'>GpWhisperNew<cr>", desc = 'Whisper New' },
        -- { '<leader>awp', ":<C-u>'<,'>GpWhisperPopup<cr>", desc = 'Whisper Popup' },
        -- { '<leader>awr', ":<C-u>'<,'>GpWhisperRewrite<cr>", desc = 'Whisper Rewrite' },
        -- { '<leader>awt', ":<C-u>'<,'>GpWhisperTabnew<cr>", desc = 'Whisper Tabnew' },
        -- { '<leader>awv', ":<C-u>'<,'>GpWhisperVnew<cr>", desc = 'Whisper Vnew' },
        -- { '<leader>aww', ":<C-u>'<,'>GpWhisper<cr>", desc = 'Whisper' },
        { '<leader>ax', desc = 'Visual GpContext' },
        { '<leader>ag', desc = 'Generate Response' },
        { '<leader>ad', desc = 'Delete Chat' },
      },

      -- NORMAL mode mappings
      {
        mode = { 'n' },
        nowait = true,
        remap = false,
        { '<leader>a', group = 'AI Assistant' },
        { '<leader>at', desc = 'New Chat tabnew' },
        { '<leader>av', desc = 'New Chat vsplit' },
        { '<leader>as', desc = 'New Chat split' },
        { '<leader>aa', desc = 'Append (after)' },
        { '<leader>ab', desc = 'Prepend (before)' },
        { '<leader>ac', desc = 'New Chat' },
        { '<leader>af', desc = 'Find in past chats' },
        { '<leader>ai', group = 'generate into new ..' },
        { '<leader>aie', desc = 'This window (GpEnew)' },
        { '<leader>ain', desc = 'New split window (GpNew)' },
        { '<leader>aip', desc = 'New popup (GpPopup)' },
        { '<leader>ait', desc = 'New tab (GpTabnew)' },
        { '<leader>aiv', desc = 'New vertical split (GpVnew)' },
        { '<leader>an', desc = 'Next Agent' },
        { '<leader>ar', desc = 'Inline Rewrite' },
        { '<leader>a.', desc = 'Stop execution (GpStop)' },
        { '<leader>tc', desc = 'AI Chat (gp)' },
        -- { '<leader>aw', group = 'Whisper' },
        -- { '<leader>awa', '<cmd>GpWhisperAppend<cr>', desc = 'Whisper Append (after)' },
        -- { '<leader>awb', '<cmd>GpWhisperPrepend<cr>', desc = 'Whisper Prepend (before)' },
        -- { '<leader>awe', '<cmd>GpWhisperEnew<cr>', desc = 'Whisper Enew' },
        -- { '<leader>awn', '<cmd>GpWhisperNew<cr>', desc = 'Whisper New' },
        -- { '<leader>awp', '<cmd>GpWhisperPopup<cr>', desc = 'Whisper Popup' },
        -- { '<leader>awr', '<cmd>GpWhisperRewrite<cr>', desc = 'Whisper Inline Rewrite' },
        -- { '<leader>awt', '<cmd>GpWhisperTabnew<cr>', desc = 'Whisper Tabnew' },
        -- { '<leader>awv', '<cmd>GpWhisperVnew<cr>', desc = 'Whisper Vnew' },
        -- { '<leader>aww', '<cmd>GpWhisper<cr>', desc = 'Whisper' },
        { '<leader>ax', '<cmd>GpContext<cr>', desc = 'Edit GpContext' },
        { '<leader>ag', desc = 'Generate Response' },
        { '<leader>ad', desc = 'Delete Chat' },
      },

      -- INSERT mode mappings
      -- {
      --   mode = { 'i' },
      --   nowait = true,
      --   remap = false,
      --   { '<leader>a', group = 'AI Assistant' },
      --   { '<leader>at', desc = 'New Chat tabnew' },
      --   { '<leader>av', desc = 'New Chat vsplit' },
      --   { '<leader>as', desc = 'New Chat split' },
      --   { '<leader>aa', desc = 'Append (after)' },
      --   { '<leader>ab', desc = 'Prepend (before)' },
      --   { '<leader>ac', desc = 'New Chat' },
      --   { '<leader>af', desc = 'Find in past chats' },
      --   { '<leader>ai', group = 'generate into new ..' },
      --   { '<leader>aie', desc = 'This window (GpEnew)' },
      --   { '<leader>ain', desc = 'New split window (GpNew)' },
      --   { '<leader>aip', desc = 'Popup (GpPopup)' },
      --   { '<leader>ait', desc = 'New tab (GpTabnew)' },
      --   { '<leader>aiv', desc = 'New vertical split (GpVnew)' },
      --   { '<leader>an', desc = 'Next Agent' },
      --   { '<leader>ar', desc = 'Inline Rewrite' },
      --   { '<leader>a.', desc = 'Stop execution (GpStop)' },
      --   { '<leader>tc', desc = 'AI Chat (gp)' },
      --   -- { '<leader>aw', group = 'Whisper' },
      --   -- { '<leader>awa', '<cmd>GpWhisperAppend<cr>', desc = 'Whisper Append (after)' },
      --   -- { '<leader>awb', '<cmd>GpWhisperPrepend<cr>', desc = 'Whisper Prepend (before)' },
      --   -- { '<leader>awe', '<cmd>GpWhisperEnew<cr>', desc = 'Whisper Enew' },
      --   -- { '<leader>awn', '<cmd>GpWhisperNew<cr>', desc = 'Whisper New' },
      --   -- { '<leader>awp', '<cmd>GpWhisperPopup<cr>', desc = 'Whisper Popup' },
      --   -- { '<leader>awr', '<cmd>GpWhisperRewrite<cr>', desc = 'Whisper Inline Rewrite' },
      --   -- { '<leader>awt', '<cmd>GpWhisperTabnew<cr>', desc = 'Whisper Tabnew' },
      --   -- { '<leader>awv', '<cmd>GpWhisperVnew<cr>', desc = 'Whisper Vnew' },
      --   -- { '<leader>aww', '<cmd>GpWhisper<cr>', desc = 'Whisper' },
      --   { '<leader>ax', '<cmd>GpContext<cr>', desc = 'Edit GpContext' },
      -- },
    }
  end,
}
