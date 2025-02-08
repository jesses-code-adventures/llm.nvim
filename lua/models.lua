MODELS = {
  'claude-3-5-sonnet-20241022',
  'gemini-2.0-flash',
  'gpt-4o',
  'deepseek-chat',
  'deepseek-reasoner',
}

MODELS_CAN_REASON = {
  'deepseek-reasoner'
}

local function verify(model)
  for _, m in ipairs(MODELS) do
    if model == m then
      return model
    end
  end
  error("invalid model [" .. model .. "]")
end

---@return boolean
local function can_reason(model, show_reasoning)
  if not show_reasoning then
    return false
  end
  for _, m in ipairs(MODELS_CAN_REASON) do
    if model == m then
      return true
    end
    return false
  end
end

local function openai_replace_opts(model, system_prompt, show_reasoning)
  return {
    url = 'https://api.openai.com/v1/chat/completions',
    model = verify(model),
    api_key_name = 'OPENAI_API_KEY',
    system_prompt = system_prompt,
    replace = true,
    show_reasoning = can_reason(model, show_reasoning),
  }
end

local function openai_help_opts(model, system_prompt, show_reasoning)
  return {
    url = 'https://api.openai.com/v1/chat/completions',
    model = verify(model),
    api_key_name = 'OPENAI_API_KEY',
    system_prompt = system_prompt,
    replace = false,
    show_reasoning = can_reason(model, show_reasoning),
  }
end

local function anthropic_help_opts(model, system_prompt, show_reasoning)
  return {
    url = 'https://api.anthropic.com/v1/messages',
    model = verify(model),
    api_key_name = 'ANTHROPIC_API_KEY',
    system_prompt = system_prompt,
    replace = false,
    show_reasoning = can_reason(model, show_reasoning),
  }
end

local function anthropic_replace_opts(model, system_prompt, show_reasoning)
  return {
    url = 'https://api.anthropic.com/v1/messages',
    model = verify(model),
    api_key_name = 'ANTHROPIC_API_KEY',
    system_prompt = system_prompt,
    replace = true,
    show_reasoning = can_reason(model, show_reasoning),
  }
end

local function deepseek_help_opts(model, system_prompt, show_reasoning)
  return {
    url = 'https://api.deepseek.com/v1/chat/completions',
    model = verify(model),
    api_key_name = 'DEEPSEEK_API_KEY',
    system_prompt = system_prompt,
    replace = false,
    show_reasoning = can_reason(model, show_reasoning),
  }
end

local function deepseek_replace_opts(model, system_prompt, show_reasoning)
  return {
    url = 'https://api.deepseek.com/v1/chat/completions',
    model = verify(model),
    api_key_name = 'DEEPSEEK_API_KEY',
    system_prompt = system_prompt,
    replace = true,
    show_reasoning = can_reason(model, show_reasoning),
  }
end

local function gemini_help_opts(model, system_prompt, show_reasoning)
  return {
    url = 'https://generativelanguage.googleapis.com/v1beta/models',
    model = verify(model),
    api_key_name = 'GEMINI_API_KEY',
    system_prompt = system_prompt,
    replace = false,
    show_reasoning = can_reason(model, show_reasoning),
  }
end

local function gemini_replace_opts(model, system_prompt, show_reasoning)
  return {
    url = 'https://generativelanguage.googleapis.com/v1beta/models',
    model = verify(model),
    api_key_name = 'GEMINI_API_KEY',
    system_prompt = system_prompt,
    replace = true,
    show_reasoning = can_reason(model, show_reasoning),
  }
end

local function help_opts(model, system_prompt, show_reasoning)
  local provider = Model_to_provider(model)
  local help_fn = nil
  if provider == 'anthropic' then
    help_fn = anthropic_help_opts
  end
  if provider == 'openai' then
    help_fn = openai_help_opts
  end
  if provider == 'deepseek' then
    help_fn = deepseek_help_opts
  end
  if provider == 'gemini' then
    help_fn = gemini_help_opts
  end
  if help_fn == nil then
    error("no help fn for [" .. model .. "]")
  end
  return help_fn(model, system_prompt, show_reasoning)
end

local function replace_opts(model, system_prompt, show_reasoning)
  local provider = Model_to_provider(model)
  local replace_fn = nil
  if provider == 'anthropic' then
    replace_fn = anthropic_replace_opts
  end
  if provider == 'openai' then
    replace_fn = openai_replace_opts
  end
  if provider == 'deepseek' then
    replace_fn = deepseek_replace_opts
  end
  if provider == 'gemini' then
    replace_fn = gemini_replace_opts
  end
  if replace_fn == nil then
    error("no replace fn for [" .. model .. "]")
  end
  return replace_fn(model, system_prompt, show_reasoning)
end

---@param model string
---@param help boolean 
---@param reason boolean 
function Get_opts(model, system_prompt, help, reason)
  if model == nil or model == "" then
    error("model not set in opts")
  end
  model = string.lower(model)
  if help then
    return help_opts(model, system_prompt, reason)
  end
  return replace_opts(model, system_prompt, reason)
end
