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

## Required dependencies

- [nvim-lua/plenary.nvim][plenary.nvim] is required (hint: you are probably
  already using this).

## Installation

Install with your favourite plugin manager — for example, with [junegunn/vim-plug][vim-plug]:

```vimscript
Plug 'nvim-lua/plenary.nvim'
Plug 'joechrisellis/lsp-format-modifications.nvim'
```

## Configuration

In your [neovim/nvim-lspconfig][nvim-lspconfig] `on_attach` function:

```lua
local on_attach = function(client, bufnr)
  -- your usual configuration — options, keymaps, etc
  -- ...

  local lsp_format_modifications = require"lsp-format-modifications"
  lsp_format_modifications.setup()
  lsp_format_modifications.attach(client, bufnr, { format_on_save = false })
end
```

[nvim-lspconfig]: https://github.com/neovim/nvim-lspconfig
[plenary.nvim]: https://github.com/nvim-lua/plenary.nvim
[vim-plug]: https://github.com/junegunn/vim-plug
[vscode-format-modifications-issue]: https://github.com/Microsoft/vscode/issues/44075
