local config = require("neodev-dotnet.config")
local project = require("neodev-dotnet.project")

local M = {}

function M.run_in_terminal(cmd)
  local cfg = config.get().terminal

  if cfg.direction == "vertical" then
    vim.cmd("vsplit")
    if cfg.size then
      vim.cmd("vertical resize " .. cfg.size)
    end
  else
    vim.cmd("split")
    if cfg.size then
      vim.cmd("resize " .. cfg.size)
    end
  end

  vim.cmd("terminal " .. cmd)

  if cfg.start_insert then
    vim.cmd("startinsert")
  end
end

function M.run_dotnet_command(cmd, args)
  local project_root = project.find_project_root()

  if not project_root or project_root == "" then
    vim.notify("Could not find project root", vim.log.levels.ERROR)
    return
  end

  local full_cmd = string.format("cd %s && dotnet %s", project.shell_escape(project_root), cmd)
  if args then
    full_cmd = full_cmd .. " " .. args
  end

  M.run_in_terminal(full_cmd)
end

local function run_with_csproj(dotnet_cmd)
  local csproj = project.find_csproj(true)
  if csproj then
    M.run_in_terminal("dotnet " .. dotnet_cmd .. " " .. project.shell_escape(csproj))
  end
end

function M.build()
  run_with_csproj("build")
end

function M.run()
  run_with_csproj("run --project")
end

function M.test()
  run_with_csproj("test")
end

function M.watch()
  run_with_csproj("watch run --project")
end

function M.clean()
  M.run_dotnet_command("clean")
end

function M.restore()
  M.run_dotnet_command("restore")
end

return M
