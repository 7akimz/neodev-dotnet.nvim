local config = require("neodev-dotnet.config")
local project = require("neodev-dotnet.project")
local launch_settings = require("neodev-dotnet.launch_settings")

local M = {}

local setup_done = false
local keymaps_done = false

local function get_cwd()
  local csproj = project.find_csproj(true)
  return csproj and project.get_project_dir(csproj) or vim.fn.getcwd()
end

function M.show_info()
  local csproj = project.find_csproj(false)
  if csproj then
    vim.notify("Project: " .. csproj, vim.log.levels.INFO)
  end
  local cfg = config.get().debug
  local dbg_path = vim.fn.expand(cfg.netcoredbg_path)
  vim.notify("Netcoredbg: " .. (vim.fn.executable(dbg_path) == 1 and "Found" or "Not found"), vim.log.levels.INFO)
end

local function setup_signs_and_highlights()
  local signs = {
    { name = "DapBreakpoint", text = "●", fg = "#e06c75" },
    { name = "DapBreakpointCondition", text = "◆", fg = "#e5c07b" },
    { name = "DapLogPoint", text = "▶", fg = "#61afef" },
    { name = "DapStopped", text = "▶", fg = "#98c379" },
    { name = "DapBreakpointRejected", text = "✗", fg = "#e06c75" },
  }

  for _, sign in ipairs(signs) do
    vim.fn.sign_define(sign.name, {
      text = sign.text,
      texthl = sign.name,
      linehl = sign.name == "DapStopped" and "DapStoppedLine" or "",
      numhl = "",
    })
    vim.api.nvim_set_hl(0, sign.name, { fg = sign.fg })
  end

  vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#2e3440" })
end

local function setup_dapui(dap)
  local dapui_ok, dapui = pcall(require, "dapui")
  if not dapui_ok then return end

  dapui.setup({
    layouts = {
      {
        elements = {
          { id = "scopes", size = 0.25 },
          { id = "breakpoints", size = 0.25 },
          { id = "stacks", size = 0.25 },
          { id = "watches", size = 0.25 },
        },
        size = 0.33,
        position = "right",
      },
      {
        elements = {
          { id = "repl", size = 0.5 },
          { id = "console", size = 0.5 },
        },
        size = 0.27,
        position = "bottom",
      },
    },
  })

  dap.listeners.after.event_initialized["neodev_dotnet"] = function() dapui.open() end
  dap.listeners.before.event_terminated["neodev_dotnet"] = function() dapui.close() end
  dap.listeners.before.event_exited["neodev_dotnet"] = function() dapui.close() end
end

local function setup_virtual_text()
  local vt_ok, virtual_text = pcall(require, "nvim-dap-virtual-text")
  if not vt_ok then return end

  virtual_text.setup({
    enabled = true,
    enabled_commands = true,
    highlight_changed_variables = true,
    highlight_new_as_changed = false,
    show_stop_reason = true,
    commented = false,
    only_first_definition = true,
    all_references = false,
    filter_references_pattern = "<module",
    virt_text_pos = "eol",
    all_frames = false,
    virt_lines = false,
    virt_text_win_col = nil,
  })
end

local function is_user_code(path)
  if not path then return false end
  if not path:match("%.cs$") then return false end
  return not path:match("Program%.cs$")
end

local function setup_auto_focus(dap)
  dap.listeners.after.event_stopped["neodev_dotnet_focus"] = function(session, body)
    if not body then return end

    vim.defer_fn(function()
      local s = dap.session()
      if not s then return end

      local current = s.current_frame
      if current and is_user_code(current.source and current.source.path) then
        return
      end

      s:request("threads", nil, function(err, resp)
        if err or not resp or not resp.threads then return end

        local threads = resp.threads
        local idx = 0

        local function check_next()
          idx = idx + 1
          if idx > #threads then return end

          if threads[idx].id == s.stopped_thread_id then
            check_next()
            return
          end

          s:request("stackTrace", { threadId = threads[idx].id, levels = 30 }, function(err2, st)
            if err2 or not st then
              check_next()
              return
            end

            for _, frame in ipairs(st.stackFrames or {}) do
              if is_user_code(frame.source and frame.source.path) then
                vim.schedule(function()
                  s.stopped_thread_id = threads[idx].id
                  s:_frame_set(frame)
                end)
                return
              end
            end

            check_next()
          end)
        end

        check_next()
      end)
    end, 200)
  end
end

local function setup_configurations(dap)
  dap.configurations.cs = {
    {
      type = "coreclr",
      name = "Launch .NET Core",
      request = "launch",
      program = project.find_dll,
      cwd = get_cwd,
      stopAtEntry = false,
      console = "integratedTerminal",
      justMyCode = false,
      env = launch_settings.get_launch_env,
    },
    {
      type = "coreclr",
      name = "Attach to Process",
      request = "attach",
      justMyCode = false,
      processId = function() return require("dap.utils").pick_process() end,
    },
    {
      type = "coreclr",
      name = "Launch Web API",
      request = "launch",
      program = project.find_dll,
      cwd = get_cwd,
      stopAtEntry = false,
      console = "integratedTerminal",
      justMyCode = false,
      env = launch_settings.get_launch_env,
    },
  }
end

function M.setup()
  if setup_done then return end

  local cfg = config.get().debug
  if not cfg.enabled then return end

  local dap_ok, dap = pcall(require, "dap")
  if not dap_ok then return end

  setup_done = true

  local netcoredbg_path = vim.fn.expand(cfg.netcoredbg_path)
  if vim.fn.executable(netcoredbg_path) == 1 then
    dap.adapters.coreclr = {
      type = "executable",
      command = netcoredbg_path,
      args = { "--interpreter=vscode" },
    }
  end

  dap.defaults.coreclr.exception_breakpoints = { "user-unhandled" }

  if cfg.configurations then
    dap.configurations.cs = cfg.configurations
  else
    setup_configurations(dap)
  end

  if cfg.auto_setup_dapui then
    setup_dapui(dap)
  end

  if cfg.virtual_text then
    setup_virtual_text()
  end

  setup_auto_focus(dap)

  pcall(function() require("telescope").load_extension("dap") end)

  setup_signs_and_highlights()
end

function M.set_keymaps()
  if keymaps_done then return end

  local cfg = config.get().debug
  if not cfg.enabled then return end

  local dap_ok, dap = pcall(require, "dap")
  if not dap_ok then return end

  keymaps_done = true

  local km = cfg.keymaps

  vim.keymap.set("n", km.continue, dap.continue, { desc = "Debug: Continue" })
  vim.keymap.set("n", km.step_over, dap.step_over, { desc = "Debug: Step Over" })
  vim.keymap.set("n", km.step_into, dap.step_into, { desc = "Debug: Step Into" })
  vim.keymap.set("n", km.step_out, dap.step_out, { desc = "Debug: Step Out" })
  vim.keymap.set("n", km.terminate, dap.terminate, { desc = "Debug: Stop" })
  vim.keymap.set("n", km.toggle_breakpoint, dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
  vim.keymap.set("n", km.conditional_breakpoint, function()
    dap.set_breakpoint(vim.fn.input("Condition: "))
  end, { desc = "Conditional Breakpoint" })
  vim.keymap.set("n", km.repl, dap.repl.open, { desc = "Debug REPL" })
  vim.keymap.set("n", km.run_last, dap.run_last, { desc = "Run Last" })
  vim.keymap.set("n", km.pause, dap.pause, { desc = "Debug: Pause" })
  vim.keymap.set("n", km.info, M.show_info, { desc = "Debug: Info" })

  local dapui_ok, dapui = pcall(require, "dapui")
  if dapui_ok then
    vim.keymap.set("n", km.toggle_ui, dapui.toggle, { desc = "Toggle Debug UI" })
  end

  local has_telescope = pcall(require, "telescope")
  if has_telescope then
    vim.keymap.set("n", km.list_breakpoints, function()
      require("telescope").extensions.dap.list_breakpoints()
    end, { desc = "Debug: List Breakpoints" })
  end
end

return M
