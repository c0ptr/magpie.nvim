# Roadmap

This is a working list, not a promise. Priorities may change based on real
usage. Items marked **v0.3** are already implemented.

## Shipped in v0.3

- **v0.3** Comment translation (manual and automatic modes).
- **v0.3** Tree-sitter plus `commentstring` comment detection.
- **v0.3** `:MagpieComment`, `:MagpieComments`, `:MagpieCommentsCheck`,
  `:MagpieCommentMode`.
- **v0.3** Batched translation and per-comment fallback.
- **v0.3** Tool-directive skipping and stale-buffer protection.
- **v0.3** Shared translation engine with custom prompts and block-aware cache
  keys.

## Next: safer and more predictable automation

1. **Preview before apply (high priority).**
   Show the proposed translation in virtual text or a small diff, with
   `accept`/`reject`/`edit` actions. Auto mode could then default to preview
   instead of direct replacement, which is friendlier for teams and code
   review.

2. **Project glossary and translation memory.**
   A project-local glossary (for example `.magpie/glossary.json`) for consistent
   terminology: "功能" -> "feature", "缓存" -> "cache", product names that must
   not be translated. Reuse previous translations for identical sentences and
   let users edit/approve them.

3. **Project-level configuration and filters.**
   A `.magpie.json`/`.magpie.lua` file per repository: target language, skip
   patterns, protected filetypes, generated-file detection, and branch rules.
   Respect `.gitignore` and skip vendored/minified/generated files by default.

4. **Comment-aware translation of structured text.**
   Keep doc-comment tags intact (`@param`, `@return`, `:param`, `@throws`,
   JSDoc/JavaDoc/Doxygen), translate only descriptions, and preserve Markdown
   lists, code spans, tables, and fenced blocks inside comments. Handle
   localization files and embedded Markdown separately.

5. **Review workflow.**
   `:MagpieReview` opens a list (quickfix, telescope, or snacks picker) of all
   Chinese comments with actions: translate, accept, reject, edit, jump to
   context. Optional diagnostics (`vim.diagnostic`) mark untranslated comments
   in the sign column.

## Integration and editor UX

6. **LSP code action.**
   Offer "Translate comment" as a code action for the current line or range,
   so it is discoverable from the standard LSP UI.

7. **Diff-aware auto mode.**
   Translate only comments in the current diff from `gitsigns.nvim` or
   `mini.diff`, avoiding unrelated changes during a focused edit or commit.

8. **Inline virtual text and side panel.**
   A non-intrusive display mode showing translations as virtual text below the
   comment, plus a persistent side panel for long comments or whole-file
   review. Keep the current floating window as the default.

9. **Bilingual comments.**
   Optionally keep the original text and append the translation, or write
   `English（中文）` style bilingual comments. Useful for teams that want both
   languages.

10. **Statusline and notifications.**
    A compact status component showing `magpie:auto`, pending requests, and
    per-buffer counts of untranslated comments.

## Beyond comments

11. **Commit message and PR description translation.**
    `:MagpieCommit` / a `gitcommit` filetype hook to translate a Chinese commit
    message to English while preserving Conventional Commits prefixes and
    trailers.

12. **Identifier and string explanations.**
    Translate or explain English identifiers and UI strings for Chinese
    developers (`MagpieExplainName`), and help choose English names for Chinese
    concepts (`MagpieName`). Do not rename automatically without confirmation.

13. **Documentation translation.**
    A separate mode for Markdown/AsciiDoc prose with code fences protected; do
    not mix it with source-code comment rules.

14. **Bidirectional mode.**
    Automatic selection between Chinese-to-English and English-to-Chinese based
    on the current buffer/project, with per-project defaults. v0.3 already
    supports the direction via `comment_translation.target_lang`.

## Infrastructure and quality

15. **Offline/local providers.**
    Ollama, llama.cpp server, and a local translation memory provider for users
    who cannot send source comments to a cloud API. Add a redaction mode for
    secrets and URLs.

16. **Queue, retries, and rate limiting.**
    A small request queue with exponential backoff, rate limiting, cancellation
    on `:MagpieClose`/mode change, and a `:MagpieQueue` diagnostic view.

17. **Cache management.**
    `:MagpieCacheClear`, cache statistics, per-project cache scoping, and a
    way to remove a bad translation from both memory and disk caches.

18. **Testing and CI hardening.**
    Windows path/curl tests, tree-sitter parser fixtures, luacheck/stylua CI,
    and a suite that runs with and without tree-sitter.

## Explicit non-goals

- Replacing a full prose translation plugin.
- Automatically rewriting code, strings, or identifiers without confirmation.
- Sending every buffer to a remote provider in auto mode.
