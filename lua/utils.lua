local Job = require 'plenary.job'

function LlmAppPrint(message)
  print('LLM: ' .. message)
end

function String_startswith(v, sub)
  if v:find("^" .. sub:gsub("(%W)", "%%%1")) then
    return true
  end
  return false
end

function Strip_string(input, chars)
  chars = chars or "%s" -- default to whitespace
  return input:match("^[" .. chars .. "]*(.-)[" .. chars .. "]*$") or ""
end

function Read_json(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
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
        LlmAppPrint("Failed to write to file: " .. path)
      end
    end,
  }):start()
end
