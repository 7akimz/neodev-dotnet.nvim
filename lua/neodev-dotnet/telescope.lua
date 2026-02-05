local project = require("neodev-dotnet.project")
local terminal = require("neodev-dotnet.terminal")

local M = {}

function M.find_project_files()
  local project_root = project.find_project_root()

  local has_telescope, builtin = pcall(require, "telescope.builtin")
  if has_telescope then
    builtin.find_files({
      cwd = project_root,
      prompt_title = "Project Files",
      find_command = {
        "find", project_root,
        "-name", "*.cs", "-o", "-name", "*.csproj", "-o", "-name", "*.sln",
      },
    })
    return
  end

  local files = vim.fn.systemlist(
    "find " .. vim.fn.shellescape(project_root) ..
    " -name '*.cs' -o -name '*.csproj' -o -name '*.sln'"
  )
  if #files == 0 then
    vim.notify("No project files found", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, f in ipairs(files) do
    table.insert(items, { filename = f, lnum = 1, text = f })
  end
  vim.fn.setqflist(items, "r")
  vim.cmd("copen")
end

function M.open_project_file()
  local project_root = project.find_project_root()
  local sln = vim.fn.glob(project_root .. "/*.sln")
  local csproj = vim.fn.glob(project_root .. "/*.csproj")
  if sln ~= "" then
    vim.cmd("edit " .. vim.fn.fnameescape(sln))
  elseif csproj ~= "" then
    vim.cmd("edit " .. vim.fn.fnameescape(csproj))
  else
    vim.notify("No project file found", vim.log.levels.WARN)
  end
end

function M.select_and_run_project()
  local sln_root = project.find_project_root()

  local has_telescope, builtin = pcall(require, "telescope.builtin")
  if has_telescope then
    builtin.find_files({
      cwd = sln_root,
      prompt_title = "Select Project",
      find_command = { "find", sln_root, "-name", "*.csproj", "-type", "f" },
      attach_mappings = function(_, map)
        map("i", "<CR>", function(prompt_bufnr)
          local selection = require("telescope.actions.state").get_selected_entry()
          require("telescope.actions").close(prompt_bufnr)
          if selection then
            terminal.run_in_terminal("dotnet run --project " .. project.shell_escape(selection.path))
          end
        end)
        return true
      end,
    })
    return
  end

  local files = vim.fn.systemlist(
    "find " .. vim.fn.shellescape(sln_root) .. " -name '*.csproj' -type f"
  )
  if #files == 0 then
    vim.notify("No .csproj files found", vim.log.levels.INFO)
    return
  end

  vim.ui.select(files, { prompt = "Select project to run:" }, function(choice)
    if choice then
      terminal.run_in_terminal("dotnet run --project " .. project.shell_escape(choice))
    end
  end)
end

return M
