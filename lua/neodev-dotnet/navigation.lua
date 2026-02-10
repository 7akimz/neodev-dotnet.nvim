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

local function looks_like_interface(name)
  return name:match("^I%u") ~= nil
end

local function rg_search(patterns, exclude_args, root)
  local seen = {}
  local items = {}

  for _, pattern in ipairs(patterns) do
    local cmd = vim.list_extend(
      { "rg", "--vimgrep", "--no-heading", "--type", "cs" },
      exclude_args
    )
    table.insert(cmd, pattern)
    table.insert(cmd, root)

    local result = vim.fn.systemlist(cmd)
    if vim.v.shell_error == 0 then
      for _, line in ipairs(result) do
        local entry = parse_rg_line(line)
        if entry then
          local key = entry.filename .. ":" .. entry.lnum
          if not seen[key] then
            seen[key] = true
            table.insert(items, entry)
          end
        end
      end
    end
  end

  return items
end

local function is_mediatr_request_or_notification(bufnr, word)
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "roslyn" })
  if #clients == 0 then
    return false
  end

  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)

  local result = vim.lsp.buf_request_sync(bufnr, "textDocument/definition", params, 3000)
  if not result then
    return false
  end

  for _, res in pairs(result) do
    if res.result then
      local locations = vim.islist(res.result) and res.result or { res.result }
      for _, loc in ipairs(locations) do
        local uri = loc.uri or loc.targetUri
        if uri then
          local def_bufnr = vim.uri_to_bufnr(uri)
          vim.fn.bufload(def_bufnr)
          local lines = vim.api.nvim_buf_get_lines(def_bufnr, 0, -1, false)
          local content = table.concat(lines, "\n")

          local has_class = content:match("class%s+" .. word) or content:match("record%s+" .. word)
          if has_class then
            if content:match("IRequest") or content:match("INotification") then
              return true
            end
          end
        end
      end
    end
  end

  return false
end

local function find_mediatr_handler(name, exclude_args, root)
  local patterns = {
    "IRequestHandler\\s*<\\s*" .. name .. "\\b",
    "INotificationHandler\\s*<\\s*" .. name .. "\\b",
    "class\\s+" .. name .. "Handler\\b",
  }

  return rg_search(patterns, exclude_args, root)
end

local function find_rg_items(name, opts)
  opts = opts or {}
  local cfg = config.get().navigation
  local root = project.find_project_root()

  local exclude_args = {}
  for _, dir in ipairs(cfg.exclude_dirs) do
    table.insert(exclude_args, "--glob")
    table.insert(exclude_args, "!" .. dir .. "/")
  end

  if opts.mediatr_handler then
    local items = find_mediatr_handler(name, exclude_args, root)
    if #items > 0 then
      return items
    end
  end

  local pattern_groups = {}

  if looks_like_interface(name) then
    table.insert(pattern_groups, {
      "class\\s+\\w+[^{]*:\\s*[^{]*\\b" .. name .. "\\b",
    })
  end

  table.insert(pattern_groups, {
    "Handle\\s*\\(\\s*" .. name .. "\\b",
    "(override|virtual|abstract)[^;{]*\\b" .. name .. "\\b",
  })

  table.insert(pattern_groups, {
    "(class|record|struct)\\s+\\w+[^{]*<[^>]*\\b" .. name .. "\\b",
  })

  for _, patterns in ipairs(pattern_groups) do
    local items = rg_search(patterns, exclude_args, root)
    if #items > 0 then
      return items
    end
  end

  return {}
end

local function show_results(items, name)
  if #items == 0 then
    vim.notify("No implementations found for " .. name, vim.log.levels.INFO)
    return
  end

  if #items == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(items[1].filename))
    vim.api.nvim_win_set_cursor(0, { items[1].lnum, items[1].col - 1 })
    return
  end

  show_in_telescope(items, "Implementations of " .. name)
end

local function grep_implementations(name, opts)
  show_results(find_rg_items(name, opts), name)
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
  local word = vim.fn.expand("<cword>")
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "roslyn" })

  if #clients == 0 then
    grep_implementations(word)
    return
  end

  local is_mediatr = is_mediatr_request_or_notification(bufnr, word)
  if is_mediatr then
    grep_implementations(word, { mediatr_handler = true })
    return
  end

  local params = vim.lsp.util.make_position_params(0, clients[1].offset_encoding)

  vim.lsp.buf_request_all(bufnr, "textDocument/implementation", params, function(results)
    local lsp_results = on_lsp_results(results)

    if #lsp_results == 1 and not looks_like_interface(word) then
      vim.schedule(function()
        local rg_items = find_rg_items(word)
        if #rg_items > 0 then
          show_results(rg_items, word)
        else
          local loc = lsp_results[1]
          local uri = loc.uri or loc.targetUri
          local range = loc.range or loc.targetSelectionRange
          vim.lsp.util.show_document({ uri = uri, range = range }, "utf-8", { focus = true })
        end
      end)
      return
    end

    if #lsp_results > 1 then
      vim.schedule(function()
        vim.fn.setqflist({}, " ", {
          title = "Implementations",
          items = vim.lsp.util.locations_to_items(lsp_results, "utf-8"),
        })
        vim.cmd("copen")
      end)
      return
    end

    vim.schedule(function()
      grep_implementations(word, { mediatr_handler = true })
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
