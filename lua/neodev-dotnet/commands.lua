local M = {}

local subcommands = {
  build = function() require("neodev-dotnet.terminal").build() end,
  run = function() require("neodev-dotnet.terminal").run() end,
  test = function() require("neodev-dotnet.terminal").test() end,
  watch = function() require("neodev-dotnet.terminal").watch() end,
  clean = function() require("neodev-dotnet.terminal").clean() end,
  restore = function() require("neodev-dotnet.terminal").restore() end,
  ["new-class"] = function() require("neodev-dotnet.codegen").new_class() end,
  ["new-interface"] = function() require("neodev-dotnet.codegen").new_interface() end,
  ["find-files"] = function() require("neodev-dotnet.telescope").find_project_files() end,
  ["open-project"] = function() require("neodev-dotnet.telescope").open_project_file() end,
  ["list-projects"] = function() require("neodev-dotnet.telescope").select_and_run_project() end,
  info = function() require("neodev-dotnet.debug").show_info() end,
}

local subcommand_names = vim.tbl_keys(subcommands)
table.sort(subcommand_names)

function M.register()
  vim.api.nvim_create_user_command("DotNet", function(opts)
    local subcmd = opts.fargs[1]
    if not subcmd then
      vim.notify("Usage: :DotNet <subcommand>", vim.log.levels.WARN)
      return
    end

    local handler = subcommands[subcmd]
    if not handler then
      vim.notify("Unknown subcommand: " .. subcmd, vim.log.levels.ERROR)
      return
    end

    handler()
  end, {
    nargs = 1,
    complete = function(arg_lead)
      return vim.tbl_filter(function(cmd)
        return cmd:find(arg_lead, 1, true) == 1
      end, subcommand_names)
    end,
    desc = ".NET Core development commands",
  })
end

return M
