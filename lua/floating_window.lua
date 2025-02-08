function Open_floating_window(floating_buf, floating_win)
  if floating_buf == nil then
    floating_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[floating_buf].modifiable = false
  end
  if floating_win == nil then
    local wins = vim.api.nvim_tabpage_list_wins(0)
    local leftmost_win = nil
    local min_col = math.huge
    for _, win in ipairs(wins) do
      local buf = vim.api.nvim_win_get_buf(win)
      local buf_name = vim.api.nvim_buf_get_name(buf)
      local filename = vim.fn.fnamemodify(buf_name, ':t')
      if filename == 'chat.md' or filename == '.llmfiles' then
        goto continue
      end
      local pos = vim.api.nvim_win_get_position(win)
      if pos[2] < min_col then
        min_col = pos[2]
        leftmost_win = win
      end
      ::continue::
    end
    if leftmost_win == nil then
      error("expected to find a window to float the reasoning window on")
    end
    local width = math.floor(vim.api.nvim_win_get_width(leftmost_win) * 0.4)
    local height = math.floor(vim.api.nvim_win_get_height(leftmost_win) * 0.6)
    floating_win = vim.api.nvim_open_win(floating_buf, false, {
      relative = 'win',
      win = leftmost_win,
      anchor = 'NE',
      width = width,
      height = height,
      col = vim.api.nvim_win_get_width(leftmost_win) - 1,
      row = 0,
      style = 'minimal',
      border = 'rounded',
      title = 'Reasoning',
      title_pos = 'center'
    })
    vim.wo[floating_win].wrap = true
  end
  return {floating_buf, floating_win}
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
  return {nil, nil}
end
