# Magpie.nvim · v0.1

A lightweight, dependency-free translation plugin for Neovim. Translate the
word under your cursor, a Visual selection, or text you provide, then view the
source text, pronunciation, and translation in a native floating window.

> **README authorship:** This README was written by GitHub Copilot.

![Neovim](https://img.shields.io/badge/Neovim-%3E%3D0.10-57A143?logo=neovim&logoColor=white)
![Version](https://img.shields.io/badge/version-0.1-blue)

## Features

- Providers: ChatGPT, Copilot, Gemini, DeepSeek, and Youdao.
- Bundled top-2000 English word list (IPA + Chinese glosses), available offline.
- Lookup order: in-memory cache → disk cache → local dictionary → network.
- Translate the word under the cursor, a Visual selection, or a word under the
  mouse pointer.
- Native non-focusable floating window, positioned next to the cursor or mouse.
- Dictionary IPA lookup runs in parallel with the translation request.
- In-flight requests are deduplicated; stale requests are cancelled.
- Persistent disk cache; network requests do not block the editor.
- `:checkhealth magpie` diagnostics.

## Requirements

- Neovim 0.10 or newer.
- `curl` available on `$PATH` for network translation and pronunciation.
- Internet access and credentials for the selected provider.

## Installation

### lazy.nvim

```lua
{
  "c0ptr/magpie.nvim",
  main = "magpie",
  event = "VeryLazy",
  opts = {},
}
```

`opts = {}` calls `require("magpie").setup({})` automatically. The default
`<leader>tw` mapping is installed in Normal and Visual mode. To define the
mapping yourself, set the built-in mappings to `false` and add your preferred
`keys` entries in lazy.nvim.

## Usage

| Action | Result |
| --- | --- |
| `<leader>tw` in Normal mode | Translate the word under the cursor |
| `<leader>tw` in Visual mode | Translate the selection |
| Hover over a word | Translate after a short delay (enabled by default) |
| Drag to make a Visual selection | Translate on mouse release (enabled by default) |
| `:Magpie [text]` | Translate the given text, or the current selection/word when omitted |
| `:MagpieClose` | Close the result window |

Mouse interactions require `set mouse=a` in terminal Neovim. Hover uses
`vim.on_key` and enables `mousemoveevent` while configured; it does not replace
existing mouse-move mappings.

## Configuration

All options are optional. The following shows the defaults:

```lua
require("magpie").setup({
  source_lang = "auto",
  target_lang = "zh-CN",
  provider = "chatgpt",

  keymaps = {
    normal = "<leader>tw", -- set false to disable
    visual = "<leader>tw", -- set false to disable
  },
  hover = { enabled = true, delay_ms = 550 },
  mouse_selection = { enabled = true },
  local_dictionary = { enabled = true },
  cache = {
    persist = true,
    max_entries = 100,
    max_disk_entries = 500,
  },
  ui = {
    border = "rounded",
    max_width = 72,
    min_width = 30,
    winblend = 0,
  },
})
```

Persistent cache data is stored under `stdpath("data")/magpie/`. Disable
automatic mouse actions with `hover = { enabled = false }` and/or
`mouse_selection = { enabled = false }`.

## Providers and credentials

Keep credentials out of config files by using environment variables. Magpie
reads the relevant variables automatically; equivalent Lua options are shown
below.

### ChatGPT

Set `OPENAI_API_KEY` (or `CHATGPT_API_KEY`).

```lua
require("magpie").setup({
  provider = "chatgpt",
  chatgpt = {
    api_key = vim.env.OPENAI_API_KEY,
    -- model = "gpt-4o-mini",
  },
})
```

### Copilot

Needs a GitHub token with Copilot access (an OAuth token or a fine-grained PAT
with the Copilot Chat permission). Set `GITHUB_TOKEN` or `COPILOT_API_KEY`.

```lua
require("magpie").setup({
  provider = "copilot",
  copilot = {
    api_key = vim.env.GITHUB_TOKEN,
    -- model = "gpt-4o",
  },
})
```

### Gemini

Set `GEMINI_API_KEY`.

```lua
require("magpie").setup({
  provider = "gemini",
  gemini = {
    api_key = vim.env.GEMINI_API_KEY,
    -- model = "gemini-2.5-flash",
  },
})
```

### DeepSeek

Set `DEEPSEEK_API_KEY`. DeepSeek translates through its chat-completions API,
so responses may take longer than other providers.

```lua
require("magpie").setup({
  provider = "deepseek",
  deepseek = {
    api_key = vim.env.DEEPSEEK_API_KEY,
    -- model = "deepseek-flash",
    extra_body = { thinking = { type = "disabled" } },
    -- proxy = "http://127.0.0.1:7890",
  },
})
```

### Youdao

Create credentials through the [Youdao AI Open Platform](https://ai.youdao.com/)
and set `YOUDAO_APP_KEY` and `YOUDAO_APP_SECRET`.

```lua
require("magpie").setup({
  provider = "youdao",
  youdao = {
    app_key = vim.env.YOUDAO_APP_KEY,
    app_secret = vim.env.YOUDAO_APP_SECRET,
  },
})
```

## Offline dictionary and pronunciation

With the default `target_lang = "zh-CN"`, Magpie checks its bundled list of
about 2,000 common English words before making a network request. The word list
is sourced from [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords)
(MIT). In-memory cache, disk cache, and the local dictionary are checked before
the selected provider.

The bundled dictionary works offline for covered words. Disable it with
`local_dictionary = { enabled = false }`. IPA is looked up separately using
the free Dictionary API for single English words; it may display as `—` when
unavailable, and sentences do not have IPA.

## Lua API

```lua
local magpie = require("magpie")

magpie.translate("A clear mind", { target_lang = "zh-CN" })
magpie.translate_cursor()
magpie.translate_visual()
magpie.translate_from_command("hello")
magpie.close()
magpie.last_result -- { text, phonetic, translation } of the last result
```

## Health check and tests

Run `:checkhealth magpie` to check the Neovim version, `curl`, bundled
dictionary, and provider credentials. Run the network-free test suite with:

```sh
nvim --headless --clean -i NONE -u tests/init.lua
```

CI runs the tests on Neovim 0.10–nightly. Format with
[stylua](https://github.com/JohnnyMorganz/StyLua) (config included).

## License

MIT
