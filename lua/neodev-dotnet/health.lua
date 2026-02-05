local M = {}

function M.check()
  vim.health.start("neodev-dotnet")

  if vim.fn.executable("dotnet") == 1 then
    local version = vim.fn.system("dotnet --version"):gsub("%s+$", "")
    vim.health.ok("dotnet found: " .. version)
  else
    vim.health.error("dotnet not found", { "Install .NET SDK from https://dotnet.microsoft.com" })
  end

  local config = require("neodev-dotnet.config").get()
  local netcoredbg_path = vim.fn.expand(config.debug.netcoredbg_path)
  if vim.fn.executable(netcoredbg_path) == 1 then
    vim.health.ok("netcoredbg found: " .. netcoredbg_path)
  else
    vim.health.warn("netcoredbg not found at " .. netcoredbg_path, {
      "Install netcoredbg for debugging support",
      "Set NETCOREDBG_PATH or configure debug.netcoredbg_path",
    })
  end

  if vim.fn.executable("rg") == 1 then
    vim.health.ok("ripgrep found (used for implementation fallback)")
  else
    vim.health.warn("ripgrep not found", {
      "Install ripgrep for implementation fallback search",
    })
  end

  local has_telescope = pcall(require, "telescope")
  if has_telescope then
    vim.health.ok("telescope.nvim found")
  else
    vim.health.info("telescope.nvim not found (quickfix will be used instead)")
  end

  local has_dap = pcall(require, "dap")
  if has_dap then
    vim.health.ok("nvim-dap found")
  else
    vim.health.info("nvim-dap not found (debugging disabled)")
  end

  local has_dapui = pcall(require, "dapui")
  if has_dapui then
    vim.health.ok("nvim-dap-ui found")
  else
    vim.health.info("nvim-dap-ui not found (debug UI disabled)")
  end

  local has_roslyn = pcall(require, "roslyn")
  if has_roslyn then
    vim.health.ok("roslyn.nvim found")
  else
    vim.health.info("roslyn.nvim not found (C# LSP features require roslyn.nvim)")
  end
end

return M
