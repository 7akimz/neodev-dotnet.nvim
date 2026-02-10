if vim.g.loaded_neodev_dotnet then
  return
end
vim.g.loaded_neodev_dotnet = true

if vim.fn.has("nvim-0.11") ~= 1 then
  vim.notify("neodev-dotnet requires Neovim >= 0.11", vim.log.levels.ERROR)
  return
end

local augroup = vim.api.nvim_create_augroup("neodev_dotnet", { clear = true })

require("neodev-dotnet.commands").register()

vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = "cs",
  callback = function(event)
    local config = require("neodev-dotnet.config").get()
    if not config.keymaps.enabled then
      return
    end

    local bufnr = event.buf
    local prefix = config.keymaps.prefix
    local km = config.keymaps

    local function map(key, fn, desc)
      vim.keymap.set("n", prefix .. key, fn, { buffer = bufnr, desc = ".NET: " .. desc })
    end

    local terminal = require("neodev-dotnet.terminal")
    map(km.build, terminal.build, "Build")
    map(km.run, terminal.run, "Run")
    map(km.test, terminal.test, "Test")
    map(km.watch, terminal.watch, "Watch Run")
    map(km.clean, terminal.clean, "Clean")
    map(km.restore, terminal.restore, "Restore")

    local telescope = require("neodev-dotnet.telescope")
    map(km.find_files, telescope.find_project_files, "Find Project Files")
    map(km.open_project, telescope.open_project_file, "Open Project File")
    map(km.list_projects, telescope.select_and_run_project, "Run Project from List")

    if config.codegen.enabled then
      local codegen = require("neodev-dotnet.codegen")
      map(km.new_class, codegen.new_class, "New Class")
      map(km.new_interface, codegen.new_interface, "New Interface")
    end

    vim.defer_fn(function()
      local debug = require("neodev-dotnet.debug")
      debug.setup()
      debug.set_keymaps()
    end, 0)
  end,
})

vim.api.nvim_create_autocmd("User", {
  group = augroup,
  pattern = "RoslynInitialized",
  callback = function()
    local navigation = require("neodev-dotnet.navigation")
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "cs" then
        navigation.attach(buf)
      end
    end
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = augroup,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or client.name ~= "roslyn" then
      return
    end

    if vim.bo[event.buf].filetype ~= "cs" then
      return
    end

    local config = require("neodev-dotnet.config").get()
    if not config.navigation.implementation_fallback then
      return
    end

    local navigation = require("neodev-dotnet.navigation")
    navigation.attach(event.buf)
  end,
})
