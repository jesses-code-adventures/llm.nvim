---@class LlmFileType
---@field path string
---@field contents string

local LlmFile = {}
LlmFile.__index = LlmFile

---@param path string
---@param contents string
function LlmFile.new(path, contents)
  local self = setmetatable({}, LlmFile)
  self.path = path
  self.contents = contents
  return self
end

function LlmFile:formatted_contents()
  return string.format("<contentblock file=%s>\n%s\n</contentblock>", self.path, self.contents)
end

---@return string[]
function Get_llmfile_paths()
  local contents = {}
  local current_dir = vim.fn.getcwd()
  local file_path = current_dir .. "/.llmfiles"

  local file = io.open(file_path, "r")
  if not file then
    return {}
  end

  for line in file:lines() do
    local trimmed_line = line:match("^%s*(.-)%s*$")
    if trimmed_line ~= "" then
      table.insert(contents, trimmed_line)
    end
  end


  file:close()
  return contents
end

---@param llm_paths string[]
---@param system_prompt string
function System_prompt_with_llm_files(llm_paths, system_prompt)
  local files_string = "<system_prompt>\n" .. system_prompt .. "\n</system_prompt>"
  for _, p in ipairs(llm_paths) do
    local attributes = vim.loop.fs_stat(p)
    if attributes and attributes.type == "directory" then
      error("Expected file path but got directory: " .. p)
    end
    local f = io.open(p, "r")
    if f then
      local llm_file = LlmFile.new(p, f:read("*all"))
      files_string = files_string .. "\n\n" .. llm_file:formatted_contents()
      f:close()
    else
      vim.notify("no file found: " .. p, vim.log.levels.WARN)
    end
  end
  return files_string
end

