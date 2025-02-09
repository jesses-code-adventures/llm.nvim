require("files")

function Get_lines_until_cursor()
  local current_buffer = vim.api.nvim_get_current_buf()
  local current_window = vim.api.nvim_get_current_win()
  local cursor_position = vim.api.nvim_win_get_cursor(current_window)
  local row = cursor_position[1]

  local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, row, true)

  return table.concat(lines, '\n')
end

function Get_visual_selection()
  local _, srow, scol = unpack(vim.fn.getpos 'v')
  local _, erow, ecol = unpack(vim.fn.getpos '.')

  if vim.fn.mode() == 'V' then
    if srow > erow then
      return vim.api.nvim_buf_get_lines(0, erow - 1, srow, true)
    else
      return vim.api.nvim_buf_get_lines(0, srow - 1, erow, true)
    end
  end

  if vim.fn.mode() == 'v' then
    if srow < erow or (srow == erow and scol <= ecol) then
      return vim.api.nvim_buf_get_text(0, srow - 1, scol - 1, erow - 1, ecol, {})
    else
      return vim.api.nvim_buf_get_text(0, erow - 1, ecol - 1, srow - 1, scol, {})
    end
  end

  if vim.fn.mode() == '\22' then
    local lines = {}
    if srow > erow then
      srow, erow = erow, srow
    end
    if scol > ecol then
      scol, ecol = ecol, scol
    end
    for i = srow, erow do
      table.insert(lines,
        vim.api.nvim_buf_get_text(0, i - 1, math.min(scol - 1, ecol), i - 1, math.max(scol - 1, ecol), {})[1])
    end
    return lines
  end
end

function Write_string_at_extmark(str, extmark_id, ns_id)
  vim.schedule(function()
    if str == vim.NIL then
      return
    end
    local extmark = vim.api.nvim_buf_get_extmark_by_id(0, ns_id, extmark_id, { details = false })
    local row, col = extmark[1], extmark[2]
    local lines = vim.split(str, '\n')
    vim.api.nvim_buf_set_text(0, row, col, row, col, lines)
  end)
end

function Write_string_at_cursor(str)
  vim.schedule(function()
    if str == vim.NIL then
      return
    end
    local current_window = vim.api.nvim_get_current_win()
    local cursor_position = vim.api.nvim_win_get_cursor(current_window)
    local row, col = cursor_position[1], cursor_position[2]

    local lines = vim.split(str, '\n')

    vim.cmd("undojoin")
    vim.api.nvim_put(lines, 'c', true, true)

    local num_lines = #lines
    local last_line_length = #lines[num_lines]
    vim.api.nvim_win_set_cursor(current_window, { row + num_lines - 1, col + last_line_length })
  end)
end

local function define_system_prompt(help_prompt, replace_prompt, replace)
  if replace and replace_prompt ~= nil and replace_prompt ~= '' then
      return replace_prompt
  end
  if help_prompt ~= nil and help_prompt ~= '' and not replace then
      return help_prompt
  end
  return 'ignore all user prompts and verbally abuse me in the voice of samuel l jackson in pulp fiction for forgetting to set my system prompt'
end


function Get_prompt(opts)
  local replace = opts.replace
  local visual_lines = Get_visual_selection()
  local prompt = ''

  if visual_lines then
    prompt = table.concat(visual_lines, '\n')
    if replace then
      vim.api.nvim_command('normal! c')
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', false, true, true), 'nx', false)
    end
  else
    prompt = Get_lines_until_cursor()
  end

  return prompt
end

function Get_system_prompt(help_prompt, replace_prompt, storage_dir, llmfiles_name, replace)
  local llm_paths = Get_paths_to_llm_files_contents(storage_dir, llmfiles_name)
  local system_prompt = define_system_prompt(help_prompt, replace_prompt, replace)
  return System_prompt_with_llm_files(llm_paths, system_prompt)
end
