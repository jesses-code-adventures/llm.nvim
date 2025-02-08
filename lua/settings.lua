require("utils")

local function settings_path(dir)
  return vim.fs.joinpath(dir, "settings.json")
end

function Write_selected_model(dir, model, reasoning)
  vim.fn.mkdir(dir, "p")
  local path = settings_path(dir)
  local settings = {
    model = model,
    show_reasoning = reasoning,
  }
  Write_json(settings, path)
end

function Get_settings(dir)
  return Read_json(settings_path(dir))
end

