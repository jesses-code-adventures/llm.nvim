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

