# Magpie.nvim · v0.1

A dependency-free Neovim translation plugin for English words and sentences. It
shows the source text, IPA pronunciation, and translation in a native floating
window.

![Neovim](https://img.shields.io/badge/Neovim-%3E%3D0.10-57A143?logo=neovim&logoColor=white)
![Version](https://img.shields.io/badge/version-0.1-blue)

## Features

- Providers: ChatGPT, Copilot, Gemini, DeepSeek, and Youdao (all key-backed).
- Bundled top-2000 English word list (IPA + Chinese glosses): common words
  translate instantly, even offline.
- Lookup order: in-memory cache → disk cache → local dictionary → network.
- Translate the word under the cursor, a Visual selection, or the word under
  the mouse pointer (hover).
- Native non-focusable floating window, positioned next to the cursor or mouse.
- Dictionary IPA lookup runs in parallel with the translation request.
- In-flight requests are deduplicated; stale requests are cancelled.
- Persistent disk cache (survives restarts) with normalized cache keys.
- Never blocks the editor; all requests are asynchronous.

## Requirements

- Neovim 0.10 or newer (tested on 0.12).
- `curl` available on `$PATH`.
- An API key for the provider you use (see Providers below).

## Installation (lazy.nvim)

```lua
{
  "your-name/magpie.nvim",
  main = "magpie",
  event = "VeryLazy",
  opts = {
    target_lang = "zh-CN", -- the default
  },
  keys = {
    { "<leader>tw", "<cmd>Magpie<cr>", mode = { "n", "x" }, desc = "Translate word or selection" },
  },
}
```

`opts = {}` calls `require("magpie").setup({})` automatically. If you prefer
the plugin's built-in mappings, omit `keys`; `<leader>tw` is installed in
Normal and Visual mode by default.

## Usage

| Action | Default behavior |
| --- | --- |
| `<leader>tw` in Normal mode | Translate the word under the cursor |
| `<leader>tw` in Visual mode | Translate the selected word or sentence |
| Hover a word with the mouse | Translate after a short delay |
| Drag to make a Visual selection with the mouse | Translate on mouse release |
| `:Magpie [text]` | Translate an explicit text, or the current word/selection |
| `:MagpieClose` | Close the floating result window |

Mouse hover needs `set mouse=a` in terminal Neovim. The plugin enables
`mousemoveevent` only while hover translation is enabled; it receives events
through `vim.on_key`, so it does not replace your `<MouseMove>` mappings.

## Configuration

```lua
require("magpie").setup({
  target_lang = "zh-CN",
  source_lang = "auto",
  provider = "chatgpt", -- "chatgpt", "copilot", "gemini", "deepseek" or "youdao"

  keymaps = {
    normal = "<leader>tw",
    visual = "<leader>tw",
  },

  hover = {
    enabled = true,
    delay_ms = 550,
  },

  -- A Visual selection made by mouse drag is translated automatically.
  mouse_selection = { enabled = true },

  ui = {
    border = "rounded",
    max_width = 72,
    winblend = 0,
  },

  cache = {
    persist = true,          -- keep translations across sessions
    max_disk_entries = 500,  -- stored under stdpath("data")/magpie/
  },
  local_dictionary = { enabled = true },
})
```

## Providers

Every provider needs its own API key, set with an environment variable or in
the provider options. Keys are only sent to the configured endpoint and are
never written to a buffer, log, or cache.

### ChatGPT

```lua
require("magpie").setup({
  provider = "chatgpt",
  chatgpt = {
    api_key = vim.env.OPENAI_API_KEY,
    -- model = "gpt-4o-mini", -- the default
  },
})
```

### Copilot

Needs a GitHub token with Copilot access (an OAuth token or a fine-grained PAT
with the Copilot Chat permission):

```lua
require("magpie").setup({
  provider = "copilot",
  copilot = {
    api_key = vim.env.GITHUB_TOKEN, -- or $COPILOT_API_KEY
    -- model = "gpt-4o", -- the default
  },
})
```

### Gemini

```lua
require("magpie").setup({
  provider = "gemini",
  gemini = {
    api_key = vim.env.GEMINI_API_KEY,
    -- model = "gemini-2.5-flash", -- the default
  },
})
```

### DeepSeek

```lua
require("magpie").setup({
  provider = "deepseek",
  deepseek = {
    api_key = vim.env.DEEPSEEK_API_KEY,
    -- model = "deepseek-flash", -- the default
    -- Disable thinking mode for faster answers:
    extra_body = { thinking = { type = "disabled" } },
    -- proxy = "http://127.0.0.1:7890",
  },
})
```

Generated answers take a moment; the window shows a loading state until the
response arrives.

### Youdao

Requires free API credentials from
[AI 开放平台](https://ai.youdao.com/):

```lua
require("magpie").setup({
  provider = "youdao",
  youdao = {
    app_key = vim.env.YOUDAO_APP_KEY,
    app_secret = vim.env.YOUDAO_APP_SECRET,
  },
})
```

## Local dictionary (offline)

Magpie bundles the ~2000 most common English words (IPA + Chinese glosses) and
checks them before any network request. Word list from
[hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords) (MIT).

With the default `target_lang = "zh-CN"`, covered words — and anything already
in the disk cache — work fully offline. Disable with
`local_dictionary = { enabled = false }`.

## Notes on IPA

Translation services do not reliably expose IPA. For a single English word the
plugin looks up IPA from the free Dictionary API in parallel with translation;
if it is unavailable, or the text is a sentence, the IPA field intentionally
shows `—`.

## Public API

```lua
local translate = require("magpie")

translate.translate("A clear mind", { target_lang = "zh-CN" })
translate.translate_cursor()
translate.translate_visual()
translate.translate_from_command("hello")
translate.close()
translate.last_result -- { text, phonetic, translation } of the last result
```

## Development

Run the lightweight, network-free test suite with:

```sh
nvim --headless --clean -i NONE -u tests/init.lua
```

Check the runtime with `:checkhealth magpie`. CI runs the tests on Neovim
0.10–nightly. Format with [stylua](https://github.com/JohnnyMorganz/StyLua)
(config included).

## License

MIT
