# Magpie.nvim · v0.3

A lightweight, dependency-free translation plugin for Neovim. Translate the
word under your cursor, a Visual selection, or text you provide, then view the
source text, pronunciation, and translation in a native floating window.

v0.3 adds **code comment translation**: Chinese comments can be translated into
English automatically while you write, or on demand in manual mode. Detection
works across programming languages through tree-sitter when a parser is
available, with a `commentstring` fallback for every filetype Neovim knows.

> **README authorship:** The original README was written by GitHub Copilot.

![Neovim](https://img.shields.io/badge/Neovim-%3E%3D0.10-57A143?logo=neovim&logoColor=white)
![Version](https://img.shields.io/badge/version-0.3-blue)

## Features

- **Code comment translation (v0.3).** Translate Chinese comments into English
  (or the other way around) without touching the code around them.
  - `manual` mode: translate the comment under the cursor, a Visual selection,
    or all comments in the buffer on demand.
  - `auto` mode: translate the comments touched during the insert session when
    you leave Insert mode, with a debounce and stale-buffer protection.
  - Tree-sitter comment detection when a parser is installed; a built-in
    `commentstring` fallback plus common-language marker tables otherwise.
  - Preserves comment markers, indentation, block decorations (`/*`, `*`,
    `*/`), inline comments, TODO/FIXME tags, and code identifiers.
  - Skips tool directives such as `eslint-disable`, `@ts-ignore`, `noqa`,
    `nolint`, `SPDX-License-Identifier`, and Vim modelines.
  - Batches multiple comments into one request for `:MagpieComments`.
  - Runtime mode switching with `:MagpieCommentMode`.
- Providers: ChatGPT, Copilot, Gemini, DeepSeek, and Youdao (all key-backed).
- Bundled top-2000 English words plus ~300 programming terms (IPA + Chinese
  glosses): common and tech words translate instantly, even offline.
- Lookup order: in-memory cache → disk cache → local dictionary → network.
- Translate the word under the cursor, a Visual selection, or a word under the
  mouse pointer.
- Native non-focusable floating window, positioned next to the cursor or mouse.
- Dictionary IPA lookup runs in parallel with the translation request.
- In-flight requests are deduplicated; stale requests are cancelled.
- Streaming rendering for word translations: LLM output appears word by word.
- User dictionary: add your own entries via a config file.
- Persistent disk cache (survives restarts) with normalized cache keys.
- Never blocks the editor; all requests are asynchronous.
- `:checkhealth magpie` diagnostics.

## Requirements

- Neovim 0.10 or newer.
- `curl` available on `$PATH` for network translation and pronunciation.
- Internet access and credentials for the selected provider.
- Tree-sitter parsers are optional but recommended for precise comment
  detection.

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
`<leader>tw` mapping is installed in Normal and Visual mode, and `<leader>tc` /
`<leader>tC` for comment translation. To define the mappings yourself, set the
built-in mappings to `false` and add your preferred `keys` entries in lazy.nvim.

## Usage

| Action | Result |
| --- | --- |
| `<leader>tw` in Normal mode | Translate the word under the cursor |
| `<leader>tw` in Visual mode | Translate the selection |
| `<leader>tc` in Normal mode | Translate the comment under the cursor |
| `<leader>tc` in Visual mode | Translate comments in the selection |
| `<leader>tC` in Normal mode | Translate all translatable comments in the buffer |
| Hover over a word | Translate after a short delay (enabled by default) |
| Drag to make a Visual selection | Translate on mouse release (enabled by default) |
| `:Magpie [text]` | Translate the given text, or the current selection/word when omitted |
| `:MagpieComment` | Translate the comment under the cursor; also accepts a range |
| `:MagpieComments` | Translate all translatable comments in the buffer (batched) |
| `:MagpieCommentMode [auto\|manual\|toggle\|off]` | Show or switch comment translation mode |
| `:MagpieCommentsCheck` | List translatable comments in the quickfix list |
| `:MagpieClose` | Close the result window |

Mouse interactions require `set mouse=a` in terminal Neovim. Hover uses
`vim.on_key` and enables `mousemoveevent` while configured; it does not replace
existing mouse-move mappings.

## Comment translation

Comment translation is enabled by default in **manual** mode, so nothing rewrites
your files until you ask. Enable automatic translation with one option:

```lua
require("magpie").setup({
  comment_translation = {
    mode = "auto",  -- translate comments touched during insert on InsertLeave
  },
})
```

In auto mode, Magpie waits until you leave Insert mode, then translates the
comment blocks you touched during that insert session (including the one at the
cursor). This means writing a comment, pressing Enter, and continuing with code
still translates the comment you just wrote. It never rewrites the whole buffer
automatically. If the buffer changes while the request is in flight, the result
is discarded rather than applied to shifted text. Translation is asynchronous:
if you save immediately after leaving Insert mode, wait for the translation and
write again. Magpie warns when a translation lands right after a write.

### What counts as a comment?

- Tree-sitter `comment`, `line_comment`, `block_comment`, `doc_comment`, and
  `multiline_comment` nodes when a parser is available for the buffer (or for an
  injected language).
- Otherwise, `commentstring` plus a built-in table of common comment markers:
  `//`, `#`, `--`, `;`, `%`, `"`, `'`, `rem`, `!`, `*`, `/* */`, `<!-- -->`,
  `{- -}`, `(* *)`, `--[[ ]]`, `#[ ]#`, `#| |#`, `%{ %}`, `<# #>`,
  `=begin/=end`, and others.
- Inline trailing comments, multi-line line-comment blocks, and block comments
  are supported. Detection targets comments; code between and around them is
  never rewritten, and a tree-sitter parser also reliably excludes strings and
  docstrings.

The bundled fallback is enough for most languages Neovim has a filetype plugin
for. Installing a tree-sitter parser improves accuracy for languages with
grammar-specific comment nodes (Rust, Java, Vue, Markdown code blocks, and so
on) and avoids false positives in strings.

Without a parser, the fallback scanner is deliberately syntax-light. It
understands quoted strings and common comment markers, but comment-like text
inside multi-line strings (Python triple quotes, Lua long brackets, shell
heredocs) may be mistaken for a comment. Install the language parser for best
results; `use_treesitter = false` is mainly useful for testing or when a
particular parser produces bad nodes. This matters most for auto mode: install
the parsers for languages you write regularly before enabling automatic
rewrites.

### What is preserved?

Only the natural-language content of comments is replaced. Comment markers,
indentation, block decorations, and surrounding code stay untouched. Each
translation run is its own undo block, so one `u` restores the source comment
without undoing your recent typing. When a translation has a different number
of lines than the source, the comment is collapsed into a single line rather
than corrupting the file. Tags such as
`TODO`, `FIXME`, and `NOTE`, inline code, URLs, and identifiers are kept by the
prompt.

Tool directives (`eslint-disable`, `@ts-ignore`, `noqa`, `nolint`,
`type: ignore`, `go:generate`, `SPDX-License-Identifier`, Vim modelines, and
similar) are skipped by default. Shebangs are ignored.

### Reverse direction

`target_lang` controls the direction. The default translates Chinese comments
into English; set it to `"zh-CN"` to translate English comments into Chinese:

```lua
require("magpie").setup({
  comment_translation = {
    mode = "manual",
    target_lang = "zh-CN",
  },
})
```

### Comment translation options

```lua
require("magpie").setup({
  keymaps = {
    comment = "<leader>tc",   -- Normal/Visual: comment under cursor/selection
    comments = "<leader>tC",  -- Normal: all comments in the buffer
  },

  comment_translation = {
    enabled = true,
    mode = "manual",        -- "manual" or "auto"
    target_lang = "en",     -- Chinese -> English; use "zh-CN" for the reverse
    source_lang = "auto",   -- provider hint; "auto" is usually best
    filetypes = nil,        -- nil = all filetypes; a list restricts the feature
    exclude_filetypes = {   -- skipped even when filetypes is nil
      "checkhealth", "diff", "gitcommit", "gitrebase", "help", "lspinfo",
      "man", "markdown", "neo-tree", "notify", "noice", "NvimTree",
      "prompt", "qf", "snacks_dashboard", "text",
    },
    use_treesitter = true,  -- false forces the commentstring scanner
    debounce_ms = 500,      -- delay after InsertLeave in auto mode
    max_batch = 6,          -- comments per request for :MagpieComments
    max_chars = 3000,       -- comments longer than this (bytes) are skipped
    notify = "on_error",    -- "always", "on_error", or "never"
    skip_patterns = {       -- Lua patterns; matching comments are skipped
      "eslint%-disable", "eslint%-enable",
      "@ts%-ignore", "@ts%-expect%-error",
      "noqa", "nolint", "type:%s*ignore",
      "go:generate", "go:build", "go:embed", "^%+build",
      "SPDX%-License%-Identifier", "^vim:", "^vi:", "^ex:",
    },
  },
})
```

The `comment` and `comments` keymap entries live in the top-level `keymaps`
table, next to `normal` and `visual`. Set either to `false` to disable it.

The mode can be changed without restarting Neovim:

```vim
:MagpieCommentMode          " show the current mode
:MagpieCommentMode auto     " enable automatic translation
:MagpieCommentMode manual   " only translate on demand
:MagpieCommentMode toggle   " switch between auto and manual
:MagpieCommentMode off      " disable comment translation
```

For a statusline component:

```lua
-- e.g. lualine
{ function() return "magpie:" .. require("magpie").comment_mode() end }
```

### Privacy and limits

Comments are sent to the configured translation provider. Use
`comment_translation.enabled = false` or `:MagpieCommentMode off` if comments
may contain secrets. Auto mode only sends comments that contain Chinese (or
English, for the reverse direction); it does not upload every buffer. Very long
comments are skipped (`max_chars`), and unknown filetypes without comment syntax
are left alone.

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
    normal = "<leader>tw",   -- Normal mode: word under cursor
    visual = "<leader>tw",   -- Visual mode: selection
    comment = "<leader>tc",  -- Normal/Visual mode: comment translation
    comments = "<leader>tC", -- Normal mode: all comments in the buffer
  },

  -- Code comment translation (see the section above)
  comment_translation = {
    enabled = true,
    mode = "manual", -- "manual" | "auto"
    target_lang = "en",
    source_lang = "auto",
    filetypes = nil,
    exclude_filetypes = {
      "checkhealth", "diff", "gitcommit", "gitrebase", "help", "lspinfo",
      "man", "markdown", "neo-tree", "notify", "noice", "NvimTree",
      "prompt", "qf", "snacks_dashboard", "text",
    },
    use_treesitter = true,
    debounce_ms = 500,
    max_batch = 6,
    max_chars = 3000,
    notify = "on_error",
    skip_patterns = {
      "eslint%-disable", "eslint%-enable",
      "@ts%-ignore", "@ts%-expect%-error",
      "noqa", "nolint", "type:%s*ignore",
      "go:generate", "go:build", "go:embed", "^%+build",
      "SPDX%-License%-Identifier", "^vim:", "^vi:", "^ex:",
    },
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
  local_dictionary = {
    enabled = true,
    user_file = nil, -- default: ~/.config/nvim/magpie-dict.txt
  },

  -- Stream LLM output into the window word by word
  stream = { enabled = true },

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

Automatic Chinese-to-English comment translation while writing:

```lua
require("magpie").setup({
  provider = "deepseek",
  comment_translation = { mode = "auto", target_lang = "en" },
})
```

Manual comment translation only, with every other automatic feature off:

```lua
require("magpie").setup({
  comment_translation = { mode = "manual" },
  hover = { enabled = false },
  mouse_selection = { enabled = false },
})
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
  comment_translation = { enabled = false },
})
```

Words outside the dictionary then show an error instead of translating.

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

Magpie bundles the ~2000 most common English words plus ~300 programming
terms (languages, frameworks, tools, and concepts; IPA + Chinese glosses) and
checks them before any network request. Word list from
[hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords) (MIT).
With the default `target_lang = "zh-CN"`, the plugin checks the bundled list
after the in-memory and disk caches and before contacting the selected provider.

The bundled dictionary works offline for covered words. Disable it with
`local_dictionary = { enabled = false }`. IPA is looked up separately using
the free Dictionary API for single English words; it may display as `—` when
unavailable, and sentences do not have IPA.

### User dictionary

Create `~/.config/nvim/magpie-dict.txt` (or set `local_dictionary.user_file`)
with one entry per line; entries override the bundled dictionary and work
offline:

```txt
kubernetes	Kubernetes（容器编排平台）
alias	别名
```

The word may contain `+ # . -`. Restart Neovim (or run
`require("magpie").setup()` again) to reload the file.

## Notes on IPA

Translation services do not reliably expose IPA. For a single English word the
plugin looks up IPA from the free Dictionary API in parallel with translation;
if it is unavailable, or the text is a sentence, the IPA field intentionally
shows `—`.

## Public API (Lua API)

```lua
local magpie = require("magpie")

-- Word / selection translation
magpie.translate("A clear mind", { target_lang = "zh-CN" })
magpie.translate_cursor()
magpie.translate_visual()
magpie.translate_from_command("hello")
magpie.close()
magpie.last_result -- { text, phonetic, translation } of the last word result

-- Comment translation (v0.3)
magpie.translate_comment()             -- comment under the cursor / Visual range
magpie.translate_comment({ range = { 4, 9 } }) -- zero-based first/last row
magpie.translate_comments()            -- every translatable comment in the buffer
magpie.check_comments({ open = false }) -- number of comments; optional quickfix
magpie.comment_mode()                  -- "auto", "manual", or "off"
magpie.set_comment_mode("auto")        -- "auto", "manual", "toggle", or "off"
magpie.version                         -- "0.3.0"
```

## Health check and tests

Run `:checkhealth magpie` to check the Neovim version, `curl`, bundled
dictionary, provider credentials, and comment translation mode. Run the
network-free test suite with:

```sh
nvim --headless --clean -i NONE -u tests/init.lua
```

CI runs the tests on Neovim 0.10–nightly. Format with
[stylua](https://github.com/JohnnyMorganz/StyLua) (config included).

See [ROADMAP.md](ROADMAP.md) for planned features and [CHANGELOG.md](CHANGELOG.md)
for release notes.

## License

MIT
