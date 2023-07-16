# lsp-format-modifications.nvim

Use LSP to format only modified text in Neovim (like [VSCode's format
modifications feature][vscode-format-modifications-issue]).

# What problem does this solve?

Many projects suggest contributors use an autoformatter to keep code style
consistent.

However, in larger projects with legacy code, there can be plenty of places
where the style deviates from the autoformatter's preference.

In that case, you don't want to format entire files — you'll be left with very
noisy diffs!

You also don't want to comb through all of the changes you've made, manually
applying the autoformatter before you commit. We are too lazy for that!

One reasonable solution is to run the autoformatter over the changed lines as
defined by the revision control system. [VSCode can do
this][vscode-format-modifications-issue] — and this is something that I didn't
find an analog for in Neovim. Hence, this plugin!

# Getting started

## Requirements

- **Neovim ≥0.8 is required**. Neovim 0.8 has a more flexible API for LSP
  formatting, which this plugin leverages.
- Any LSP server that you want to use with this plugin must support the
  [`DocumentRangeFormattingProvider` server
  capability][document-range-formatting-provider-capability] —
  `lsp-format-modifications.nvim` will warn if an unsupported LSP server is
  used.
- [nvim-lua/plenary.nvim][plenary.nvim] is required (hint: you are probably
  already using this).

## Installation

Install with your favourite plugin manager — for example, with [junegunn/vim-plug][vim-plug]:

```vimscript
Plug 'nvim-lua/plenary.nvim'
Plug 'joechrisellis/lsp-format-modifications.nvim'
```

## Configuration and usage

In terms of basic usage:

```lua
require"lsp-format-modifications".format_modifications(<lsp-client>, <bufnr>, <config>)
```

... will format the modifications in the buffer with ID `<bufnr>` using LSP
client `<lsp-client>`, according to the options specified in `<config>`.

For convenience, you may choose to create a user command that does this for
you. For example, in your LSP `on_attach` function:

```lua
local on_attach = function(client, bufnr)
  -- your usual configuration — options, keymaps, etc
  -- ...

  vim.api.nvim_buf_create_user_command(
    bufnr,
    "FormatModifications",
    function()
      local lsp_format_modifications = require"lsp-format-modifications"
      lsp_format_modifications.format_modifications(client, bufnr)
    end,
    {}
  )
end
```

If you'd prefer to instead format-on-save, try:

```lua
local on_attach = function(client, bufnr)
  -- your usual configuration — options, keymaps, etc
  -- ...

  local augroup_id = vim.api.nvim_create_augroup(
    "FormatModificationsDocumentFormattingGroup",
    { clear = false }
  )
  vim.api.nvim_clear_autocmds({ group = augroup_id, buffer = bufnr })

  vim.api.nvim_create_autocmd(
    { "BufWritePre" },
    {
      group = augroup_id,
      buffer = bufnr,
      callback = function()
        local lsp_format_modifications = require"lsp-format-modifications"
        lsp_format_modifications.format_modifications(client, bufnr)
      end,
    }
  )
end
```

### Options

A complete configuration table is below:

```lua
local config = {
  -- The callback that is invoked to compute a diff so that we know what to
  -- format. This defaults to vim.diff with some sensible defaults.
  diff_callback = function(compareee_content, buf_content)
    return vim.diff(compareee_content, buf_content, {...})
  end,

  -- The callback that is invoked to actually do the formatting on the changed
  -- hunks. Defaults to vim.lsp.buf.format (requires Neovim ≥ 0.8).
  format_callback = vim.lsp.buf.format,

  -- The VCS to use. Possible options are: "git", "hg". Defaults to "git".
  vcs = "git",

  -- EXPERIMENTAL: when true, do not attempt to format the outermost empty
  -- lines in diff hunks, and do not touch hunks consisting of entirely empty
  -- lines. For some LSP servers, this can result in more intuitive behaviour.
  experimental_empty_line_handling = false
}
```

## Caveats and issues

**Please raise an issue if something is wrong — but read this section first.**

In my experience with LSP, I've found that most language servers have imperfect
support for range formatting. A lot of the time, selecting and formatting a
range results in the formatter also capturing some of the surrounding text. I'm
not totally sure why this is, but the upshot is that _for some language
servers, `:FormatModifications` might capture more than just the lines in the
hunk_. This is usually not a big deal.

A good way to test whether `lsp-format-modifications.nvim` is playing up, or
whether it's just your language server, is to visually select the changed range
and hit `gq` (invoking `formatexpr`). If you see the same problem, it's more
likely to be problem with your language server.

## Supported VCSs

| VCS                        | Works with `lsp-format-modifications.nvim`? | More info                                                                                       |
| -------------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| [Git][git-vcs]             | ✅                                          |                                                                                                 |
| [Mercurial][mercurial-vcs] | ✅                                          | Implemented in [this PR](https://github.com/joechrisellis/lsp-format-modifications.nvim/pull/3) |

Adding support for a new VCS is fairly simple (see [this
PR](https://github.com/joechrisellis/lsp-format-modifications.nvim/pull/3) for
an example) — pull requests are very welcome.

## Tested language servers

| Language server      | Works with `lsp-format-modifications.nvim`? | More info                                                                                                                                                                                       |
| -------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `clangd`             | ✅                                          |                                                                                                                                                                                                 |
| `tsserver`           | ✅                                          |                                                                                                                                                                                                 |
| `null_ls`            | ✅                                          | See [this issue](https://github.com/joechrisellis/lsp-format-modifications.nvim/issues/1#issuecomment-1275302811) for how to get set up — only sources that support range formatting will work. |
| `lua-language-server`| ✅                                          | For best results, set the `experimental_empty_line_handling` option in config.                                                                                                                  |

[git-vcs]: https://git-scm.com
[mercurial-vcs]: https://www.mercurial-scm.org
[nvim-lspconfig]: https://github.com/neovim/nvim-lspconfig
[plenary.nvim]: https://github.com/nvim-lua/plenary.nvim
[vim-plug]: https://github.com/junegunn/vim-plug
[vscode-format-modifications-issue]: https://github.com/Microsoft/vscode/issues/44075
[document-range-formatting-provider-capability]: https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualstudio.languageserver.protocol.servercapabilities.documentrangeformattingprovider?view=visualstudiosdk-2022
