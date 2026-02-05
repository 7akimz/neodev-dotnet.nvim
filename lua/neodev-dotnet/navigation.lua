local config = require("neodev-dotnet.config")
local project = require("neodev-dotnet.project")

local M = {}

local function parse_rg_line(line)
  local file, lnum, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
  if file then
    return {
      filename = file,
      lnum = tonumber(lnum),
      col = tonumber(col),
      text = vim.trim(text),
    }
  end
  return nil
end

local function show_in_telescope(items, title)
  local has_telescope, pickers = pcall(require, "telescope.pickers")
  if not has_telescope then
    vim.fn.setqflist(items, "r")
    vim.cmd("copen")
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local make_entry = require("telescope.make_entry")

  pickers.new({}, {
    prompt_title = title,
    finder = finders.new_table({
      results = items,
      entry_maker = make_entry.gen_from_quickfix(),
    }),
    previewer = conf.qflist_previewer({}),
    sorter = conf.generic_sorter({}),
  }):find()
end

local function grep_implementations(interface_name)
  local cfg = config.get().navigation
  local root = project.find_project_root()

  local exclude_args = {}
  for _, dir in ipairs(cfg.exclude_dirs) do
    table.insert(exclude_args, "--glob")
    table.insert(exclude_args, "!" .. dir .. "/")
  end

  local pattern = "class\\s+\\w+[^{]*:\\s*[^{]*\\b" .. interface_name .. "\\b"

  local cmd = vim.list_extend(
    { "rg", "--vimgrep", "--no-heading", "--type", "cs" },
    exclude_args
  )
  table.insert(cmd, pattern)
  table.insert(cmd, root)

  local result = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 or #result == 0 then
    vim.notify("No implementations found for " .. interface_name, vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, line in ipairs(result) do
    local entry = parse_rg_line(line)
    if entry then
      table.insert(items, entry)
    end
  end

  if #items == 0 then
    vim.notify("No implementations found for " .. interface_name, vim.log.levels.INFO)
    return
  end

  if #items == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(items[1].filename))
    vim.api.nvim_win_set_cursor(0, { items[1].lnum, items[1].col - 1 })
    return
  end

  show_in_telescope(items, "Implementations of " .. interface_name)
end

local function on_lsp_results(results)
  local all_results = {}
  for _, res in pairs(results) do
    if res.result then
      if vim.islist(res.result) then
        vim.list_extend(all_results, res.result)
      else
        table.insert(all_results, res.result)
      end
    end
  end
  return all_results
end

function M.goto_implementation()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/implementation" })
  if #clients == 0 then
    grep_implementations(vim.fn.expand("<cword>"))
    return
  end

  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)
  local word = vim.fn.expand("<cword>")

  vim.lsp.buf_request_all(bufnr, "textDocument/implementation", params, function(results)
    local lsp_results = on_lsp_results(results)

    if #lsp_results > 0 then
      if #lsp_results == 1 then
        local loc = lsp_results[1]
        local uri = loc.uri or loc.targetUri
        local range = loc.range or loc.targetSelectionRange
        vim.schedule(function()
          vim.lsp.util.show_document({ uri = uri, range = range }, "utf-8", { focus = true })
        end)
      else
        vim.schedule(function()
          vim.fn.setqflist({}, " ", {
            title = "Implementations",
            items = vim.lsp.util.locations_to_items(lsp_results, "utf-8"),
          })
          vim.cmd("copen")
        end)
      end
      return
    end

    vim.schedule(function()
      grep_implementations(word)
    end)
  end)
end

function M.attach(bufnr)
  local cfg = config.get().navigation
  if not cfg.implementation_fallback then
    return
  end

  vim.keymap.set("n", cfg.fallback_keymap, function()
    M.goto_implementation()
  end, { buffer = bufnr, desc = ".NET: Go to implementation (with fallback)" })
end

return M
