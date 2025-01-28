local M = {}

local Job = require 'plenary.job'

---@class LlmFileType
---@field path string
---@field contents string

local LlmFile = {}
LlmFile.__index = LlmFile

---@param path string
---@param contents string
function LlmFile.new(path, contents)
  local self = setmetatable({}, LlmFile)
  self.path = path
  self.contents = contents
  return self
end

function LlmFile:formatted_contents()
  return string.format("<contentblock file=%s>\n%s\n</contentblock>", self.path, self.contents)
end

---@return string[]
local function get_llmfile_paths()
  local contents = {}
  local current_dir = vim.fn.getcwd()
  local file_path = current_dir .. "/.llmfiles"

  local file = io.open(file_path, "r")
  if not file then
    return {}
  end

  for line in file:lines() do
    local trimmed_line = line:match("^%s*(.-)%s*$")
    if trimmed_line ~= "" then
      table.insert(contents, trimmed_line)
    end
  end


  file:close()
  return contents
end

local function get_api_key(name)
  return os.getenv(name)
end

M.reasoning_win = nil
M.reasoning_buf = nil

function M.open_reasoning_window()
  if M.reasoning_buf == nil then
    M.reasoning_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[M.reasoning_buf].modifiable = false
  end
  if M.reasoning_win == nil then
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
    M.reasoning_win = vim.api.nvim_open_win(M.reasoning_buf, false, {
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
    vim.wo[M.reasoning_win].wrap = true
  end
end

function M.write_reasoning_content(content)
  vim.schedule(function()
    if not M.reasoning_buf or not vim.api.nvim_buf_is_valid(M.reasoning_buf) or content == vim.NIL then return end
    vim.bo[M.reasoning_buf].modifiable = true
    local line_count = vim.api.nvim_buf_line_count(M.reasoning_buf)
    if line_count == 0 then
      local lines = vim.split(content, '\n')
      vim.api.nvim_buf_set_lines(M.reasoning_buf, 0, -1, false, lines)
    else
      local last_line = vim.api.nvim_buf_get_lines(M.reasoning_buf, line_count - 1, line_count, false)[1] or ''
      local combined = last_line .. content
      local lines = vim.split(combined, '\n')
      vim.api.nvim_buf_set_lines(M.reasoning_buf, line_count - 1, line_count, false, { lines[1] })
      if #lines > 1 then
        vim.api.nvim_buf_set_lines(M.reasoning_buf, line_count, line_count, false, { unpack(lines, 2) })
      end
    end
    if M.reasoning_win and vim.api.nvim_win_is_valid(M.reasoning_win) then
      local new_line_count = vim.api.nvim_buf_line_count(M.reasoning_buf)
      vim.api.nvim_win_set_cursor(M.reasoning_win, { new_line_count, 0 })
    end
    vim.bo[M.reasoning_buf].modifiable = false
  end)
end

function M.clear_reasoning_display()
  if M.reasoning_win and vim.api.nvim_win_is_valid(M.reasoning_win) then
    vim.api.nvim_win_close(M.reasoning_win, true)
  end
  if M.reasoning_buf and vim.api.nvim_buf_is_valid(M.reasoning_buf) then
    vim.api.nvim_buf_delete(M.reasoning_buf, { force = true })
  end

  M.reasoning_win = nil
  M.reasoning_buf = nil
end

function M.get_lines_until_cursor()
  local current_buffer = vim.api.nvim_get_current_buf()
  local current_window = vim.api.nvim_get_current_win()
  local cursor_position = vim.api.nvim_win_get_cursor(current_window)
  local row = cursor_position[1]

  local lines = vim.api.nvim_buf_get_lines(current_buffer, 0, row, true)

  return table.concat(lines, '\n')
end

function M.get_visual_selection()
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

function M.make_anthropic_spec_curl_args(opts, prompt, system_prompt)
  local url = opts.url
  local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
  local data = {
    system = system_prompt,
    messages = { { role = 'user', content = prompt } },
    model = opts.model,
    stream = true,
    max_tokens = 4096,
  }
  local args = { '-N', '-X', 'POST', '-H', 'Content-Type: application/json', '-d', vim.json.encode(data) }
  if api_key then
    table.insert(args, '-H')
    table.insert(args, 'x-api-key: ' .. api_key)
    table.insert(args, '-H')
    table.insert(args, 'anthropic-version: 2023-06-01')
  end
  table.insert(args, url)
  return args
end

function M.make_openai_spec_curl_args(opts, prompt, system_prompt)
  local url = opts.url
  local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
  local data = {
    messages = { { role = 'system', content = system_prompt }, { role = 'user', content = prompt } },
    model = opts.model,
    temperature = 0.7,
    stream = true,
  }
  local args = { '-N', '-X', 'POST', '-H', 'Content-Type: application/json', '-d', vim.json.encode(data) }
  if api_key then
    table.insert(args, '-H')
    table.insert(args, 'Authorization: Bearer ' .. api_key)
  end
  table.insert(args, url)
  return args
end

function M.make_deepseek_spec_curl_args(opts, prompt, system_prompt)
  local url = opts.url
  local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
  local data = {
    messages = { { role = 'system', content = system_prompt }, { role = 'user', content = prompt } },
    model = opts.model,
    temperature = 0.0,
    stream = true,
  }
  local args = { '-N', '-X', 'POST', '-H', 'Content-Type: application/json', '-d', vim.json.encode(data) }
  if api_key then
    table.insert(args, '-H')
    table.insert(args, 'Authorization: Bearer ' .. api_key)
  end
  table.insert(args, url)
  return args
end

function M.write_string_at_cursor(str)
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

local function get_prompt(opts)
  local replace = opts.replace
  local visual_lines = M.get_visual_selection()
  local prompt = ''

  if visual_lines then
    prompt = table.concat(visual_lines, '\n')
    if replace then
      vim.api.nvim_command 'normal! d'
      vim.api.nvim_command 'normal! k'
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', false, true, true), 'nx', false)
    end
  else
    prompt = M.get_lines_until_cursor()
  end

  return prompt
end

function M.handle_anthropic_spec_data(data_stream, event_state, _)
  if event_state == 'content_block_delta' then
    local json = vim.json.decode(data_stream)
    if json.delta and json.delta.text then
      M.write_string_at_cursor(json.delta.text)
    end
  end
end

function M.handle_openai_spec_data(data_stream, _, _)
  if data_stream:match '"delta":' then
    local json = vim.json.decode(data_stream)
    if json.choices and json.choices[1] and json.choices[1].delta then
      local content = json.choices[1].delta.content
      if content then
        M.write_string_at_cursor(content)
      end
    else
      print("no choices found")
      print(vim.inspect(json))
    end
  end
end

function M.handle_openai_reasoning_data(data_stream, _, show_reasoning)
  if data_stream:match '"delta":' then
    local json = vim.json.decode(data_stream)
    if json.choices and json.choices[1] and json.choices[1].delta then
      local content = json.choices[1].delta.content
      if content then
        M.write_string_at_cursor(content)
      end
      local reasoning_content = json.choices[1].delta.reasoning_content
      if reasoning_content and show_reasoning then
        M.write_reasoning_content(reasoning_content)
      end
    else
      print("no choices found")
      print(vim.inspect(json))
    end
  end
end

local group = vim.api.nvim_create_augroup('DING_LLM_AutoGroup', { clear = true })
local active_job = nil

---@param llm_paths string[]
---@param system_prompt string
local function system_prompt_with_files(llm_paths, system_prompt)
  local files_string = "<system_prompt>\n" .. system_prompt .. "\n</system_prompt>"
  for _, p in ipairs(llm_paths) do
    local attributes = vim.loop.fs_stat(p)
    if attributes and attributes.type == "directory" then
      error("Expected file path but got directory: " .. p)
    end
    local f = io.open(p, "r")
    if f then
      local llm_file = LlmFile.new(p, f:read("*all"))
      files_string = files_string .. "\n\n" .. llm_file:formatted_contents()
      f:close()
    else
      vim.notify("no file found: " .. p, vim.log.levels.WARN)
    end
  end
  return files_string
end

function M.invoke_llm_and_stream_into_editor(opts, make_curl_args_fn, handle_data_fn, show_reasoning)
  if M.reasoning_buf ~= nil or M.reasoning_win ~= nil then
    M.clear_reasoning_display()
  end
  if show_reasoning == nil then
    show_reasoning = false
  end
  local llm_paths = get_llmfile_paths()
  vim.api.nvim_clear_autocmds { group = group }
  local prompt = get_prompt(opts)
  local system_prompt = opts.system_prompt or
      'You are a tsundere uwu anime. Yell at me for not setting my configuration for my llm plugin correctly'
  system_prompt = system_prompt_with_files(llm_paths, system_prompt)
  local args = make_curl_args_fn(opts, prompt, system_prompt)
  local curr_event_state = nil

  local function parse_and_call(line)
    local event = line:match '^event: (.+)$'
    if event then
      curr_event_state = event
      return
    end
    local data_match = line:match '^data: (.+)$'
    if data_match then
      handle_data_fn(data_match, curr_event_state, show_reasoning)
    end
  end

  if active_job then
    active_job:shutdown()
    active_job = nil
    M.clear_reasoning_display()
  end

  active_job = Job:new {
    command = 'curl',
    args = args,
    on_stdout = function(_, out)
      parse_and_call(out)
    end,
    on_stderr = function(_, _) end,
    on_exit = function()
      active_job = nil
    end,
  }

  active_job:start()

  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'DING_LLM_Escape',
    callback = function()
      if active_job then
        active_job:shutdown()
        print 'LLM streaming cancelled'
        active_job = nil
      end
      M.clear_reasoning_display()
    end,
  })

  vim.api.nvim_set_keymap('n', '<Esc>', ':doautocmd User DING_LLM_Escape<CR>', { noremap = true, silent = true })
  if show_reasoning then
    M.open_reasoning_window()
  end
  return active_job
end

return M
