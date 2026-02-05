local M = {}

local defaults = {
  keymaps = {
    enabled = true,
    prefix = "<leader>dn",
    build = "b",
    run = "r",
    test = "t",
    watch = "w",
    clean = "c",
    restore = "p",
    find_files = "f",
    open_project = "o",
    list_projects = "l",
    new_class = "n",
    new_interface = "i",
  },
  terminal = {
    direction = "horizontal",
    size = 15,
    start_insert = true,
  },
  debug = {
    enabled = true,
    netcoredbg_path = vim.env.NETCOREDBG_PATH or "~/.local/bin/netcoredbg",
    auto_setup_dapui = true,
    virtual_text = true,
    keymaps = {
      continue = "<F5>",
      step_over = "<F10>",
      step_into = "<F11>",
      step_out = "<F12>",
      terminate = "<S-F5>",
      toggle_breakpoint = "<leader>b",
      conditional_breakpoint = "<leader>B",
      repl = "<leader>dr",
      run_last = "<leader>dl",
      toggle_ui = "<leader>dt",
      info = "<leader>di",
      list_breakpoints = "<leader>dB",
    },
    configurations = nil,
  },
  navigation = {
    implementation_fallback = true,
    fallback_keymap = "gi",
    exclude_dirs = { "bin", "obj", ".git", "node_modules", "TestResults" },
  },
  codegen = {
    enabled = true,
  },
}

local config = vim.deepcopy(defaults)

function M.setup(user_config)
  config = vim.tbl_deep_extend("force", defaults, user_config or {})
end

function M.get()
  return config
end

return M
