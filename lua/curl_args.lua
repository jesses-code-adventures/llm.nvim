require("utils")

local function construct_args(data)
  return { '-N', '-X', 'POST', '-H', 'Content-Type: application/json', '--no-progress-meter', '-d', vim.json.encode(data) }
end

local function get_api_key(name)
  return os.getenv(name)
end

local function make_anthropic_spec_curl_args(opts, prompt, system_prompt)
  local url = 'https://api.anthropic.com/v1/messages'
  local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
  local data = {
    system = system_prompt,
    messages = { { role = 'user', content = prompt } },
    model = opts.model,
    stream = true,
    max_tokens = 4096,
  }
  local args = construct_args(data)
  if api_key then
    table.insert(args, '-H')
    table.insert(args, 'x-api-key: ' .. api_key)
    table.insert(args, '-H')
    table.insert(args, 'anthropic-version: 2023-06-01')
  end
  table.insert(args, url)
  return args
end

local function make_openai_spec_curl_args(opts, prompt, system_prompt)
  local url = 'https://api.openai.com/v1/chat/completions'
  local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
  local data = {
    messages = { { role = 'system', content = system_prompt }, { role = 'user', content = prompt } },
    model = opts.model,
    temperature = 0.7,
    stream = true,
  }
  local args = construct_args(data)
  if api_key then
    table.insert(args, '-H')
    table.insert(args, 'Authorization: Bearer ' .. api_key)
  end
  table.insert(args, url)
  return args
end

local function make_deepseek_spec_curl_args(opts, prompt, system_prompt)
  local url = 'https://api.deepseek.com/v1/chat/completions'
  local api_key = opts.api_key_name and get_api_key(opts.api_key_name)
  local data = {
    messages = { { role = 'system', content = system_prompt }, { role = 'user', content = prompt } },
    model = opts.model,
    temperature = 0.0,
    stream = true,
  }
  local args = construct_args(data)
  if api_key then
    table.insert(args, '-H')
    table.insert(args, 'Authorization: Bearer ' .. api_key)
  end
  table.insert(args, url)
  return args
end

local function make_gemini_spec_curl_args(opts, prompt, system_prompt)
  local url = 'https://generativelanguage.googleapis.com/v1beta/models/' .. opts.model .. ":streamGenerateContent?key=" .. opts.api_key_name and get_api_key(opts.api_key_name)
  local data = {
    system_instruction = { { parts = { { text = system_prompt } } } },
    contents = { { parts = { { text = prompt } } } },
    safety_settings = { { threshold = "BLOCK_NONE" } },
    temperature = 0.2,
  }
  local args = { '--no-buffer', '-X', 'POST', '-H', 'Content-Type: application/json', '-d', vim.json.encode(data) }
  table.insert(args, url)
  return args
end

---@param model string
function Make_curl_args(model)
  if model == nil or model == "" then
    error("model not set in opts")
  end
  local provider = Model_to_provider(model)
  if provider == 'anthropic' then
    return make_anthropic_spec_curl_args
  end
  if provider == 'deepseek' then
    return make_deepseek_spec_curl_args
  end
  if provider == 'openai' then
    return make_openai_spec_curl_args
  end
  if provider == 'gemini' then
    return make_gemini_spec_curl_args
  end
  error("no handle function for provider [" .. provider .. "]")
end
