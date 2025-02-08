require("curl_args")
require("data_fn")
require("models")
require("llm_files")
require("floating_window")
require("settings")
require("prompt")

local Job = require 'plenary.job'

local group = vim.api.nvim_create_augroup('DING_LLM_AutoGroup', { clear = true })
local active_job = nil

local M = {
  _reasoning_win = nil,
  _reasoning_buf = nil,
}

function M.setup(opts)
  M.opts = opts
end

function M._reasoning_bufwin_fn(f)
  local bufwin = f()
  M._reasoning_buf = bufwin[1]
  M._reasoning_win = bufwin[2]
end

function M.invoke_llm_and_stream_into_editor(opts)
  local prompt = Get_prompt(opts)
  local system_prompt = Get_system_prompt(opts)
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
      handle_data_fn(data_match, curr_event_state, opts.show_reasoning, Write_string_at_cursor, function(s) Write_floating_content(s, M._reasoning_buf, M._reasoning_win) end)
    end
  end

  if active_job then
    active_job:shutdown()
    active_job = nil
    M._reasoning_bufwin_fn(Clear_floating_display())
  end

  active_job = Job:new {
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
        -- job failed, print the error message
        vim.schedule(function()
          local result = table.concat(j:result(), "\n")
          local stderr = table.concat(j:stderr_result(), "\n")
          vim.notify("Job failed with exit code " .. return_val .. "\nstdout:\n" .. result .. "\nstderr:\n" .. stderr,
            vim.log.levels.ERROR)
        end)
      end
    end, }

  active_job:start()
  return active_job
end

function M.handle_prompt(help)
  local settings = Get_settings()
  local opts = Get_opts(settings.model, nil, help, settings.show_reasoning)
  for k, v in pairs(M.opts) do
    opts[k] = v
  end
  if settings.show_reasoning and M._reasoning_buf ~= nil or M._reasoning_win ~= nil then
    M._reasoning_bufwin_fn(Clear_floating_display)
  end
  vim.api.nvim_clear_autocmds { group = group }
  M.invoke_llm_and_stream_into_editor(opts)
  if settings.show_reasoning then
    M._reasoning_bufwin_fn(Open_floating_window)
  end
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'DING_LLM_Escape',
    callback = function()
      if active_job then
        active_job:shutdown()
        print 'LLM streaming cancelled'
        active_job = nil
      end
      M._reasoning_bufwin_fn(Clear_floating_display)
    end,
  })
  vim.api.nvim_set_keymap('n', '<Esc>', ':doautocmd User DING_LLM_Escape<CR>', { noremap = true, silent = true })
end

function M.replace()
  print("hit replace")
  M.handle_prompt(false)
end

function M.help()
  print("hit help")
  M.handle_prompt(true)
end

return M
