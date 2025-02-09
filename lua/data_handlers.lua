local function handle_anthropic_spec_data(data_stream, event_state, _, write_fn, _)
  if event_state == 'content_block_delta' then
    local json = vim.json.decode(data_stream)
    if json.delta and json.delta.text then
      write_fn(json.delta.text)
    else
      print("no choices found")
      print(vim.inspect(json))
    end
  end
end

local function handle_openai_spec_data(data_stream, _, _, write_fn, _)
  if data_stream:match '"delta":' then
    local json = vim.json.decode(data_stream)
    if json.choices and json.choices[1] and json.choices[1].delta then
      local content = json.choices[1].delta.content
      if content then
        write_fn(content)
      end
    else
      print("no choices found")
      print(vim.inspect(json))
    end
  end
end

local function handle_deepseek_reasoning_data(data_stream, _, show_reasoning, write_fn, write_reasoning_fn)
  if data_stream:match '"delta":' then
    local json = vim.json.decode(data_stream)
    if json.choices and json.choices[1] and json.choices[1].delta then
      local content = json.choices[1].delta.content
      if content then
        write_fn(content)
      end
      local reasoning_content = json.choices[1].delta.reasoning_content
      if reasoning_content and show_reasoning then
        write_reasoning_fn(reasoning_content)
      end
    else
      print("no choices found")
      print(vim.inspect(json))
    end
  end
end

-- TODO: use, if we choose to handle the whole json object in handle_google_spec_data
local function get_google_response_text(json)
  if not json.candidates then
    return ""
  end
  if not json.candidates[1] then
    return ""
  end
  if not json.candidates[1].content then
    return ""
  end
  if not json.candidates[1].content.parts then
    return ""
  end
  if not json.candidates[1].content.parts[1] then
    return ""
  end
  return json.candidates[1].content.parts[1].text
end

-- TODO: fix gemini
local function handle_google_spec_data(data_stream, event_state, _, write_fn, _)
  if data_stream then
    write_fn(vim.json.decode('{' .. data_stream .. '}').text)
  else
    print("no choices found")
  end
end

local function handle_groq_spec_data(data_stream, _, _, write_fn, _)
  if data_stream:match '"delta":' then
    local json = vim.json.decode(data_stream)
    if json.choices and json.choices[1] and json.choices[1].delta then
      local content = json.choices[1].delta.content
      if content then
        write_fn(content)
      end
    else
      print("no choices found")
      print(vim.inspect(json))
    end
  end
end


---@param model string
function Get_data_fn(model)
  if model == nil or model == "" then
    error("model not set in opts")
  end
  model = string.lower(model)
  local provider = Model_to_provider(model)
  if provider == 'anthropic' then
    return handle_anthropic_spec_data
  end
  if provider == 'deepseek' then
    return handle_deepseek_reasoning_data
  end
  if provider == 'openai' then
    return handle_openai_spec_data
  end
  if provider == 'google' then
    return handle_google_spec_data
  end
  if provider == 'groq' then
    return handle_groq_spec_data
  end
  error("provider not handled - " .. provider)
end
