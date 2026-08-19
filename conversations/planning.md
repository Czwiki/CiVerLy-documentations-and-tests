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

date: 2026-05-25T 13:00:00Z
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

date: 2026-07-10T 13:00:00Z
participants:
- You: Henry
- Assistant: Kilo AI, Kimi 2.6 via Neuralwatt
topic: "Expanding planning"

User:
Please include in the @documentation/README.md , the implementation guide, a subtask. It is nessesary for this tool that the implemented ciphers can be sliced into specific rounds, i.e. from 2-9 or 1-10, to analyze those results. Please elaborate this in the working used in the file.


The user wants me to add a new subtask to the implementation guide in documentation/README.md. The subtask should explain that implemented ciphers need to be sliceable into specific rounds (e.g., rounds 2-9 or 1-10) for analysis purposes. It should match the style and working used in the existing file.

Let me first read the existing file to understand its style and content structure. (I already have the content from the read tool output.)

Looking at the current structure:

Choose the right base class
Pick a file name and public class name
Build the cipher as a DAG
Model-friendly component choices
AES-like indexing and layout
Key schedule strategy
Provide tests and examples
Minimal template
Modeling options and performance notes
Common pitfalls checklist
Where to look for examples
Related docs pages
The new subtask about round slicing should probably go after the DAG construction section (step 3) or around the key schedule section (step 6). Actually, looking at the flow, it makes most sense as a separate numbered step, maybe between 3 and 4, or integrated into 3. But the user said "include ... a subtask", which suggests adding it as a new numbered section.

Looking at the content, after building the cipher as a DAG (step 3), and before model-friendly component choices (step 4), would be a good place. But renumbering everything is risky. Alternatively, I could add it as step 3.5 or insert it and renumber. Since the user explicitly said "subtask", and looking at how these guides usually work, I should insert it as a new numbered step.

Wait, the user said "include in the ... implementation guide, a subtask". This might mean adding a subsection within an existing step, or a new numbered step. Given the importance of round slicing, I think it deserves its own numbered step, perhaps inserted after step 3 "Build the cipher as a DAG" since that's where round construction happens.

Let me draft the content:

4) Sliceable round construction
Design the cipher so that individual rounds or round ranges can be extracted for isolated analysis. This is essential for analyzing truncated differentials, bounding probabilities over specific round intervals, or comparing trails across partial cipher variants.

Guidelines:

Build each round as a named subcipher so that round boundaries are explicit in the DAG. Avoid flattening multiple rounds into a single anonymous subcipher.
If the round function is uniform, construct it once and add it repeatedly with add_subcipher, but ensure each instantiation is wired independently so tools can slice between any two round nodes.
Provide an R parameter (total number of rounds) and document whether the constructor accepts a start/end round range or if slicing is done externally via the cipher graph.
When adding outputs, ensure intermediate round states can be exposed if the analysis tool supports it. At minimum, the final round must terminate with add_output.
If round constants or keys vary per round, store them in a list indexed by round number so that a slice from round r_start to r_end can retrieve the correct constants without recomputing the full schedule.
Round slicing in practice:

Some modeling pipelines expect a contiguous subgraph from round a to round b. Keeping the DAG layered by round makes this extraction straightforward.
If the cipher has an initial or final whitening layer, model these as separate subciphers (or as round 0 and round R+1) so they do not interfere with round-indexed slicing.
Test slicing by extracting a sub-cipher for rounds 2–9 (or 1–10) and verifying that is_valid remains true and that test vectors for the full cipher can be reproduced by composing the slices.
I'll place this after step 3 and renumber subsequent steps.

Now I need to add a new subtask about sliceable round construction. Looking at the current structure, the best place to insert it is after step 3 "Build the cipher as a DAG" and before step 4 "Model-friendly component choices", since round slicing is fundamentally about how the DAG is structured.

I need to renumber steps 4 through 12 to 5 through 13. The edit tool requires exact string matching, so I should do this carefully.

Actually, looking at the pitfalls checklist (step 10), I see there's already a bullet about "Round constants set on the wrong node or not reset per round" which is related but not the same.

Let me draft the new section content:

4) Sliceable round construction
Design the cipher so that individual rounds or round ranges can be extracted for isolated analysis. This is essential for analyzing truncated differentials, bounding probabilities over specific round intervals, or comparing trails across partial cipher variants.

Guidelines:

Build each round as a named subcipher so that round boundaries are explicit in the DAG. Avoid flattening multiple rounds into a single anonymous subcipher.
If the round function is uniform, construct it once and add it repeatedly with add_subcipher, but ensure each instantiation is wired independently so tools can slice between any two round nodes.
Provide an R parameter (total number of rounds) and document whether the constructor accepts a start/end round range or if slicing is done externally via the cipher graph.
When adding outputs, ensure intermediate round states can be exposed if the analysis tool supports it. At minimum, the final round must terminate with add_output.
If round constants or keys vary per round, store them in a list indexed by round number so that a slice from round r_start to r_end can retrieve the correct constants without recomputing the full schedule.
Round slicing in practice:

Some modeling pipelines expect a contiguous subgraph from round a to round b. Keeping the DAG layered by round makes this extraction straightforward.
If the cipher has an initial or final whitening layer, model these as separate subciphers (or as round 0 and round R+1) so they do not interfere with round-indexed slicing.
Test slicing by extracting a sub-cipher for rounds 2–9 (or 1–10) and verifying that is_valid remains true and that test vectors for the full cipher can be reproduced by composing the slices.
I'll insert this after the Pitfall: if you do not call paragraph and before ## 4) Model-friendly component choices. Then I need to renumber all subsequent sections.

Wait, maybe instead of renumbering everything (which is error-prone with exact string matching), I could insert it as section 3.5 or keep it unnumbered? No, the user said "subtask" and the document uses numbered sections. I'll insert it as step 4 and renumber.

Let me do this in two edits:

Insert the new section 4
Renumber sections 4->5, 5->6, etc. through 12->13
Actually, I can do it in one big edit if I replace a large enough block. But that might be error-prone. Let me do it systematically.

First, I'll insert the new content before "## 4) Model-friendly component choices".

Then I'll change all the subsequent section headers.

Let me verify the exact strings:

"## 4) Model-friendly component choices" -> "## 5) Model-friendly component choices"
"## 5) AES-like indexing and layout" -> "## 6) AES-like indexing and layout"
"## 6) Key schedule strategy" -> "## 7) Key schedule strategy"
"## 7) Provide tests and examples" -> "## 8) Provide tests and examples"
"## 8) Minimal template" -> "## 9) Minimal template"
"## 9) Modeling options and performance notes" -> "## 10) Modeling options and performance notes"
"## 10) Common pitfalls checklist" -> "## 11) Common pitfalls checklist"
"## 11) Where to look for examples" -> "## 12) Where to look for examples"
"## 12) Related docs pages" -> "## 13) Related docs pages"
I'll do this with multiple edits.

I see - "## 5) Model-friendly component choices" is already at line 87, which means the first edit in the batch actually succeeded but reported failure? No, looking more carefully: the first replacement in the batch was "## 4) Model-friendly component choices" -> "## 5) Model-friendly component choices". But when I look at the file, it already shows "## 5) Model-friendly component choices" at line 87.

Wait, let's trace back. The first big edit inserted the new section 4 and changed "## 4) Model-friendly component choices" to "## 5) Model-friendly component choices" in the same edit. So when the subsequent edit tried to change "## 4) Model-friendly component choices" to "## 5) Model-friendly component choices", it failed because that string no longer exists. But all the other edits (5->6, 6->7, etc.) succeeded.

Actually, looking at the first edit again: oldString: "Pitfall: if you do not call add_output for all outputs, is_valid remains false and evaluation/modeling fails.\n\n## 4) Model-friendly component choices" newString: "...new section...\n\n## 5) Model-friendly component choices"

Yes! The first edit already changed "## 4)" to "## 5)". So the file state is now correct. All sections have been properly renumbered. Let me verify by checking the end of the file.

Done. I inserted a new section "4) Sliceable round construction" into documentation/README.md and renumbered the subsequent sections accordingly.

The new section covers:

Building each round as a named subcipher so round boundaries are explicit in the DAG.
Wiring round instantiations independently to enable slicing between any two round nodes.
Keeping round constants/keys in a round-indexed list for easy extraction of ranges like 2–9 or 1–10.
Modeling initial/final whitening as separate subciphers so they don't interfere with round-indexed slicing.
Testing slices by verifying is_valid and matching full-cipher test vectors.

date: 2026-08-19T 18:00:00Z
participants:
- You: Henry
- Assistant: Kilo AI, Kimi 2.7 Code
topic: "Planning of Implementation"

User:
It seems like the specifications in @documentation/README.md  are not clear enough on the slicing. Basically, the R argument of the constructor can stay, but it cannot be used togehter with the specification of a start and an end, which must be there together. And please include that the cipher must be slicable, preferably with these start and end parameters. But depending on the structure  cipher, other techniques may be more suitable. As for the key schedule: If possible, it should be included as a class method, but only usable by the constructor or other internal functions. In addition, the specification of a master key in the constructor should be possible. This should mutually exclude the specification of explicit round keys via rks.

User wants me to update the documentation/README.md file to clarify slicing specifications and key schedule requirements. Let me understand the requested changes:

Slicing:
The R argument of the constructor can stay
But it cannot be used together with specifying start and end
start and end must be provided together
Cipher must be sliceable, preferably with these start and end parameters
Depending on cipher structure, other techniques may be more suitable
Key schedule:
Should be included as a class method
Only usable by the constructor or other internal functions
Specification of a master key in the constructor should be possible
This should mutually exclude the specification of explicit round keys via rks
I need to edit the README.md file. I've already read it. Let me make the edits in sections 4 (sliceable round construction) and 7 (key schedule strategy), and possibly update section 3 or 9 if needed.

Let me first update section 4 to clarify the slicing requirements.

I will update the slicing and key-schedule guidelines in documentation/README.md to make those requirements explicit.

Updated documentation/README.md with the clarified slicing and key-schedule rules:

Slicing: R and the pair (start, end) are now required to be mutually exclusive, with both start and end accepted together.
Key schedule: the key schedule should be a class method usable only internally, the constructor should accept master_key, and master_key/rks are mutually exclusive.
Added the corresponding pitfalls to the checklist.
Updated the minimal template to reflect the new constructor signature and mutual-exclusion checks.

