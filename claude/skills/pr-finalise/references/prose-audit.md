# Prose comment audit: subagent prompt template

Dispatch as a `general-purpose` subagent. Write the diff to a file first (`git diff -U0 origin/<base>...HEAD > <scratch>/diff.patch`) and fill `<<DIFF_PATH>>` with its absolute path.

---

You are auditing a pull request diff for non-functional comments. Read-only task: do not edit any file and do not run any command that changes state.

Read the unified diff at `<<DIFF_PATH>>`. It was produced with `git diff -U0`, so every line inside a hunk is either added (`+`) or removed (`-`). There are no context lines.

Consider ONLY added lines. Ignore removed lines and the `---`/`+++` file headers.

Compute each added line's number in the new file from its hunk header `@@ -a,b +c,d @@`: the first added line in the hunk is line `c`, and each following added line adds one. Removed lines do not advance the count.

Identify every comment on an added line using the comment syntax of the file's language, inferred from its extension: `#` for Python, shell, YAML, TOML, Ruby, Dockerfile; `//` and `/* */` for JavaScript, TypeScript, Go, Rust, Java, C-family; `--` for SQL; `<!-- -->` for HTML, XML, Markdown, Vue templates; `{/* */}` inside JSX and TSX. A `#` or `//` inside a string literal is not a comment.

A Python docstring is a string literal (`"""..."""` or `'''...'''`) that is the first statement of a module, class, or function body, and it counts as a comment for this audit even though it carries no `#`. Docstrings are easy to miss because they look like ordinary string literals rather than comments: for every added `def` or `class` line, and for the first added line of a file, deliberately check whether the next statement is a bare string literal, and if so, treat it as a comment.

A multi-line comment or docstring — anything opening with `/*`, `/**`, `"""`, `'''`, or a run of consecutive `#`/`--`/`//` lines with no blank or non-comment line between them — is ONE item, reported once at the line where it opens, even when that opening line carries no text of its own (a bare `/*`, a bare `/**`, or a bare `"""` alone on its line). Do not emit a separate item for each physical line of the block. For example, this four-line licence block:

```
/*
 * Copyright (c) 2026 Delio. All rights reserved.
 * Licensed under the MIT License.
 */
```

is one item, keyed to the line carrying `/*`, not four items. The same applies to a JSDoc block that opens with a bare `/**`, and to commented-out code that spans several consecutive `#` or `//` lines — that run is one block and one item, keyed to its first line, not one item per line.

Classify each item.

FUNCTIONAL, keep. Something other than a human reader consumes it:
- Tool directives and pragmas: `eslint-disable`, `eslint-enable`, `prettier-ignore`, `noqa`, `type: ignore`, `pyright: ignore`, `@ts-expect-error`, `@ts-ignore`, `fmt: off`, `fmt: on`, `nosec`, `nolint`, `pylint:`, `coverage: ignore`, `istanbul ignore`, `biome-ignore`, `rubocop:disable`, clippy attributes, `#pragma`.
- Shebangs and encoding declarations.
- Documentation comments in the language's documentation form: Python docstrings, JSDoc and TSDoc `/** */`, rustdoc `///` and `//!`, godoc (the comment directly above an exported Go declaration), Javadoc, XML doc comments. These stay functional even when their wording reads as plain explanation — judge the comment's *form* (is it the language's recognised documentation form, read by a doc generator, IDE, or type checker), never how explanatory its *content* sounds.
- Licence and copyright headers. These are functional regardless of how much plain English they contain — a build, packaging, or compliance step reads them, and their absence is legally meaningful, even though a human can also read them.
- Type comments a checker reads: `# type:`, `@type {}` in JSDoc, `// @flow`.
- Markers a tool needs to work: migration directives such as `-- +goose Up`, `-- migrate:up`, `--> statement-breakpoint`; `# yaml-language-server: $schema=`; `# syntax=` in a Dockerfile; `# frozen_string_literal: true`; template engine directives placed in comments.

PROSE, remove. Only a human reads it:
- Explanations of what code does or why, including a plain comment above a function or block that describes it but is not in the language's documentation-comment form.
- `TODO`, `FIXME`, `NOTE`, `HACK`, `XXX`, and similar — no tool consumes these, so they are prose regardless of how actionable they sound.
- Commented-out code — text that looks like code but is prefixed with a comment marker so nothing executes, imports, or reads it. Resembling real syntax does not make it functional; the test is whether anything runs or reads it, and for commented-out code nothing does.
- Section banners and dividers such as `// ---- helpers ----` or `# ===== Config =====`.
- Change-history and attribution notes.

Decision test when unsure: if this comment were deleted, would any tool, build, linter, type checker, documentation generator, or framework behave differently or lose information it consumes? Yes: functional. No: prose. Apply this to the comment's *form*, not to how plain-English it reads — a licence header or a docstring/JSDoc block stays functional under this test even when every sentence in it is ordinary explanation, because deleting it changes what a doc generator, packaging step, or compliance scan sees; conversely, commented-out code stays prose even though it looks like real syntax, because deleting it changes nothing a tool reads.

Before you output anything, self-check for completeness: list every added line where a comment or docstring opens, including any you found by checking `def`/`class` lines and file-opening lines for docstrings. Count that list. Your output array must contain exactly one item per opening line in it — never fewer (something you found while scanning but left out of the output) and never more (one block emitted as several per-line items). If the two counts disagree, find the missing or duplicated item and fix it before producing the final output.

Output one JSON array inside a single fenced code block and nothing else. One object per item:

{"path": "<file path>", "line": <new-file line number>, "text": "<exact comment text, first line if multi-line>", "verdict": "functional" | "prose", "reason": "<one short clause>"}

Include every comment found, functional and prose. If there are none on added lines, output an empty array.
