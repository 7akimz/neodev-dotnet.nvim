# neodev-dotnet.nvim

.NET Core development toolkit for Neovim — build, test, debug, and navigate C# projects.

## Features

- **Project discovery** — finds `*.csproj` and `*.sln` files from the current buffer
- **Build/Run/Test/Watch/Clean/Restore** — via terminal splits
- **Code generation** — `dotnet new class`, `dotnet new interface`
- **Implementation fallback** — `gi` tries LSP first, then ripgrep across the solution
- **DAP debugging** — netcoredbg adapter with 4 launch configurations, DAP UI, virtual text
- **Telescope pickers** — project files, project selector (quickfix fallback when Telescope absent)
- **`:DotNet` command** — unified command with tab completion

Complements [roslyn.nvim](https://github.com/seblyng/roslyn.nvim) — does not manage the Roslyn LSP server.

## Requirements

- Neovim >= 0.11
- .NET SDK

### Optional

- [roslyn.nvim](https://github.com/seblyng/roslyn.nvim) — C# LSP
- [ripgrep](https://github.com/BurntSushi/ripgrep) — implementation fallback search
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) + [nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) + [nvim-dap-virtual-text](https://github.com/theHamsta/nvim-dap-virtual-text) — debugging
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) — enhanced pickers
- [netcoredbg](https://github.com/Samsung/netcoredbg) — debug adapter

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "7akimz/neodev-dotnet.nvim",
  ft = { "cs" },
  dependencies = {
    "mfussenegger/nvim-dap",           -- optional
    "rcarriga/nvim-dap-ui",            -- optional
    "theHamsta/nvim-dap-virtual-text", -- optional
    "nvim-telescope/telescope.nvim",   -- optional
  },
  opts = {},
}
```

## Configuration

All options with defaults:

```lua
require("neodev-dotnet").setup({
  keymaps = {
    enabled = true,
    prefix = "<leader>dn",
    build = "b", run = "r", test = "t", watch = "w",
    clean = "c", restore = "p", find_files = "f",
    open_project = "o", list_projects = "l",
    new_class = "n", new_interface = "i",
  },
  terminal = {
    direction = "horizontal",  -- "horizontal" | "vertical"
    size = 15,
    start_insert = true,
  },
  debug = {
    enabled = true,
    netcoredbg_path = vim.env.NETCOREDBG_PATH or "~/.local/bin/netcoredbg",
    auto_setup_dapui = true,
    virtual_text = true,
    keymaps = {
      continue = "<F5>", step_over = "<F10>", step_into = "<F11>",
      step_out = "<F12>", terminate = "<S-F5>",
      toggle_breakpoint = "<leader>b", conditional_breakpoint = "<leader>B",
      repl = "<leader>dr", run_last = "<leader>dl", toggle_ui = "<leader>dt",
      info = "<leader>di", list_breakpoints = "<leader>dB",
    },
    configurations = nil, -- nil = use defaults, or provide custom DAP configs
  },
  navigation = {
    implementation_fallback = true,
    fallback_keymap = "gi",
    exclude_dirs = { "bin", "obj", ".git", "node_modules", "TestResults" },
  },
  codegen = { enabled = true },
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:DotNet build` | Build the project |
| `:DotNet run` | Run the project |
| `:DotNet test` | Run tests |
| `:DotNet watch` | Watch run (hot reload) |
| `:DotNet clean` | Clean build artifacts |
| `:DotNet restore` | Restore NuGet packages |
| `:DotNet new-class` | Create a new class |
| `:DotNet new-interface` | Create a new interface |
| `:DotNet find-files` | Find project files |
| `:DotNet open-project` | Open .sln or .csproj |
| `:DotNet list-projects` | Pick a project and run it |
| `:DotNet info` | Show debug info |

## Keymaps

All keymaps use the configured prefix (default `<leader>dn`), set in C# buffers only.

| Key | Action |
|-----|--------|
| `{prefix}b` | Build |
| `{prefix}r` | Run |
| `{prefix}t` | Test |
| `{prefix}w` | Watch run |
| `{prefix}c` | Clean |
| `{prefix}p` | Restore packages |
| `{prefix}f` | Find project files |
| `{prefix}o` | Open project file |
| `{prefix}l` | List and run projects |
| `{prefix}n` | New class |
| `{prefix}i` | New interface |

### Debug Keymaps

| Key | Action |
|-----|--------|
| `<F5>` | Continue / start debugging |
| `<S-F5>` | Stop debugging |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<F12>` | Step out |
| `<leader>b` | Toggle breakpoint |
| `<leader>B` | Conditional breakpoint |
| `<leader>dr` | Open debug REPL |
| `<leader>dl` | Run last debug session |
| `<leader>dt` | Toggle debug UI |
| `<leader>di` | Show debug info |
| `<leader>dB` | List breakpoints (Telescope) |

## Implementation Fallback

The core novel feature. When `gi` is pressed on a Roslyn-attached buffer:

1. Sends `textDocument/implementation` to the LSP
2. If results exist, navigates normally (single jump or quickfix list)
3. If empty, runs ripgrep across the solution for classes implementing the interface
4. Results shown in Telescope (or quickfix if Telescope absent)

Pattern: `class\s+\w+[^{]*:\s*[^{]*\b{InterfaceName}\b` across all `*.cs` files.

## Health Check

```
:checkhealth neodev-dotnet
```

## Acknowledgements

Built with [Claude Code](https://claude.ai/claude-code).

## License

MIT
