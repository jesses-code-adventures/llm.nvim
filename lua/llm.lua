require("curl_args")
require("data_handlers")
require("models")
require("files")
require("windows")
require("settings")
require("prompt")
require("utils")
local Job = require 'plenary.job'

local group = vim.api.nvim_create_augroup('LLM_AutoGroup', { clear = true })
local active_job = nil

local M = {
  _reasoning_win = nil,
  _reasoning_buf = nil,
  _settings_win = nil,
  _settings_buf = nil,
}

function M._update_settings(settings)
  if settings == nil then
    return
  end
  M.show_reasoning = settings.show_reasoning
  M.model = settings.model
  M._validate_settings()
end

function M._validate_settings()
  local available = Available_models(M.excluded_providers)
  local fail_msg = "default model isn't provided, it may not exist or you may have the provider excluded. available models: " .. vim.inspect(available) .. ", default model: " .. M.default_model
  for _, m in ipairs(available) do
    if m == M.default_model then
      goto found_default_model
    end
  end
  vim.notify(fail_msg, vim.log.levels.WARN)
  ::found_default_model::

  -- TODO: note this early return - if we want to validate other settings after, we should do this differently
  if M.model == nil or M.model == "" then
    return
  end
  fail_msg = "selected model isn't provided, it may not exist or you may have the provider excluded. available models: " .. vim.inspect(available) .. ", selected model: " .. M.model
  for _, m in ipairs(available) do
    if m == M.model then
      goto found_selected_model
    end
  end
  vim.notify(fail_msg, vim.log.levels.WARN)
  ::found_selected_model::
end

function M.setup(opts)
  M._storage_dir = opts.storage_dir or vim.fn.stdpath('data') .. '/llm'
  M.excluded_providers = opts.excluded_providers or {}
  M.llmfiles_name = opts.llmfiles_name or '.llmfiles'
  M.chat_name = opts.chat_name or 'chat.md'
  M.default_model = opts.default_model or 'anthropic-claude-3-5-sonnet-20241022'
  M.help_prompt = opts.help_prompt
  M.replace_prompt = opts.replace_prompt
  local settings = Get_settings(M._storage_dir)
  if settings == nil then
    M.show_reasoning = false
    M.model = M.default_model
    return
  end
  M._update_settings(settings)
end

function M._reasoning_bufwin_fn(f)
  local bufwin = f()
  M._reasoning_buf = bufwin[1]
  M._reasoning_win = bufwin[2]
end

function M._settings_bufwin_fn(f)
  local bufwin = f()
  M._settings_buf = bufwin[1]
  M._settings_win = bufwin[2]
end

function M._request_and_stream(opts, system_prompt)
  local prompt = Get_prompt(opts)
  local handle_data_fn = Get_data_fn(opts.model)
  local args = Make_curl_args(opts.model)(opts, prompt, system_prompt)
  local curr_event_state = nil

  local function parse_and_call(line)
    print(line)
    local event = line:match '^event: (.+)$'
    if event then
      curr_event_state = event
      return
    end
    local data_match = line:match '^data: (.+)$'
    if data_match then
      handle_data_fn(data_match, curr_event_state, opts.show_reasoning, Write_string_at_cursor,
        function(s) Write_floating_content(s, M._reasoning_buf, M._reasoning_win) end)
      return
    end
    local stripped = Strip_string(line)
    if String_startswith(stripped, '"text": "') then
      handle_data_fn(stripped, curr_event_state, opts.show_reasoning, Write_string_at_cursor,
        function(s) Write_floating_content(s, M._reasoning_buf, M._reasoning_win) end)
      return
    end
  end

  if active_job then
    active_job:shutdown()
    active_job = nil
    M._reasoning_bufwin_fn(Clear_floating_display())
  end

  ---@diagnostic disable-next-line: missing-fields
  active_job = Job:new({
    command = 'curl',
    args = args,
    on_stdout = function(_, out)
      parse_and_call(out)
    end,
    on_stderr = function(_, err)
      if err and err ~= "" then
        vim.schedule(function()
          vim.notify("stderr: " .. err, vim.log.levels.ERROR)
        end)
      end
    end,
    on_exit = function(j, return_val)
      active_job = nil
      if return_val ~= 0 then
        vim.schedule(function()
          local result = table.concat(j:result(), "\n")
          local stderr = table.concat(j:stderr_result(), "\n")
          vim.notify("Job failed with exit code " .. return_val .. "\nstdout:\n" .. result .. "\nstderr:\n" .. stderr,
            vim.log.levels.ERROR)
        end)
      end
    end
  })

  active_job:start()

  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'LLM_Escape',
    callback = function()
      if active_job then
        active_job:shutdown()
        LlmAppPrint('streaming cancelled')
        active_job = nil
      end
      M._reasoning_bufwin_fn(Clear_floating_display)
    end,
  })

  vim.api.nvim_set_keymap('n', '<Esc>', ':doautocmd User LLM_Escape<CR>', { noremap = true, silent = true })
  return active_job
end

function M._handle_prompt(help)
  if M.model == nil then
    M._update_settings({ model = M.default_model, show_reasoning = false })
  end

  local system_prompt = Get_system_prompt(M.help_prompt, M.replace_prompt, M._storage_dir, M.llmfiles_name, not help)
  local opts = Get_opts(M.model, system_prompt, help, M.show_reasoning)
  if opts.show_reasoning and M._reasoning_buf ~= nil or M._reasoning_win ~= nil then
    M._reasoning_bufwin_fn(Clear_floating_display)
  end
  vim.api.nvim_clear_autocmds { group = group }

  M._request_and_stream(opts, system_prompt)
  if opts.show_reasoning then
    M._reasoning_bufwin_fn(function() return Open_reasoning_window(M._reasoning_buf, M._reasoning_win) end)
  end
end

function M._select_model_fn(selected_model)
  if selected_model then
    M.model = selected_model
  else
    local current_win = vim.api.nvim_get_current_win()
    local current_line = vim.api.nvim_win_get_cursor(current_win)[1]
    local available = Available_models(M.excluded_providers)
    local model = available[current_line]
    M.model = model
  end
  LlmAppPrint("set model to [" .. M.model .. "]")
  M._update_settings(Write_selected_model(M._storage_dir, M.model, M.show_reasoning))
end

function M._toggle_reasoning_window_fn()
  M._update_settings(Write_selected_model(M._storage_dir, M.model, not M.show_reasoning))
end

function M.replace()
  M._handle_prompt(false)
end

function M.help()
  M._handle_prompt(true)
end

function M.models()
  if M._settings_win ~= nil and not vim.api.nvim_win_is_valid(M._settings_win) then
    M._settings_win = nil
  end
  if M._settings_buf ~= nil and not vim.api.nvim_buf_is_valid(M._settings_buf) then
    M._settings_buf = nil
  end
  M._settings_bufwin_fn(function() return Select_model(M._settings_buf, M._settings_win, Available_models(M.excluded_providers), M._select_model_fn,
      M._toggle_reasoning_window_fn) end)
end

function M.chat()
  vim.cmd('vsplit')
  vim.cmd('wincmd l')
  vim.cmd('vertical resize 60')
  vim.cmd('e ' .. Get_hashed_project_path(M._storage_dir, M.chat_name))
  vim.cmd('set wrap')
  vim.cmd('split')
  vim.cmd('resize 5')
  vim.cmd('e ' .. Get_hashed_project_path(M._storage_dir, M.llmfiles_name))
end

return M
