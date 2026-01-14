local namespace = vim.api.nvim_create_namespace("md-tags")
local buffer = vim.api.nvim_get_current_buf()

vim.api.nvim_set_hl(0, "MdTag", { link = "Identifier", default = true })
vim.api.nvim_set_hl(0, "MdMention", { link = "Special", default = true })

if vim.b.md_ts_highlighted then
  return
end

local ok_parser, parser = pcall(vim.treesitter.get_parser, buffer)
if not ok_parser or not parser then
  return
end

local paragraph_ok, paragraph_query = pcall(
  vim.treesitter.query.parse,
  "markdown",
  "(paragraph) @paragraph"
)
local skip_ok, skip_query = pcall(
  vim.treesitter.query.parse,
  "markdown_inline",
  [[
    (inline_link) @skip
    (shortcut_link) @skip
    (full_reference_link) @skip
    (collapsed_reference_link) @skip
    (link_text) @skip
    (link_destination) @skip
    (link_title) @skip
    (image) @skip
    (code_span) @skip
  ]]
)

if not paragraph_ok then
  return
end

vim.b.md_ts_highlighted = true

local disallowed_ancestors = {
  heading_content = true,
  atx_heading = true,
  setext_heading = true,
}

local function has_ancestor(node, lookup)
  local parent = node:parent()
  while parent do
    if lookup[parent:type()] then
      return true
    end
    parent = parent:parent()
  end
  return false
end

local function is_allowed(node)
  return not has_ancestor(node, disallowed_ancestors)
end

local function overlaps_range(row, start_col, end_col, range)
  local start_row, start_range_col, end_row, end_range_col = range[1], range[2], range[3], range[4]
  if row < start_row or row > end_row then
    return false
  end
  if start_row == end_row then
    return not (end_col <= start_range_col or start_col >= end_range_col)
  end
  if row == start_row then
    return end_col > start_range_col
  end
  if row == end_row then
    return start_col < end_range_col
  end
  return true
end

local function is_skipped(row, start_col, end_col, ranges)
  for _, range in ipairs(ranges) do
    if overlaps_range(row, start_col, end_col, range) then
      return true
    end
  end
  return false
end

local function highlight_line_matches(line, row, start_col, skip_ranges)
  local index = 1
  while index <= #line do
    local start_index, end_index, tag = line:find("([#@][%w_-]+)", index)
    if not start_index then
      break
    end
    local prev_char = start_index > 1 and line:sub(start_index - 1, start_index - 1) or ""
    if start_index == 1 or not prev_char:match("[%w_]") then
      local group = tag:sub(1, 1) == "#" and "MdTag" or "MdMention"
      local highlight_start = start_col + start_index - 1
      local highlight_end = highlight_start + #tag
      if not is_skipped(row, highlight_start, highlight_end, skip_ranges) then
        vim.api.nvim_buf_set_extmark(buffer, namespace, row, highlight_start, {
          end_row = row,
          end_col = highlight_end,
          hl_group = group,
        })
      end
    end
    index = end_index + 1
  end
end

local function build_skip_ranges(inline_trees)
  local ranges = {}
  if not skip_ok then
    return ranges
  end
  for _, tree in ipairs(inline_trees) do
    local root = tree:root()
    for _, node in skip_query:iter_captures(root, buffer, 0, -1) do
      local start_row, start_col, end_row, end_col = node:range()
      table.insert(ranges, { start_row, start_col, end_row, end_col })
    end
  end
  return ranges
end

local function collect_trees()
  local markdown_tree
  local inline_trees = {}

  parser:for_each_tree(function(tree, lang)
    if lang == "markdown" then
      markdown_tree = tree
    elseif lang == "markdown_inline" then
      table.insert(inline_trees, tree)
    end
  end)

  if not markdown_tree then
    local parsed = parser:parse()
    markdown_tree = parsed and parsed[1] or nil
  end

  return markdown_tree, inline_trees
end

local function highlight_matches()
  vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)

  local ok_parse, _ = pcall(parser.parse, parser)
  if not ok_parse then
    return
  end

  local markdown_tree, inline_trees = collect_trees()
  if not markdown_tree then
    return
  end

  local root = markdown_tree:root()
  local skip_ranges = build_skip_ranges(inline_trees)

  for _, node in paragraph_query:iter_captures(root, buffer, 0, -1) do
    if is_allowed(node) then
      local start_row, start_col = node:range()
      local text = vim.treesitter.get_node_text(node, buffer)
      local lines = vim.split(text, "\n", { plain = true })
      for offset, line in ipairs(lines) do
        local row = start_row + offset - 1
        local col = offset == 1 and start_col or 0
        highlight_line_matches(line, row, col, skip_ranges)
      end
    end
  end
end

local group = vim.api.nvim_create_augroup("MdTagHighlights", { clear = false })
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter" }, {
  group = group,
  buffer = buffer,
  callback = highlight_matches,
})

highlight_matches()

