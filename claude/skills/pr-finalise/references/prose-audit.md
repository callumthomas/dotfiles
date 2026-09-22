# Prose comment audit: subagent prompt template

Dispatch as a `general-purpose` subagent. Write the diff to a file first (`git diff -U0 origin/<base>...HEAD > <scratch>/diff.patch`) and fill `<<DIFF_PATH>>` with its absolute path.

---

You are auditing a pull request diff for non-functional comments. Read-only task: do not edit any file and do not run any command that changes state.

Read the unified diff at `<<DIFF_PATH>>`. It was produced with `git diff -U0`, so every line inside a hunk is either added (`+`) or removed (`-`). There are no context lines.

Consider ONLY added lines. Ignore removed lines and the `---`/`+++` file headers.

Compute each added line's number in the new file from its hunk header `@@ -a,b +c,d @@`: the first added line in the hunk is line `c`, and each following added line adds one. Removed lines do not advance the count.

Identify every comment on an added line using the comment syntax of the file's language, inferred from its extension or filename (Dockerfile, Jenkinsfile, Makefile): `#` for Python, shell, YAML, TOML, Dockerfile, Makefile, HCL/Terraform, `.properties`, `.ini`, `.conf`, `.htaccess` (PHP also accepts `#`); `//` and `/* */` for JavaScript, TypeScript, PHP, Go, Rust, Java, C-family, Groovy/Jenkinsfile, Less, SCSS, HCL/Terraform; `/* */` only for CSS; `--` for SQL; `<!-- -->` for HTML, XML, Markdown; `{{-- --}}` for Blade (`.blade.php` — check before treating as plain PHP); `{{/* */}}` for Helm and Go templates (`.tpl`); `{/* */}` inside JSX and TSX; `;` for `.ini`. Not comments: a `#`/`//` inside a string or URL, a PHP `#[...]` attribute, a Blade `{{ $x }}` echo.

In Python files, a docstring — a string literal (`"""..."""` or `'''...'''`) that is the first statement of a module, class, or function body — counts as a comment for this audit even though it carries no `#`. Docstrings are easy to miss because they look like ordinary string literals: for every added `def` or `class` line, and for the first added line of the file, deliberately check whether the next statement is a bare string literal, and if so, treat it as a comment.

A comment delimited by a block marker — `/*`, `/**`, `"""`, `'''`, `<!--`, `{/*`, `{{--`, or `{{/*` — is ONE item spanning from its opening line (`line`) to the line carrying its closing delimiter (`end_line`), reported at its opening line even when that line is bare (just `/*`, `/**`, or `"""`). Do not emit a separate item for each physical line inside the block. For example, this four-line licence block:

```
/*
 * Copyright (c) 2026 Delio. All rights reserved.
 * Licensed under the MIT License.
 */
```

is one item, `line` 1 and `end_line` 4, not four items. The same applies to a JSDoc or PHPDoc block opening with a bare `/**`; when open and close share one line, `end_line` equals `line`.

A run of consecutive single-line comments (`#`, `--`, `//`, with no blank or non-comment line between them) is ONE item, `end_line` its last line, only when every line in the run is commented-out code — text that looks like source, not prose. In every other case, each single-line comment is its own item, its own `line`, `end_line` equal to `line`, and its own verdict, even when adjacent to another comment. A directive immediately followed by an explanatory comment on the next line — `// phpcs:ignore Generic.Files.LineLength.TooLong` then `// The scope excludes accounts closed before 2020`, or `// eslint-disable-next-line ...` then `// because the dep array is intentional` — is two items, not one: merging them risks one verdict swallowing the other, and the removal step then acts on the wrong line.

Classify each item.

FUNCTIONAL, keep. Something other than a human reader consumes it:
- Tool directives and pragmas: `eslint-disable`, `eslint-enable`, `prettier-ignore`, `noqa`, `type: ignore`, `pyright: ignore`, `@ts-expect-error`, `@ts-ignore`, `fmt: off`, `fmt: on`, `nosec`, `nolint`, `pylint:`, `coverage: ignore`, `istanbul ignore`, `biome-ignore`, `phpcs:ignore`, `phpcs:disable`, `phpcs:enable`, `@phpstan-ignore-next-line`, `@psalm-suppress`, `stylelint-disable`, `tflint-ignore`, `checkov:skip`, `tfsec:ignore`, `hadolint ignore`, `go:build`, `go:generate`, `go:embed`, webpack magic comments such as `/* webpackChunkName */`.
- Shebangs and encoding declarations.
- Documentation comments in the language's documentation form: Python docstrings, JSDoc and TSDoc `/** */`, PHPDoc `/** */` (including inline `/** @var ... */`), rustdoc `///` and `//!`, godoc (the comment directly above an exported Go declaration), Javadoc, XML doc comments.
- Licence and copyright headers.
- Markers a tool needs to work: migration directives such as `-- +goose Up`; `# yaml-language-server: $schema=`; `# syntax=` in a Dockerfile.

PROSE, remove. Only a human reads it:
- Explanations of what code does or why, when not in the language's documentation-comment form.
- `TODO`, `FIXME`, `NOTE`, `HACK`, `XXX`, and similar.
- Commented-out code — text prefixed with a comment marker that nothing executes or reads; a consecutive run is one item, per the rule above.
- Section banners and dividers such as `// ---- helpers ----` or `# ===== Config =====`.
- Change-history and attribution notes.

Decision test when unsure: would any tool lose information or behave differently if this comment were deleted? Yes: functional. No: prose. Judge the comment's *form*, not how plain-English its *content* reads: a licence header or a docstring/JSDoc/PHPDoc block stays functional even when every sentence is ordinary explanation, because a doc generator, packaging step, or compliance scan still consumes it; commented-out code stays prose even though it resembles real syntax, because nothing runs or reads it.

Before you output anything, self-check for completeness: list every added line where a comment or docstring opens. Count that list. Your output array must contain exactly one item per opening line — never fewer (found but left out) and never more (one item split into several). If the two counts disagree, find the missing or duplicated item and fix it before producing the final output.

Output one JSON array inside a single fenced code block and nothing else. One object per item:

{"path": "<file path>", "line": <new-file line number where the item opens>, "end_line": <new-file line number where the item closes, equal to `line` for a single-line item>, "text": "<exact comment text, first line if multi-line>", "verdict": "functional" | "prose", "reason": "<one short clause>"}

Include every comment found, functional and prose. If there are none on added lines, output an empty array.
