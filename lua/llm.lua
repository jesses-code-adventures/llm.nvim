require("curl_args")
require("data_handlers")
require("files")
require("models")
require("prompt")
require("utils")
require("windows")

local Job = require('plenary.job')
local ns_id = vim.api.nvim_create_namespace('llm')


local function validate_model(model, available, fail_msg)
  for _, m in ipairs(available) do
    if m == model then
      return true
    end
  end
  vim.notify(fail_msg, vim.log.levels.WARN)
  return false
end


local function create_escape_binding()
  local user_esc = vim.fn.maparg('<Esc>', 'n')
  vim.keymap.set('n', '<Esc>', ":lua require('llm')._shutdown_existing_request()<CR>", { silent = true, desc = "llm: stop token streaming"})
  return user_esc
end


local function restore_escape_binding(original)
  vim.keymap.set('n', '<Esc>', original, { silent = true })
end


local function job_error_handler(err)
  if err and err ~= "" then
    vim.schedule(function()
      vim.notify("stderr: " .. err, vim.log.levels.ERROR)
    end)
  end
end

local M = {}


function M.setup(opts)
  M.help_prompt = opts.help_prompt
  M.replace_prompt = opts.replace_prompt
  M._storage_dir = opts.storage_dir or vim.fn.stdpath('data') .. '/llm'
  M.excluded_providers = opts.excluded_providers or {}
  M.llmfiles_name = opts.llmfiles_name or '.llmfiles'
  M.chat_name = opts.chat_name or 'chat.md'
  M.chat_path = Get_hashed_project_path(M._storage_dir, M.chat_name)
  M.llmfiles_path = Get_hashed_project_path(M._storage_dir, M.llmfiles_name)
  M.default_model = opts.default_model or 'anthropic-claude-3-5-sonnet-20241022'
  if opts.picker ~= nil and opts.picker ~= 'telescope' and opts.picker ~= 'fzf-lua' then
    error('invalid picker, please pass "telescope", "fzf-lua" or nil')
  end
  M.picker = opts.picker

  -- HACK: out of nowhere we've started getting a nil error on Get_settings sometimes
  -- code still works fine, so just doing this check for now as cbf to fix properly yet
  if Get_settings == nil then
    M.model = M.default_model
    M.show_reasoning = true
    return
  end

  local settings = Get_settings(M._storage_dir)
  if settings then
    M._update_settings(settings)
  else
    M.model = M.default_model
    M.show_reasoning = true
  end
end


function M.models()
  if M._settings_win and not vim.api.nvim_win_is_valid(M._settings_win) then
    M._settings_win = nil
  end
  if M._settings_buf and not vim.api.nvim_buf_is_valid(M._settings_buf) then
    M._settings_buf = nil
  end
  M._settings_bufwin_fn(function()
    return Select_model(M._settings_buf, M._settings_win, Available_models(M.excluded_providers),
      M._select_model_fn, M._toggle_reasoning_window_fn, M.picker)
  end)
end


function M.chat()
  local chat_path = Get_hashed_project_path(M._storage_dir, M.chat_name)
  local llmfiles_path = Get_hashed_project_path(M._storage_dir, M.llmfiles_name)

  if M._chat_buf == nil or M._chat_win == nil then
    M._chat_bufwin_fn(function() return New_chat_panel(chat_path, llmfiles_path) end)
  else
    if vim.api.nvim_get_current_win() == M._chat_win or vim.api.nvim_get_current_win() == M._llmfiles_win then
      vim.api.nvim_win_close(M._chat_win, true)
      vim.api.nvim_win_close(M._llmfiles_win, true)
      M._chat_win = nil
      M._llmfiles_win = nil
      M._model_display_extmark = nil
      return
    end
  end

  if M._chat_win ~= nil and vim.api.nvim_win_is_valid(M._chat_win) then
    vim.api.nvim_set_current_win(M._chat_win)
  end
end


function M.replace()
  M._handle_prompt(false)
end


function M.help()
  M._handle_prompt(true)
end


function M.settings()
  Display_settings(M._storage_dir, M._toggle_reasoning_window_fn, M.picker)
end


function M._handle_prompt(help)
  if not M.model then
    M._update_settings({ model = M.default_model, show_reasoning = false })
  end
  local system_prompt = M._system_prompt(help)
  local opts = Get_opts(M.model, system_prompt, help, M.show_reasoning)
  if opts.show_reasoning and (M._reasoning_buf or M._reasoning_win) then
    M._reasoning_bufwin_fn(Clear_floating_display)
  end
  M._request_and_stream(opts, system_prompt)
end


function M._update_settings(settings)
  if not settings then return end
  M.show_reasoning = settings.show_reasoning
  M.model = settings.model
  M._validate_settings()
  return settings
end


function M._validate_settings()
  local available = Available_models(M.excluded_providers)
  local default_fail_msg =
      "default model isn't provided, it may not exist or you may have the provider excluded. available models: " ..
      vim.inspect(available) .. ", default model: " .. M.default_model
  validate_model(M.default_model, available, default_fail_msg)
  if not M.model or M.model == "" then return end
  local model_fail_msg =
      "selected model isn't provided, it may not exist or you may have the provider excluded. available models: " ..
      vim.inspect(available) .. ", selected model: " .. M.model
  validate_model(M.model, available, model_fail_msg)
end


function M._reasoning_bufwin_fn(f)
  local bufwin = f()
  M._reasoning_buf, M._reasoning_win = bufwin[1], bufwin[2]
  if M._reasoning_buf == nil or M._reasoning_win == nil then
    return
  end
end


function M._settings_bufwin_fn(f)
  local bufwin = f()
  M._settings_buf, M._settings_win = bufwin[1], bufwin[2]
end


function M._chat_bufwin_fn(f)
  local bufwin = f()
  M._chat_buf, M._chat_win, M._llmfiles_buf, M._llmfiles_win = bufwin[1], bufwin[2], bufwin[3], bufwin[4]
end


function M._shutdown_existing_request()
  if not M.job then
    return
  end
  M.job:shutdown()
  M._reasoning_bufwin_fn(Clear_floating_display)
  M.job = nil
end


function M._job_exit_handler(user_esc, return_val, j)
  M.job = nil
  if M._reasoning_buf and M._reasoning_win then
    M._reasoning_bufwin_fn(Clear_floating_display)
  end
  if user_esc ~= nil then
    vim.schedule(function() restore_escape_binding(user_esc) end)
  end
  if return_val ~= 0 then
    vim.schedule(function()
      vim.notify("Job failed with exit code " .. return_val .. "\nstdout:\n" ..
        table.concat(j:result(), "\n") .. "\nstderr:\n" .. table.concat(j:stderr_result(), "\n"),
        vim.log.levels.ERROR)
    end)
  end
end


function M._parse_and_handle_data(line, curr_event_state, handle_data_fn, opts, extmark_id, buf)
  local event = line:match('^event: (.+)$')
  if event then
    return event
  end

  local data = line:match('^data: (.+)$') or line:match('"candidates": (.+)$') or line:match('"text": (.+)$')
  if data then
    handle_data_fn(data, curr_event_state, opts.show_reasoning,
      function(s) Write_string_at_extmark(s, extmark_id, ns_id, buf) end,
      function(s) Write_floating_content(s, M._reasoning_buf, M._reasoning_win) end)
  end
  return curr_event_state
end


--- generic entry point for any prompt to any provider
function M._request_and_stream(opts, system_prompt)
  local prompt = Get_prompt(opts)
  local args = Make_curl_args(opts.model)(opts, prompt, system_prompt)
  local curr_event_state = nil
  ---@type string | nil
  local user_esc = create_escape_binding()
  local buf = vim.api.nvim_get_current_buf()
  local crow = unpack(vim.api.nvim_win_get_cursor(0))
  local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns_id, crow - 1, -1, {})
  local handle_data_fn = Get_data_fn(opts.model)

  M.job = M._shutdown_existing_request()
  ---@diagnostic disable-next-line: missing-fields
  M.job = Job:new({
    command = 'curl',
    args = args,
    on_stdout = function(_, out)
      curr_event_state = M._parse_and_handle_data(
        out,
        curr_event_state,
        handle_data_fn,
        opts,
        extmark_id,
        buf
      )
    end,
    on_stderr = function(_, err)
      job_error_handler(err)
    end,
    on_exit = function(j, return_val)
      M._job_exit_handler(user_esc, return_val, j)
    end
  }):start()

  if opts.show_reasoning then
    M._reasoning_bufwin_fn(function() return Open_reasoning_window(M._reasoning_buf, M._reasoning_win) end)
  end
end


function M._system_prompt(help)
  return Get_system_prompt(M.help_prompt, M.replace_prompt, M._storage_dir, M.llmfiles_name, not help)
end


function M._select_model_fn(selected_model)
  M.model = selected_model or
      Available_models(M.excluded_providers)[vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1]]
  LlmAppPrint("set model to [" .. M.model .. "]")
  M._update_settings(Write_selected_model(M._storage_dir, M.model, M.show_reasoning))
end


function M._toggle_reasoning_window_fn()
  return M._update_settings(Write_selected_model(M._storage_dir, M.model, not M.show_reasoning))
end

return M
