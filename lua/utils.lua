local Job = require 'plenary.job'

function String_startswith(v, sub)
  if v:find("^" .. sub:gsub("(%W)", "%%%1")) then
    return true
  end
  return false
end

function Model_to_provider(v)
  v = string.lower(v)
  if String_startswith(v, "claude") then
    return 'anthropic'
  elseif String_startswith(v, "gpt") then
    return 'openai'
  elseif String_startswith(v, 'deepseek') then
    return 'deepseek'
  elseif String_startswith(v, 'gemini') then
    return 'gemini'
  end
  error("no provider for model [" .. v .. "]")
end

function Read_json(path)
  local file = io.open(path, "r") -- "r" for read mode
  if not file then
    error("Could not open file: " .. path)
    return nil
  end
  local content = file:read("*a") -- read the entire file
  file:close()

  local ok, json_data = pcall(vim.fn.json_decode, content)
  if not ok then
    error("Failed to parse JSON from file: " .. path)
    return nil
  end

  return json_data
end


function Write_json(contents, path)
  local json_data = vim.fn.json_encode(contents)
  ---@diagnostic disable-next-line: missing-fields
  Job:new({
    command = 'tee',
    args = { path },
    writer = json_data,
    on_exit = function(_, return_val)
      if return_val ~= 0 then
        print("Failed to write to file: " .. path)
      end
    end,
  }):start()
end
