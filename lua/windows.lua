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

function Open_reasoning_window(buf, win)
  if buf ~= nil and vim.api.nvim_buf_is_valid(buf) and win ~= nil and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_set_current_buf(buf)
    return { buf, win }
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

function Select_model(buf, win, models, select_model_callback, show_reasoning_callback)
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
    local editor_width = vim.o.columns
    local editor_height = vim.o.lines - vim.o.cmdheight
    local target_width = 80
    local target_height = 8
    local col = math.floor((editor_width - target_width) / 2)
    local row = math.floor((editor_height - target_height) / 2)
    return open_floating_window("Select Model", "⏎ - select, t - toggle reasoning window display, q - quit", buf, win, nil, col, row, target_width, target_height, true)
  end
  return { buf, win }
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
