local M = {}

function M.shell_escape(str)
  if not str then return "" end
  return vim.fn.shellescape(str)
end

function M.validate_path(path)
  if not path or path == "" then
    return false, "No path provided"
  end

  path = vim.fn.expand(path)

  if vim.fn.filereadable(path) ~= 1 and vim.fn.isdirectory(path) ~= 1 then
    return false, "Path does not exist: " .. path
  end

  return true, path
end

function M.find_project_root()
  local current_file = vim.fn.expand("%:p:h")
  local csproj = vim.fn.findfile("*.csproj", current_file .. ";")
  if csproj ~= "" then
    return vim.fn.fnamemodify(csproj, ":p:h")
  end
  local sln = vim.fn.findfile("*.sln", current_file .. ";")
  if sln ~= "" then
    return vim.fn.fnamemodify(sln, ":p:h")
  end
  return vim.fn.getcwd()
end

function M.get_project_dir(csproj_path)
  return vim.fn.fnamemodify(csproj_path, ":h")
end

function M.find_csproj(prompt_if_missing)
  local current_file = vim.fn.expand("%:p:h")
  local csproj = vim.fn.findfile("*.csproj", current_file .. ";")
  if csproj ~= "" then
    return vim.fn.fnamemodify(csproj, ":p")
  end

  if not prompt_if_missing then
    return nil
  end

  local user_input = vim.fn.input("Path to .csproj file: ", current_file .. "/", "file")
  if user_input == "" then
    return nil
  end

  local is_valid, validated_path = M.validate_path(user_input)
  if not is_valid then
    vim.notify("Error: " .. validated_path, vim.log.levels.ERROR)
    return nil
  end

  if not string.match(validated_path, "%.csproj$") then
    vim.notify("Error: File must be a .csproj file", vim.log.levels.ERROR)
    return nil
  end

  return validated_path
end

function M.find_dll()
  local csproj = M.find_csproj(true)
  if not csproj or csproj == "" then
    return ""
  end

  local project_dir = M.get_project_dir(csproj)
  local project_name = vim.fn.fnamemodify(csproj, ":t:r")

  local patterns = {
    project_dir .. "/bin/Debug/net*/" .. project_name .. ".dll",
    project_dir .. "/bin/Debug/net*/" .. project_name .. ".exe",
    project_dir .. "/bin/Debug/**/" .. project_name .. ".dll",
  }

  for _, pattern in ipairs(patterns) do
    local files = vim.fn.glob(pattern, false, true)
    if #files > 0 then
      table.sort(files, function(a, b) return a > b end)
      return files[1]
    end
  end

  return vim.fn.input("Path to DLL: ", project_dir .. "/bin/Debug/", "file")
end

function M.build_project()
  local csproj = M.find_csproj(true)
  if not csproj or csproj == "" then
    return false
  end

  vim.notify("Building project...", vim.log.levels.INFO)
  local result = vim.fn.system('dotnet build "' .. csproj .. '" --configuration Debug')
  if vim.v.shell_error ~= 0 then
    vim.notify("Build failed: " .. result, vim.log.levels.ERROR)
    return false
  end
  vim.notify("Build succeeded", vim.log.levels.INFO)
  return true
end

return M
