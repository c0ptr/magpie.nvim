# word-translate.nvim

A dependency-free Neovim translation plugin for English words and sentences. It
shows the source text, IPA pronunciation, and translation in a native floating
window.

![Neovim](https://img.shields.io/badge/Neovim-%3E%3D0.10-57A143?logo=neovim&logoColor=white)

## Features

- Translate the word under the cursor or under the mouse pointer.
- Translate Visual selections, including selections made by dragging the mouse.
- Native non-focusable floating window, positioned next to the cursor or mouse.
- Displays **source text**, **IPA**, and **translation**.
- Google Translate adapter works out of the box; Azure Translator (Bing) is also
  available.
- Uses current Neovim APIs: `vim.system`, `vim.json`, `vim.on_key`,
  `nvim_open_win`, and `getregion`.
- Keeps a small in-memory cache and never blocks the editor while requesting a
  translation.

## Requirements

- Neovim 0.10 or newer (tested on 0.12).
- `curl` available on `$PATH`.
- Internet access.

The default Google provider uses Google's public web-translation endpoint. It
does not require a key, but it is not a Google Cloud SLA-backed API, can change,
and may temporarily rate-limit automated traffic. Set `google.api_key` to use
the official Google Cloud Translation Basic API instead, or use the key-backed
`bing` provider below.

## lazy.nvim

```lua
{
  "your-name/word-translate.nvim",
  main = "word-translate",
  event = "VeryLazy",
  opts = {
    target_lang = "zh-CN", -- the default
  },
  keys = {
    { "<leader>tw", "<cmd>WordTranslate<cr>", mode = { "n", "x" }, desc = "Translate word or selection" },
  },
}
```

`opts = {}` calls `require("word-translate").setup({})` automatically. If you
prefer the plugin's built-in mappings, omit `keys`; `<leader>tw` is installed in
Normal and Visual mode by default.

## Usage

| Action | Default behavior |
| --- | --- |
| `<leader>tw` in Normal mode | Translate the word under the cursor |
| `<leader>tw` in Visual mode | Translate the selected word or sentence |
| Hover a word with the mouse | Translate after a short delay |
| Drag to make a Visual selection with the mouse | Translate on mouse release |
| `:WordTranslate [text]` | Translate an explicit text, or the current word/selection |
| `:WordTranslateClose` | Close the floating result window |

Mouse hover needs `set mouse=a` in terminal Neovim. The plugin enables
`mousemoveevent` only while hover translation is enabled; it receives events
through `vim.on_key`, so it does not replace your `<MouseMove>` mappings.

## Configuration

```lua
require("word-translate").setup({
  target_lang = "zh-CN",
  source_lang = "auto",
  provider = "google", -- "google" or "bing"

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
})
```

### Azure Translator (Bing)

Microsoft's Translator service is the supported Bing translation API. Create an
Azure Translator resource, then configure it with either environment variables
or Lua options:

```lua
require("word-translate").setup({
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
require("word-translate").setup({
  provider = "google",
  google = {
    api_key = vim.env.GOOGLE_TRANSLATE_API_KEY,
  },
})
```

This uses `https://translation.googleapis.com/language/translate/v2`; enable
Cloud Translation Basic in the Google Cloud project that owns the key.

### Disable automatic mouse actions

```lua
require("word-translate").setup({
  hover = { enabled = false },
  mouse_selection = { enabled = false },
})
```

## Public API

```lua
local translate = require("word-translate")

translate.translate("A clear mind", { target_lang = "zh-CN" })
translate.translate_cursor()
translate.translate_visual()
translate.close()
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

## License

MIT
