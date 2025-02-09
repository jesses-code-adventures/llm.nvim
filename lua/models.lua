MODELS = {
  'anthropic-claude-3-5-haiku-20241022',
  'anthropic-claude-3-5-sonnet-20240620',
  'anthropic-claude-3-5-sonnet-20241022',
  'deepseek-deepseek-chat',
  'deepseek-deepseek-reasoner',
  'google-gemini-2.0-flash', --TODO: fix google
  'google-gemini-2.0-flash-lite-preview-02-05', --TODO: fix google
  'groq-deepseek-r1-distill-llama-70b',
  'groq-llama-3.1-8b-instant',
  'groq-llama-3.2-1b-preview',
  'groq-llama-3.2-3b-preview',
  'groq-llama-guard-3-8b',
  'groq-llama3-70b-8192',
  'groq-llama3-8b-8192',
  'groq-mixtral-8x7b-32768',
  'openai-gpt-4o',
  'openai-gpt-4o-mini',
  'openai-o1',
  'openai-o1-mini',
  'openai-o1-preview',
  'openai-o3-mini',
}

MODELS_CAN_REASON = {
  'deepseek-reasoner'
}

function Model_to_provider(v)
  v = string.lower(v)
  if String_startswith(v, "anthropic-") then
    return 'anthropic'
  elseif String_startswith(v, "openai-") then
    return 'openai'
  elseif String_startswith(v, 'deepseek-') then
    return 'deepseek'
  elseif String_startswith(v, 'google-') then
    return 'google'
  elseif String_startswith(v, 'groq-') then
    return 'groq'
  end
  error("no provider for model [" .. v .. "]")
end

local function verify(model)
  for _, m in ipairs(MODELS) do
    if model == m then
      return model
    end
  end
  error("invalid model [" .. model .. "]")
end

---@param excluded_providers table<string>
---@return table<string>
function Available_models(excluded_providers)
  local resp = {}
  for _, m in ipairs(MODELS) do
    local provider = Model_to_provider(m)
    for _, p in ipairs(excluded_providers) do
      if provider == p then
        goto continue
      end
    end
    table.insert(resp, m)
    ::continue::
  end
  return resp
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

local function gen_opts(api_key_name, model, system_prompt, show_reasoning, replace)
  return {
    model = verify(model),
    api_key_name = api_key_name,
    system_prompt = system_prompt,
    replace = replace,
    show_reasoning = can_reason(model, show_reasoning)
  }
end

---@param model string
---@param help boolean 
---@param reason boolean 
function Get_opts(model, system_prompt, help, reason)
  if model == nil or model == "" then
    error("model not set in opts")
  end
  model = string.lower(model)
  return gen_opts(Model_to_provider(model):upper() .. '_API_KEY', model, system_prompt, reason, not help)
end
