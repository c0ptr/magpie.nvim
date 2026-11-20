# Changelog

## v0.3.0

### Added

- **Code comment translation.** Translates the natural-language text of
  comments without touching markers, indentation, block decoration, or
  surrounding code.
- Comment translation modes:
  - `manual` (default): `:MagpieComment`, `:MagpieComments`, `<leader>tc`,
    `<leader>tC`, Visual selections, and explicit ranges.
  - `auto`: translates the comment blocks touched during the insert session
    after `InsertLeave`, with a configurable debounce. Rows are tracked with
    extmarks so a comment written before continuing with code is still caught.
    It never rewrites the whole buffer automatically.
- `:MagpieCommentMode [auto|manual|toggle|off]` for runtime mode switching and
  `require("magpie").comment_mode()` for statusline components.
- `:MagpieCommentsCheck` lists translatable comments in the quickfix list and
  marks skipped directives.
- Comment detection through tree-sitter (`comment`, `line_comment`,
  `block_comment`, `doc_comment`, `multiline_comment`) with a `commentstring`
  plus common-language marker fallback for filetypes without a parser.
- Inline trailing comments, multi-line line-comment blocks, block comments,
  Javadoc-style decoration, HTML comments, Lua long-bracket comments, and more.
- Batched comment translation for `:MagpieComments` (one request for several
  comments, with an automatic per-comment fallback if the response cannot be
  split).
- Reverse direction support through `comment_translation.target_lang`.
- Skip patterns for tool directives (`eslint-disable`, `@ts-ignore`, `noqa`,
  `nolint`, `type: ignore`, `go:generate`, `SPDX-License-Identifier`, Vim
  modelines) and configurable filetype allow/deny lists.
- Comment translations share the in-memory and on-disk cache. The cache key
  keeps line structure for comment blocks so cached translations can still be
  applied safely.
- Stale-request protection: if the buffer changes while a comment translation
  is in flight, the result is discarded.
- Applied translations are their own undo block, so one `u` restores the source
  comment without undoing the code or comment you just typed.
- A warning is emitted when an asynchronous auto translation lands immediately
  after the buffer was written, so the translation is not silently left unsaved.
- `comment_translation.notify` (`always`, `on_error`, `never`), `max_chars`,
  `max_batch`, `debounce_ms`, `use_treesitter`, and `skip_patterns` options.
- Custom provider prompts. LLM providers now accept an optional system prompt,
  which the comment translator uses for line-count and marker-preserving
  instructions.
- Health check reports the comment translation mode and tree-sitter
  availability.

### Changed

- Translation request handling moved into a shared `magpie.engine` module used
  by word and comment translation. Careful users of the public API are
  unaffected; provider behavior, deduplication, cancellation, streaming, and
  disk caching are preserved.
- README and `:help magpie` were rewritten for v0.3, with a dedicated comment
  translation section.
- The test suite now covers comment detection (fallback and tree-sitter),
  marker-preserving replacement, line-count collapse, batching and fallback,
  auto/manual modes, tool-directive skipping, quickfix listing, mode switching,
  and custom prompts.

### Notes

- The default comment mode is `manual` so upgrading does not rewrite existing
  files. Set `comment_translation = { mode = "auto" }` to enable automatic
  translation.
- Comments are sent to the configured provider. See the privacy notes in the
  README.

## v0.2.0

- Streaming LLM rendering.
- Persistent disk cache.
- In-flight deduplication and stale-request cancellation.
- User dictionary support.
- Bundled programming-term dictionary.

## v0.1.0

- Initial word and Visual-selection translation.
- ChatGPT, Copilot, Gemini, DeepSeek, and Youdao providers.
- Hover and mouse-selection translation.
- Floating result window and `:checkhealth` support.
