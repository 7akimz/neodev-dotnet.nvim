local project = require("neodev-dotnet.project")

local M = {}

local DEFAULT_ENV = { ASPNETCORE_ENVIRONMENT = "Development" }

function M.find_launch_settings()
  local csproj = project.find_csproj(false)
  if not csproj then
    return nil
  end

  local project_dir = project.get_project_dir(csproj)
  local path = project_dir .. "/Properties/launchSettings.json"

  if vim.fn.filereadable(path) == 1 then
    return path
  end

  return nil
end

function M.get_launch_env()
  local path = M.find_launch_settings()
  if not path then
    return DEFAULT_ENV
  end

  local content = vim.fn.readfile(path)
  if not content or #content == 0 then
    return DEFAULT_ENV
  end

  local ok, data = pcall(vim.fn.json_decode, table.concat(content, "\n"))
  if not ok or not data or not data.profiles then
    return DEFAULT_ENV
  end

  local profile
  for _, p in pairs(data.profiles) do
    if p.commandName == "Project" then
      profile = p
      break
    end
  end
  if not profile then
    _, profile = next(data.profiles)
  end
  if not profile or not profile.environmentVariables then
    return DEFAULT_ENV
  end

  local env = {}
  local project_dir = vim.fn.fnamemodify(path, ":h:h")

  for key, value in pairs(profile.environmentVariables) do
    if type(value) == "string" then
      if (key:match("CREDENTIALS") or key:match("PATH") or key:match("FILE")) and not value:match("^/") then
        value = project_dir .. "/" .. value
      end
      env[key] = value
    end
  end

  if profile.applicationUrl then
    env.ASPNETCORE_URLS = profile.applicationUrl
  end

  return env
end

return M
