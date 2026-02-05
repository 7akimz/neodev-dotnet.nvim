local project = require("neodev-dotnet.project")
local terminal = require("neodev-dotnet.terminal")

local M = {}

local function dotnet_new(template, prompt)
  local project_root = project.find_project_root()
  local name = vim.fn.input(prompt)
  if name == "" then return end

  local cmd = string.format(
    "cd %s && dotnet new %s -n %s",
    project.shell_escape(project_root),
    template,
    vim.fn.shellescape(name)
  )
  terminal.run_in_terminal(cmd)
end

function M.new_class()
  dotnet_new("class", "Class name: ")
end

function M.new_interface()
  dotnet_new("interface", "Interface name: ")
end

return M
