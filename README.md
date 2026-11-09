# Magpie

A dependency-free Neovim translation plugin for English words and sentences. It
shows the source text, IPA pronunciation, and translation in a native floating
window.

![Neovim](https://img.shields.io/badge/Neovim-%3E%3D0.10-57A143?logo=neovim&logoColor=white)

## Features

- Translate the word under the cursor or under the mouse pointer.
- Translate Visual selections, including selections made by dragging the mouse.
- Native non-focusable floating window, positioned next to the cursor or mouse.
- Displays **source text**, **IPA**, and **translation**.
- Google Translate adapter works out of the box; Azure Translator (Bing), DeepSeek,
  and Youdao are also available.
- Bundled top-2000 English word list: common words translate instantly, even offline.
- Uses current Neovim APIs: `vim.system`, `vim.json`, `vim.on_key`,
  `nvim_open_win`, and `getregion`.
- Keeps a small in-memory cache and never blocks the editor while requesting a
  translation.

## Requirements

- Neovim 0.10 or newer (tested on 0.12).
- `curl` available on `$PATH`.
- Internet access (only for text outside the bundled dictionary and cache).

The default Google provider uses Google's public web-translation endpoint. It
does not require a key, but it is not a Google Cloud SLA-backed API, can change,
and may temporarily rate-limit automated traffic. Set `google.api_key` to use
the official Google Cloud Translation Basic API instead, or use the key-backed
`bing` provider below.

## lazy.nvim

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

`opts = {}` calls `require("magpie").setup({})` automatically. If you
prefer the plugin's built-in mappings, omit `keys`; `<leader>tw` is installed in
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
  provider = "google", -- "google", "bing", "deepseek" or "youdao"

  keymaps = {
    normal = "<leader>tw",
    visual = "<leader>tw",
  },

  hover = {
    enabled = true,
    delay_ms = 550,
  },

  cache = {
    persist = true, -- keep translations across sessions
    max_disk_entries = 500,
  },
  local_dictionary = { enabled = true },

  -- A Visual selection made by mouse drag is translated automatically.
  mouse_selection = { enabled = true },

  ui = {
    border = "rounded",
    max_width = 72,
    winblend = 0,
  },
})
```

### Azure Translator (Bing)

Microsoft's Translator service is the supported Bing translation API. Create an
Azure Translator resource, then configure it with either environment variables
or Lua options:

```lua
require("magpie").setup({
  provider = "bing",
  bing = {
    api_key = vim.env.AZURE_TRANSLATOR_KEY,
    region = vim.env.AZURE_TRANSLATOR_REGION, -- required for multi-service resources
    -- endpoint = "https://api.cognitive.microsofttranslator.com",
  },
})
```

The key is sent only to the configured Azure endpoint and is never written to a
buffer, log, or cache.

### Google Cloud Translation

When a Google Cloud Translation Basic API key is present, the Google adapter
automatically switches from the public endpoint to Google's official v2 API:

```lua
require("magpie").setup({
  provider = "google",
  google = {
    api_key = vim.env.GOOGLE_TRANSLATE_API_KEY,
  },
})
```

This uses `https://translation.googleapis.com/language/translate/v2`; enable
Cloud Translation Basic in the Google Cloud project that owns the key.

### DeepSeek

DeepSeek is an LLM-backed provider that often renders whole sentences more
naturally. It needs an API key:

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

Youdao requires free API credentials from
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

### Local dictionary (offline)

Magpie bundles the ~2000 most common English words (IPA + Chinese glosses) and
checks them before any network request. Word list from
[hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords) (MIT).

Lookup priority: in-memory cache → disk cache → local dictionary → network.
With the default `target_lang = "zh-CN"`, covered words work fully offline;
anything outside the bundle or cache still needs the network. Disable with
`local_dictionary = { enabled = false }`.

### Disable automatic mouse actions

```lua
require("magpie").setup({
  hover = { enabled = false },
  mouse_selection = { enabled = false },
})
```

## Public API

```lua
local translate = require("magpie")

translate.translate("A clear mind", { target_lang = "zh-CN" })
translate.translate_cursor()
translate.translate_visual()
translate.close()
translate.last_result -- 最近一次结果 { text, phonetic, translation }
```

## Notes on IPA

Translation services do not reliably expose IPA. For a single English word,
the plugin looks up IPA using the free Dictionary API after translation. If it
is unavailable, or the selected text is a sentence, the IPA field intentionally
shows `—`; translation still succeeds.

## Development

Run the lightweight, network-free test suite with:

```sh
nvim --headless --clean -u tests/init.lua
```

Check the runtime with `:checkhealth magpie`.

## License

MIT
