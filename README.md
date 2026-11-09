# Magpie.nvim

A lightweight, dependency-free translation plugin for Neovim. Translate the word under your cursor, a Visual selection, or text you provide, then view the source text, pronunciation, and translation in a native floating window.

> **README authorship:** This README was written by GitHub Copilot.

![Neovim 0.10+](https://img.shields.io/badge/Neovim-%3E%3D0.10-57A143?logo=neovim&logoColor=white)

## Features

- Translate the word under the cursor, a Visual selection, or arbitrary text.
- Optional mouse-hover and mouse-drag selection translation.
- Non-focusable floating window showing the original text, IPA when available, and translation.
- Four providers: Google Translate, Microsoft Azure Translator (Bing), DeepSeek, and Youdao.
- Bundled English-to-Chinese dictionary for roughly 2,000 common words, available offline.
- In-memory and optional persistent disk cache; network requests do not block the editor.
- `:checkhealth magpie` diagnostics.

## Requirements

- Neovim 0.10 or newer.
- `curl` on `$PATH` for network translation and pronunciation lookups.
- Internet access for uncached text not covered by the bundled dictionary.

The default Google provider uses Google's public web-translation endpoint. It needs no API key, but is not a Google Cloud SLA-backed API and may change or rate-limit requests. Configure a Google Cloud Translation Basic API key to use Google's official v2 endpoint instead.

## Installation

### lazy.nvim

```lua
{
  "c0ptr/magpie.nvim",
  main = "magpie",
  event = "VeryLazy",
  opts = {}, -- calls require("magpie").setup({})
}
```

The default keymap is `<leader>tw` in Normal and Visual mode. To define the mapping yourself, set the built-in mappings to `false` and add your preferred `keys` entries in lazy.nvim.

## Usage

| Action | Result |
| --- | --- |
| `<leader>tw` in Normal mode | Translate the word under the cursor |
| `<leader>tw` in Visual mode | Translate the selection |
| Hover over a word | Translate after a short delay (enabled by default) |
| Drag to make a Visual selection | Translate on mouse release (enabled by default) |
| `:Magpie [text]` | Translate the given text, or the current selection/word when omitted |
| `:MagpieClose` | Close the result window |

Mouse interactions require `set mouse=a` in terminal Neovim. Hover uses `vim.on_key` and enables `mousemoveevent` while configured; it does not replace existing mouse-move mappings.

## Configuration

All options are optional. The following shows the defaults:

```lua
require("magpie").setup({
  source_lang = "auto",
  target_lang = "zh-CN",
  provider = "google", -- "google", "bing", "deepseek", or "youdao"

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

Persistent cache data is stored under `stdpath("data")/magpie/`. Disable automatic mouse actions with `hover = { enabled = false }` and/or `mouse_selection = { enabled = false }`.

### Providers and credentials

Keep API credentials out of your config files by using environment variables. Magpie reads the relevant environment variables automatically; equivalent Lua options are shown below.

**Azure Translator (Bing)** — create an Azure Translator resource. Set `AZURE_TRANSLATOR_KEY` and, when required by your resource, `AZURE_TRANSLATOR_REGION`.

```lua
require("magpie").setup({
  provider = "bing",
  bing = {
    api_key = vim.env.AZURE_TRANSLATOR_KEY,
    region = vim.env.AZURE_TRANSLATOR_REGION,
    -- endpoint = "https://api.cognitive.microsofttranslator.com",
  },
})
```

**Google Cloud Translation Basic** — set `GOOGLE_TRANSLATE_API_KEY` to use the official v2 API instead of the public endpoint.

```lua
require("magpie").setup({
  provider = "google",
  google = { api_key = vim.env.GOOGLE_TRANSLATE_API_KEY },
})
```

**DeepSeek** — set `DEEPSEEK_API_KEY`. DeepSeek translates through its chat-completions API, so responses may take longer than other providers.

```lua
require("magpie").setup({
  provider = "deepseek",
  deepseek = {
    api_key = vim.env.DEEPSEEK_API_KEY,
    -- model = "deepseek-flash",
    -- Optional: disable thinking for faster responses.
    extra_body = { thinking = { type = "disabled" } },
    -- proxy = "http://127.0.0.1:7890",
  },
})
```

**Youdao** — create credentials through the [Youdao AI Open Platform](https://ai.youdao.com/) and set `YOUDAO_APP_KEY` and `YOUDAO_APP_SECRET`.

```lua
require("magpie").setup({
  provider = "youdao",
  youdao = {
    app_key = vim.env.YOUDAO_APP_KEY,
    app_secret = vim.env.YOUDAO_APP_SECRET,
  },
})
```

### Offline dictionary and pronunciation

With the default `target_lang = "zh-CN"`, Magpie checks its bundled list of about 2,000 common English words before making a network request. The word list is sourced from [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords) (MIT). In-memory cache, disk cache, and the local dictionary are checked before the selected translation provider.

IPA is looked up separately using the free Dictionary API for single English words. IPA may display as `—` when unavailable; sentences still translate normally. The bundled dictionary is only for English words translated to Chinese.

## Lua API

```lua
local magpie = require("magpie")

magpie.translate("A clear mind", { target_lang = "zh-CN" })
magpie.translate_cursor()
magpie.translate_visual()
magpie.close()

-- Most recent result: { text, phonetic, translation }
print(vim.inspect(magpie.last_result))
```

## Health check and tests

Run `:checkhealth magpie` to check the Neovim version, `curl`, bundled dictionary, and provider credentials.

Run the network-free test suite with:

```sh
nvim --headless --clean -u tests/init.lua
```

## License

[MIT](LICENSE)
