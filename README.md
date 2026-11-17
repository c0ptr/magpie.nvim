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

## Getting started

1. Install the plugin (see above).
2. Get an API key for the provider you want to use.
3. Export it as an environment variable (e.g. `export OPENAI_API_KEY=sk-...`),
   or set it directly in your Neovim config (see below).
4. Done. Hover a word, press `<leader>tw`, or run `:Magpie hello world`.
   Words in the bundled dictionary translate even without any key.

## Configuration

Call `require("magpie").setup()` with these options; every key is optional
and falls back to its default. Provider secrets can come from environment
variables instead of the config.

```lua
require("magpie").setup({
  -- Languages
  source_lang = "auto",   -- "auto" or a language code, e.g. "en", "ja"
  target_lang = "zh-CN",  -- language code, e.g. "zh-CN", "en", "ja"

  -- Provider: "chatgpt", "copilot", "gemini", "deepseek" or "youdao"
  provider = "chatgpt",

  -- Keymaps installed by the plugin (set one to false to disable it)
  keymaps = {
    normal = "<leader>tw",  -- Normal mode: word under cursor
    visual = "<leader>tw",  -- Visual mode: selection
  },

  -- Hover: translate the word under the mouse after it stays still
  hover = {
    enabled = true,
    delay_ms = 550,  -- how long the mouse must stay still (ms)
  },

  -- Translate a Visual selection made by dragging the mouse, on release
  mouse_selection = { enabled = true },

  -- Result window
  ui = {
    border = "rounded",  -- "none", "single", "double", "rounded", "solid", "shadow"
    max_width = 72,
    min_width = 30,
    winblend = 0,
    title = " 翻译 ",
  },

  -- Cache: in-memory + optional disk persistence
  cache = {
    max_entries = 100,       -- in-memory entries
    persist = true,          -- save to disk across sessions
    max_disk_entries = 500,  -- disk entries (oldest evicted first)
    dir = nil,               -- disk location; default stdpath("data")/magpie
  },

  -- Bundled top-2000 word dictionary (offline, used for Chinese targets)
  local_dictionary = { enabled = true },

  -- IPA lookup for single English words (free Dictionary API)
  dictionary = {
    enabled = true,
    endpoint = "https://api.dictionaryapi.dev/api/v2/entries/en",
    timeout_ms = 5000,
  },

  -- Provider settings (only the one named by `provider` is used)
  chatgpt = {
    api_key = vim.env.OPENAI_API_KEY,  -- or $OPENAI_API_KEY / $CHATGPT_API_KEY
    model = "gpt-4o-mini",
    temperature = 0.2,
    extra_body = nil,  -- merged into the request body, e.g. { top_p = 1 }
    proxy = nil,       -- e.g. "http://127.0.0.1:7890"
    endpoint = "https://api.openai.com/v1/chat/completions",
    timeout_ms = 30000,
  },

  copilot = {
    api_key = vim.env.GITHUB_TOKEN,  -- or $GITHUB_TOKEN / $COPILOT_API_KEY
    model = "gpt-4o",
    temperature = 0.2,
    extra_body = nil,
    proxy = nil,
    endpoint = "https://api.githubcopilot.com/chat/completions",
    timeout_ms = 30000,
  },

  gemini = {
    api_key = vim.env.GEMINI_API_KEY,  -- or $GEMINI_API_KEY
    model = "gemini-2.5-flash",
    temperature = 0.2,
    proxy = nil,
    endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
    timeout_ms = 30000,
  },

  deepseek = {
    api_key = vim.env.DEEPSEEK_API_KEY,  -- or $DEEPSEEK_API_KEY
    model = "deepseek-flash",
    temperature = 0.2,
    extra_body = nil,  -- e.g. { thinking = { type = "disabled" } } to speed up
    proxy = nil,
    endpoint = "https://api.deepseek.com/chat/completions",
    timeout_ms = 30000,
  },

  youdao = {
    app_key = vim.env.YOUDAO_APP_KEY,       -- or $YOUDAO_APP_KEY
    app_secret = vim.env.YOUDAO_APP_SECRET, -- or $YOUDAO_APP_SECRET
    proxy = nil,
    endpoint = "https://openapi.youdao.com/api",
    timeout_ms = 10000,
  },
})
```

### Examples

Minimal setup (ChatGPT via environment variable, everything else default):

```lua
require("magpie").setup({}) -- uses $OPENAI_API_KEY
```

Copilot, key in the config, hover and mouse features off:

```lua
require("magpie").setup({
  provider = "copilot",
  copilot = { api_key = vim.env.GITHUB_TOKEN, model = "gpt-4o" },
  hover = { enabled = false },
  mouse_selection = { enabled = false },
})
```

Offline only (bundled dictionary + disk cache; no IPA network lookup):

```lua
require("magpie").setup({
  local_dictionary = { enabled = true },
  dictionary = { enabled = false },
})
```

Words outside the dictionary then show an error instead of translating.

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
