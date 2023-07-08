
local M = {}

local util = require"lsp-format-modifications.util"
local vcs = require"lsp-format-modifications.vcs"

M.default_diff_opts = {
  result_type = "indices",
  algorithm = "patience",
  ctxlen = 0,
  interhunkctxlen = 0,
  indent_heuristic = true,
  ignore_cr_at_eol = true,
}

local base_config = {
  -- the callback used to compute a diff between the comparee and the buffer
  -- content
  diff_callback = function(comparee_content, buf_content)
    return vim.diff(
      comparee_content,
      buf_content,
      M.default_diff_opts
    )
  end,

  -- the callback used to actually format the hunks
  format_callback = vim.lsp.buf.format, -- NOTE: requires 0.8

  -- if true, set up a BufWritePre autocmd to format on save
  format_on_save = false,

  -- the vcs being used
  vcs = "git",

  -- EXPERIMENTAL: when true, do not attempt formatting on the outermost empty
  -- lines in diff hunks, and do not touch hunks consisting of entirely empty lines
  experimental_empty_line_handling = false
}

local function prechecks(lsp_client, bufnr, config)
  if not lsp_client.server_capabilities.documentRangeFormattingProvider then -- unsupported server
    return "client " .. lsp_client.name .. " does not have a document range formatting provider"
  end

  if vcs[config.vcs] == nil then -- unsupported VCS
    return "VCS " .. config.vcs .. " isn't supported"
  end

  if config.diff_options ~= nil then -- old option, report deprecated
    return "diff_options is deprecated, use diff_callback instead"
  end

  return nil
end


M.format_modifications = function(lsp_client, bufnr, config)
  local bufname = vim.fn.bufname(bufnr)

  local vcs_client = vcs[config.vcs]:new()

  local err = vcs_client:init(bufname)
  if err ~= nil then
    util.notify(
      err .. ", doing nothing",
      vim.log.levels.WARN
    )
    return
  end

  local file_info = vcs_client:file_info(bufname)
  if not(file_info.is_tracked) then
    -- easiest case: the file is new, so skip the whole dance and format
    -- everything
    config.format_callback{
      id = lsp_client.id,
      bufnr = bufnr
    }
    return
  end

  if file_info.has_conflicts then
    -- the file is marked as conflicted, so it probably has conflict markers.
    -- don't do anything to avoid screwing things up.
    return
    -- TODO: we should probably calculate the diff between the file on-disk and
    -- the common ancestor here
  end

  local comparee_lines, err = vcs_client:get_comparee_lines(bufname)
  if err ~= nil then
    util.notify(
      "failed to get comparee, " .. err .. " -- consider raising a GitHub issue",
      vim.log.levels.ERROR
    )
    return
  end

  local comparee_content = table.concat(comparee_lines, "\n")

  local done = false
  while not(done) do
    done = true

    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local buf_content = table.concat(buf_lines, "\n")

    local hunks = config.diff_callback(comparee_content, buf_content)

    for _, hunk in ipairs(hunks) do
      local old_start, old_count, new_start, new_count = unpack(hunk)
      if new_count == 0 then -- lines were removed, nothing to do for this hunk
        goto next_hunk
      end

      local start_line, end_line = new_start, new_start + new_count - 1

      if config.experimental_empty_line_handling then
        while start_line ~= end_line and buf_lines[start_line] == "" do
          start_line = start_line + 1
        end
        while start_line ~= end_line and buf_lines[end_line] == "" do
          end_line = end_line - 1
        end

        if buf_lines[start_line] == "" then
          goto next_hunk
        end
      end

      local start_col, end_col = 0, #buf_lines[end_line] - 1

      config.format_callback{
        id = lsp_client.id,
        bufnr = bufnr,
        range = {
          start = { start_line, start_col },
          ["end"] = { end_line, end_col }
        }
      }

      local new_buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local new_buf_content = table.concat(new_buf_lines, "\n")

      if buf_content ~= new_buf_content then -- the formatter changed something
        -- ... and any remaining hunks may have been invalidated by the
        -- formatter adding/deleting lines, so time to grab the diff again
        done = false
        goto next_diff
      end

      ::next_hunk::
    end

    ::next_diff::
  end
end

M.format_modifications_buffer = function(bufnr)
  local ctx = vim.b[bufnr].lsp_format_modifications_context
  if ctx == nil then
    -- ... attaching to the buffer has either not been performed via attach, or
    -- none of the attached clients are supported
    util.notify(
      "no supported LSP clients attached to buffer, nothing to do",
      vim.log.levels.WARN
    )
    return
  end

  for client_id, config in pairs(ctx) do
    local lsp_client = vim.lsp.get_client_by_id(tonumber(client_id))
    M.format_modifications(lsp_client, bufnr, config)
  end
end

M.format_modifications_current_buffer = function()
  local bufnr = vim.fn.bufnr("%") -- work on the current buffer
  return M.format_modifications_buffer(bufnr)
end

M.attach = function(lsp_client, bufnr, provided_config)
  provided_config = vim.F.if_nil(provided_config, {})
  local config = vim.tbl_extend("force", base_config, provided_config)

  -- pre-flight checks
  local err = prechecks(lsp_client, bufnr, config)
  if err ~= nil then
    util.notify(
      "failed checks: " .. err,
      vim.log.levels.ERROR
    )
    return
  end

  if config.format_on_save then
    local augroup_id = vim.api.nvim_create_augroup(
      "NvimFormatModificationsDocumentFormattingGroup",
      { clear = false }
    )
    vim.api.nvim_clear_autocmds({ group = augroup_id, buffer = bufnr })

    vim.api.nvim_create_autocmd(
      { "BufWritePre" },
      {
        group = augroup_id,
        buffer = bufnr,
        callback = function()
          M.format_modifications_buffer(bufnr)
        end,
      }
    )
  end

  local ctx = vim.b[bufnr].lsp_format_modifications_context
  ctx = vim.F.if_nil(ctx, {})
  ctx[tostring(lsp_client.id)] = config

  vim.b[bufnr].lsp_format_modifications_context = ctx

  vim.api.nvim_create_user_command(
    "FormatModifications",
    M.format_modifications_current_buffer,
    {}
  )
end

return M
