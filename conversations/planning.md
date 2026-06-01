date: 2026-05-22T 9:05:00Z
participants:
- You: Henry
- Assistant: VS Code Copilot Chat, GPT 5.2 Codex
tooling:
vscode: "1.21.0"
topic: "Planning of Implementation"

User: Hello, I need some help with some tasks. Please develop a procedure to implement new ciphers in the same style as the other ones in /cipher_implementation/ and with the help of the already established building blocks. Include implementational specialities and pitfalls. You may write your findings into a README.

GitHub Copilot: Optimized tool selection

Searched for files matching `**/implement_cipher.rst`, 1 match

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/__init__.py)

Read [](file:///home/user/CiVerLy-forked/docs/source/documentation/implementations/index.rst)

Read [](file:///home/user/CiVerLy-forked/docs/source/documentation/cipher.rst)

Read [](file:///home/user/CiVerLy-forked/docs/source/user_manual/implement_cipher.rst)

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/abc.py)

Read [](file:///home/user/CiVerLy-forked/docs/source/developer_manual/file_structure.rst)

Searched for files matching `**/src/civerly/cipher_implementations/**/README*`, no matches

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/present.py#1-1), lines 1 to 300

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/skinny.py#1-1), lines 1 to 300

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/aes.py#1-1), lines 1 to 400

Created [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/README.md)

Added a concise implementation guide for new ciphers in README.md, aligned with the style and constraints used in existing cipher implementations. It covers class selection, DAG construction, modeling-friendly components, AESlike indexing quirks, key schedule choices, and common pitfalls, plus a minimal template and example pointers.

If you want, I can also:
1) Cross-link this from the docs (e.g., user manual).
2) Add a short checklist to each cipher file as a header comment.

Made changes.

User: Would you mind making it even more detailed?

GitHub Copilot: Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/README.md)

Generating patch (136 lines) in [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/README.md)


```

```
Expanded the guide in README.md with more concrete steps, edge-mapping details, modeling notes, key schedule guidance, and a broader pitfalls checklist.

If you want it even deeper, I can also:
1) Add a short “component-to-modeling” table with which options are supported where.
2) Add a section on validation/debugging strategies (intermediate round checks, graph inspection).

Made changes.

date: 2026-05-25T 10:45:00Z
participants:
- You: Henry
- Assistant: VS Code Copilot Chat, GPT 5.4 mini
tooling:
vscode: "1.21.0"
topic: "Planning of Implementation"

User: Please review this implementation guide for new ciphers. Please include some details to classes and modules that are commonly used and cover common pitfalls.

GitHub Copilot: Optimized tool selection. I’m checking the guide against the actual cipher modules and examples so I can tighten the recommendations where the codebase already has clear patterns, then I’ll patch the README directly.

Read [](file:///home/user/CiVerLy-forked/documentation/README.md)

Searched for files matching `**/aes.py`, 1 match

Searched for files matching `**/present.py`, 1 match

Searched for files matching `**/abc.py`, 1 match

I’ve confirmed the guide is broadly sound, but it’s light on the concrete entry points developers actually import. I’m reading the canonical examples now so I can name the right classes and point out the pitfalls that show up in real implementations.

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/aes.py#1-1), lines 1 to 260

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/present.py#1-1), lines 1 to 260

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/abc.py)

Read [](file:///home/user/CiVerLy-forked/src/civerly/component.py#1-1), lines 1 to 260

The examples confirm a few practical details worth folding into the guide: which imports are used in real ciphers, where SAT vs MILP breaks, and what “Unnamed Component” means in trail checks. I’m grabbing the base classes next so the guide points at the right modules, not just the right ideas.

Read [](file:///home/user/CiVerLy-forked/src/civerly/sboxcipher.py#1-1), lines 1 to 220

Read [](file:///home/user/CiVerLy-forked/src/civerly/wordbasedcipher.py)

Read [](file:///home/user/CiVerLy-forked/src/civerly/wordsboxcipher.py)

Read [](file:///home/user/CiVerLy-forked/src/civerly/aeslike.py)

I have enough context to make a focused update now. The patch will add the concrete module/class names people actually import, fix the incomplete key-schedule guidance, and sharpen the pitfall list around the most common wiring and modeling mistakes.

Apply Patch

The first patch draft was rejected on format, so I’m resubmitting the same focused update with the required tool metadata.

Generating patch (100 lines) in [](file:///home/user/CiVerLy-forked/documentation/README.md)


```

```
The README patch is in place. I’m doing a narrow validation pass on just that file now to make sure the edits stayed localized and the revised wording reads cleanly.

Ran terminal command:  git diff -- documentation/README.md

`git diff` came back empty, so I’m checking repository status directly to confirm the file is tracked in the current worktree and to verify the exact scope of the change.

Ran terminal command:  git status --short && git diff --stat -- documentation/README.md

The repository is treating the whole documentation folder as untracked, so `git diff` is not useful here. I’m verifying the edited content directly instead of relying on git output.

Read [](file:///home/user/CiVerLy-forked/documentation/README.md)

Read [](file:///home/user/CiVerLy-forked/documentation/README.md#200-200), lines 200 to 200

I updated documentation/README.md to make the guide more concrete and implementation-oriented. The revised version now names the commonly used modules and classes developers actually import, points to the existing cipher patterns in aes.py, present.py, abc.py, and `skinny.py`, and expands the component guidance with the usual `civerly.component` building blocks.

I also tightened the key-schedule section, added more explicit test and doctest guidance, and expanded the pitfalls list around the issues that most often break modeling: word-vs-bit edge wiring, unsupported component combinations, matrix shape/type mismatches, and AESlike column alignment. I validated the edited content directly in the file; git diff was not useful here because the documentation folder is currently treated as untracked in this worktree.

Made changes.

date: 2026-05-25T 13:00:00Z
participants:
- You: Henry
- Assistant: VS Code Copilot Chat, GPT 5.4 mini
tooling:
vscode: "1.21.0"
topic: "Planning of Implementation"

User: Please review this implementation guide for new ciphers. Please include some details to classes and modules that are commonly used and cover common pitfalls.

GitHub Copilot: Optimized tool selectionI’m checking the guide against the actual cipher modules and examples so I can tighten the recommendations where the codebase already has clear patterns, then I’ll patch the README directly.

Read [](file:///home/user/CiVerLy-forked/documentation/README.md)

Searched for files matching `**/aes.py`, 1 match

Searched for files matching `**/present.py`, 1 match

Searched for files matching `**/abc.py`, 1 match

I’ve confirmed the guide is broadly sound, but it’s light on the concrete entry points developers actually import. I’m reading the canonical examples now so I can name the right classes and point out the pitfalls that show up in real implementations.

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/aes.py#1-1), lines 1 to 260

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/present.py#1-1), lines 1 to 260

Read [](file:///home/user/CiVerLy-forked/src/civerly/cipher_implementations/abc.py)

Read [](file:///home/user/CiVerLy-forked/src/civerly/component.py#1-1), lines 1 to 260

The examples confirm a few practical details worth folding into the guide: which imports are used in real ciphers, where SAT vs MILP breaks, and what “Unnamed Component” means in trail checks. I’m grabbing the base classes next so the guide points at the right modules, not just the right ideas.

Read [](file:///home/user/CiVerLy-forked/src/civerly/sboxcipher.py#1-1), lines 1 to 220

Read [](file:///home/user/CiVerLy-forked/src/civerly/wordbasedcipher.py)

Read [](file:///home/user/CiVerLy-forked/src/civerly/wordsboxcipher.py)

Read [](file:///home/user/CiVerLy-forked/src/civerly/aeslike.py)

I have enough context to make a focused update now. The patch will add the concrete module/class names people actually import, fix the incomplete key-schedule guidance, and sharpen the pitfall list around the most common wiring and modeling mistakes.

Apply Patch

The first patch draft was rejected on format, so I’m resubmitting the same focused update with the required tool metadata.

Generating patch (100 lines) in [](file:///home/user/CiVerLy-forked/documentation/README.md)


```

```
The README patch is in place. I’m doing a narrow validation pass on just that file now to make sure the edits stayed localized and the revised wording reads cleanly.

Ran terminal command:  git diff -- documentation/README.md

`git diff` came back empty, so I’m checking repository status directly to confirm the file is tracked in the current worktree and to verify the exact scope of the change.

Ran terminal command:  git status --short && git diff --stat -- documentation/README.md

The repository is treating the whole documentation folder as untracked, so `git diff` is not useful here. I’m verifying the edited content directly instead of relying on git output.

Read [](file:///home/user/CiVerLy-forked/documentation/README.md)

Read [](file:///home/user/CiVerLy-forked/documentation/README.md#200-200), lines 200 to 200

I updated documentation/README.md to make the guide more concrete and implementation-oriented. The revised version now names the commonly used modules and classes developers actually import, points to the existing cipher patterns in aes.py, present.py, abc.py, and `skinny.py`, and expands the component guidance with the usual `civerly.component` building blocks.

I also tightened the key-schedule section, added more explicit test and doctest guidance, and expanded the pitfalls list around the issues that most often break modeling: word-vs-bit edge wiring, unsupported component combinations, matrix shape/type mismatches, and AESlike column alignment. I validated the edited content directly in the file; git diff was not useful here because the documentation folder is currently treated as untracked in this worktree.

Made changes.

User: Please add some more details from the documentation in the docs directory.

GitHub Copilot: I’m pulling a few targeted snippets from the docs tree so I can fold in the same terminology and caveats the manual uses, rather than inventing new guidance.

Searched for regex `word_coarseness|AESlike|WordSBoxCipher|SBoxCipher|PermuteLayer_CVL|LinearLayer_CVL` (`**/docs/build/html/_sources/**/*.txt`), 50 results

Searched for regex `word_coarseness|AESlike|WordSBoxCipher|SBoxCipher|PermuteLayer_CVL|LinearLayer_CVL` (`**/docs/source/**/*.rst`), 50 results

Read [](file:///home/user/CiVerLy-forked/docs/source/index.rst)

Read [](file:///home/user/CiVerLy-forked/docs/source/user_manual/index.rst)

The docs confirm there are already dedicated pages for the exact class families and component behaviors, so I’m adding a short “where to read next” section plus a few implementation rules lifted from those pages.

Read [](file:///home/user/CiVerLy-forked/docs/source/user_manual/implement_cipher.rst#45-45), lines 45 to 135

Read [](file:///home/user/CiVerLy-forked/docs/source/user_manual/generate_report.rst#190-190), lines 190 to 235

Read [](file:///home/user/CiVerLy-forked/docs/source/documentation/component.rst#90-90), lines 90 to 151

I’ve got the exact phrasing the manual uses for the model limits and report behavior, so I’m adding a small follow-up section that points readers into the relevant docs pages and mirrors those constraints.

Generating patch (40 lines) in [](file:///home/user/CiVerLy-forked/documentation/README.md)


```

```
The follow-up edits are in place. I’m doing one last narrow read to confirm the added cross-references and constraints read cleanly and don’t duplicate the earlier guidance awkwardly.

Read [](file:///home/user/CiVerLy-forked/documentation/README.md)

Added a docs-oriented follow-up to documentation/README.md: it now points readers to the manual pages in user_manual and documentation, and it folds in a few specific rules from those pages about `AESlike` column alignment, `LinearLayer_CVL` vs `PermuteLayer_CVL`, and how reports differ for rectangular vs flat word states.

The update also keeps the implementation guide aligned with the class hierarchy and component restrictions described in docs/source/user_manual/implement_cipher.rst and the report behavior in docs/source/user_manual/generate_report.rst. I verified the resulting README content directly.

Made changes.
