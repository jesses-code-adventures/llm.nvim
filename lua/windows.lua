local function open_floating_window(title, footer, buf, win, relative_win, col, row, width, height, enter)
  if win ~= nil and buf ~= nil then
    return { buf, win }
  end
  if buf == nil then
    error("expect a buf")
  end
  win = vim.api.nvim_open_win(buf, enter, {
    relative = relative_win and 'win' or 'editor',
    win = relative_win,
    anchor = relative_win and 'NE' or nil,
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
    footer = footer,
    footer_pos = 'center',
  })
  vim.wo[win].wrap = true
  return { buf, win }
end


local function get_code_win()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local relative_win = nil
  local min_col = math.huge
  for _, this_win in ipairs(wins) do
    local this_buf = vim.api.nvim_win_get_buf(this_win)
    local this_buf_name = vim.api.nvim_buf_get_name(this_buf)
    local filename = vim.fn.fnamemodify(this_buf_name, ':t')
    if filename == 'chat.md' or filename == '.llmfiles' then
      goto continue
    end
    local pos = vim.api.nvim_win_get_position(this_win)
    if pos[2] < min_col then
      min_col = pos[2]
      relative_win = this_win
    end
    ::continue::
  end
  if relative_win == nil then
    error("expected to find a relative window to float the reasoning window on")
  end
  return relative_win
end


local function centered_win_dimensions(width, height)
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines - vim.o.cmdheight
  local col = math.floor((editor_width - width) / 2)
  local row = math.floor((editor_height - height) / 2)
  return { col, row, width, height }
end


function Open_reasoning_window(buf, win)
  if buf ~= nil and vim.api.nvim_buf_is_valid(buf) and win ~= nil and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_set_current_buf(buf)
    return { buf, win }
  end
  local wins = vim.api.nvim_list_wins()
  for _, w in ipairs(wins) do
    local config = vim.api.nvim_win_get_config(w)
    if config.title and config.title == "Reasoning" then
      win = w
      buf = vim.api.nvim_win_get_buf(w)
      return { buf, win }
    end
  end
  if buf == nil then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].modifiable = false
  end
  local relative_win = get_code_win()
  local width = math.floor(vim.api.nvim_win_get_width(relative_win) * 0.4)
  local height = math.floor(vim.api.nvim_win_get_height(relative_win) * 0.6)
  local col = vim.api.nvim_win_get_width(relative_win) - 1
  local row = 0
  return open_floating_window("Reasoning", "ESC - exit", buf, win, relative_win, col, row, width, height, false)
end


function Select_model(buf, win, models, select_model_callback, show_reasoning_callback, picker)
  if pcall(require, 'telescope') and picker == 'telescope' then
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    pickers.new({}, {
      prompt_title = 'Find a Model',
      results_title = 'LLM Models',
      finder = finders.new_table({
        results = models
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          select_model_callback(selection[1])
        end)
        return true
      end,
    }):find()
    return { nil, nil }
  else
    if buf == nil or not vim.api.nvim_buf_is_valid(buf) then
      buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, 0, false, models)
      vim.bo[buf].modifiable = false
      vim.keymap.set('n', '<CR>', function()
        select_model_callback()
        vim.api.nvim_win_close(0, true)
      end, { buffer = buf, noremap = true, silent = true })
      vim.keymap.set('n', 't', function() show_reasoning_callback() end, { buffer = buf, noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':bwipeout<CR>', { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(buf, 'n', '<ESC>', ':bwipeout<CR>', { noremap = true, silent = true })
    end
   if win == nil or not vim.api.nvim_win_is_valid(win) then
      local dims = centered_win_dimensions(80, 20)
      return open_floating_window("Select Model", "⏎ - select, t - toggle reasoning window display, q - quit", buf, win,
        nil, dims[1], dims[2], dims[3], dims[4], true)
    end
    return { buf, win }
  end
end


function Write_floating_content(content, floating_buf, floating_win)
  vim.schedule(function()
    if not floating_buf or not vim.api.nvim_buf_is_valid(floating_buf) or content == vim.NIL then return end
    vim.bo[floating_buf].modifiable = true
    local line_count = vim.api.nvim_buf_line_count(floating_buf)
    if line_count == 0 then
      local lines = vim.split(content, '\n')
      vim.api.nvim_buf_set_lines(floating_buf, 0, -1, false, lines)
    else
      local last_line = vim.api.nvim_buf_get_lines(floating_buf, line_count - 1, line_count, false)[1] or ''
      local combined = last_line .. content
      local lines = vim.split(combined, '\n')
      vim.api.nvim_buf_set_lines(floating_buf, line_count - 1, line_count, false, { lines[1] })
      if #lines > 1 then
        vim.api.nvim_buf_set_lines(floating_buf, line_count, line_count, false, { unpack(lines, 2) })
      end
    end
    if floating_win and vim.api.nvim_win_is_valid(floating_win) then
      local new_line_count = vim.api.nvim_buf_line_count(floating_buf)
      vim.api.nvim_win_set_cursor(floating_win, { new_line_count, 0 })
    end
    vim.bo[floating_buf].modifiable = false
  end)
end


function Clear_floating_display(floating_buf, floating_win)
  if floating_win and vim.api.nvim_win_is_valid(floating_win) then
    vim.api.nvim_win_close(floating_win, true)
  end
  if floating_buf and vim.api.nvim_buf_is_valid(floating_buf) then
    vim.api.nvim_buf_delete(floating_buf, { force = true })
  end
  return { nil, nil }
end


local function display_settings_telescope(settings, toggle_reasoning_fn)
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    pickers.new({}, {
      prompt_title = false,
      results_title = 'LLM Settings',
      prompt_prefix = "",
      initial_mode = 'normal',
      finder = finders.new_table({
        results = {
          "Model: " .. settings.model,
          "Show Reasoning: " .. tostring(settings.show_reasoning),
        }
      }),
      sorting_strategy = "ascending",
      layout_strategy = "vertical",
      layout_config = {
        height = 0.2,
      },
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
        end)
        map('n', 't', function()
          settings = toggle_reasoning_fn()
          local picker = action_state.get_current_picker(prompt_bufnr)
          picker:refresh(finders.new_table({
            results = {
              "Model: " .. settings.model,
              "Show Reasoning: " .. tostring(settings.show_reasoning),
            }
          }))
        end)
        return true
      end,
    }):find()
end


local function display_settings_native(settings, toggle_reasoning_fn)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "Model: " .. settings.model,
    "Show Reasoning: " .. tostring(settings.show_reasoning),
  })
  local dims = centered_win_dimensions(50, 6)
  local bufwin = open_floating_window("Settings", "", buf, nil, nil, dims[1], dims[2], dims[3], dims[4],
    true)
  buf = bufwin[1]
  local win = bufwin[2]
  vim.api.nvim_win_set_option(win, 'winhl', 'Normal:Normal')
  vim.keymap.set('n', '<CR>', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, noremap = true, silent = true })
  vim.keymap.set('n', 't', function()
    settings = toggle_reasoning_fn()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "Model: " .. settings.model,
      "Show Reasoning: " .. tostring(settings.show_reasoning),
    })
  end, { buffer = buf, noremap = true, silent = true })
end


function Display_settings(storage_dir, toggle_reasoning_fn, picker_name)
  local settings = Get_settings(storage_dir)
  if not settings then return end

  if pcall(require, 'snacks') and picker_name == 'snacks' then
    require('snacks').picker.pick({
      items = {
        "Model: " .. settings.model,
        "Show Reasoning: " .. tostring(settings.show_reasoning),
      },
      title = "Settings",
      on_change = function(picker, item)
        settings = toggle_reasoning_fn()
        picker:refresh({
          items = {
            "Model: " .. settings.model,
            "Show Reasoning: " .. tostring(settings.show_reasoning),
          }
        })
      end
    })
    return
  elseif pcall(require, 'telescope') and picker_name == 'telescope' then
    display_settings_telescope(settings, toggle_reasoning_fn)
    return
  end

  display_settings_native(settings, toggle_reasoning_fn)
end


function New_chat_panel(chat_path, llmfiles_path)
  vim.cmd('vsplit')
  vim.cmd('wincmd l')
  vim.cmd('vertical resize 60')

  vim.cmd('e ' .. chat_path)
  local chat_buf = vim.api.nvim_get_current_buf()
  local chat_win = vim.api.nvim_get_current_win()
  vim.wo[chat_win].wrap = true

  vim.cmd('split')
  vim.cmd('resize 5')
  vim.cmd('e ' .. llmfiles_path)
  local llmfiles_buf = vim.api.nvim_get_current_buf()
  local llmfiles_win = vim.api.nvim_get_current_win()

  return { chat_buf, chat_win, llmfiles_buf, llmfiles_win }
end
