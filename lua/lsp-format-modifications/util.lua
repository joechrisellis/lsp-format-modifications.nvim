
local M = {}

M.notify = function(msg, level, opts)
  if vim.g.lsp_format_modifications_silence then
    return
  end

  vim.notify("lsp-format-modifications.nvim: " .. msg, level, opts)
end

return M
