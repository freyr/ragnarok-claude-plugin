---
name: kb-write
description: Use when the person explicitly asks to write a note into the knowledge base of their vaults through the checked write path — "kb-write this", "add this to the knowledge base", "save this as a vault note and check for duplicates", "record this fact in the vault" — or when a replay runner calls it in fixture mode with a mirror path. Runs admission, classification, collision search, a verdict for each candidate, one resolution for each collision, validation, one diff for approval, a backed-up write and a post-write check. Not for searching or reading notes (use the ragnarok tools), not for converting the labels of many existing notes, not for tuning config.toml (ragnarok-adapt), and not for project plans, specs or scratch notes that the person writes without the write path.
---

# Write a note into the knowledge base

This skill takes one piece of text (a fact, a procedure, a decision, a profile) and puts it into the vaults
without a duplicate, a hidden contradiction or a broken link. ragnarok gives only mechanical tools. You are the
classifier and the judge. The mechanical results are hard gates. Your verdicts are advice that the person sees
in one diff before anything is written.

## Requirements

- The ragnarok MCP server with the tools `find_collisions`, `validate`, `find_entities` and `vault_rules`.
  They need a `ragnarok-mcp` version that has them. If the tools are absent, stop and say so: name the missing
  tools and say that the server must run a `ragnarok-mcp` version with the write-path tools. Do not write a
  note by hand as a fallback.
- Load the tools in one call before step 1:
  `ToolSearch` with `select:mcp__plugin_ragnarok_ragnarok__vault_rules,mcp__plugin_ragnarok_ragnarok__find_entities,mcp__plugin_ragnarok_ragnarok__find_collisions,mcp__plugin_ragnarok_ragnarok__validate,mcp__plugin_ragnarok_ragnarok__open_note,mcp__plugin_ragnarok_ragnarok__search`.
- The helper script `${CLAUDE_PLUGIN_ROOT}/scripts/kb-write.sh` (bench check, backup, restore).

Below, `vault_rules` means `mcp__plugin_ragnarok_ragnarok__vault_rules`, and so on for each tool.

## Hard rules

- Write only on an explicit request of the person, or in fixture mode. Never start this skill on your own.
- Write nothing before step 7 has an explicit "yes" from the person (fixture mode: before step 6 passes).
- A private note is never read, quoted or changed. A `PrivateNotAllowed` error of any tool stops the run. A
  target path that matches a `private_patterns` entry of `vault_rules` is never written (the step 2 gate). Never
  set `allow_private` and never pass `allow_private=true`. Do not get around a refusal with Read, Grep or a shell
  command.
- Never invent an entity. A `subject` or an `owner` is an entity note that `find_entities` lists. A new entity
  needs its own note, which the person approves as part of the same diff.
- Never move, rename, delete or overwrite an existing note. The resolution actions keep each path, and a new
  note never takes the path of an existing file.
- Back up each file before you change it (step 8). On a failed post-write check, restore all backups (step 9).
- Keep the person's data out of this plugin: no note text, path or name goes into a tracked file of a repo.

## Terms

| Term | Meaning |
| --- | --- |
| Note key | `<vault>/<path in the vault>`, as in `search` results, for example `Work/Clients/acme.md`. Tools take and return note keys. |
| Note file | The file of a note key. Real mode: `<vault folder>/<path in the vault>`, where the vault folder is `vault_paths.<vault>` of the `config.toml` of the ragnarok home, else `<root>/<vault>`. Fixture mode: `<mirror>/<folder>/<path in the vault>`, where `folder` is the `folder` of that vault in `vault_rules`. |
| Draft | The full Markdown text of a note that you intend to write (frontmatter and body), with its intended note key. |
| Change set | All drafts of one run: the new notes and the changed existing notes. |
| Identity key | `type`, the primary subject (the first `subject` item, resolved to its entity note) and `task` when the note has one. A note with no primary subject has no identity key. |
| Same identity | Two notes with equal identity keys. A note with no identity key has the same identity as no other note. |

## The frontmatter model

Write only these keys, the existing keys `project`, `area`, `type`, `status` and `description`, and the keys
that `vault_rules` lists in `write.known_keys`. Keep the other keys that an existing note already has. On an
entity note, `kind`, `aliases` and `facts` are allowed too.

| Key | Values | Rule |
| --- | --- | --- |
| `class` | `state`, `proposal`, `record` | Always write it. |
| `validity` | state: `current`, `superseded`; proposal: `open`, `accepted`, `rejected`, `superseded`; record: none | Always write it for a state or a proposal. Never write it for a record. |
| `as_of` | ISO date `YYYY-MM-DD` | The date when the claims of the note were true. |
| `subject` | list of wiki-links to entity notes | Only entities that exist. The first item is the primary subject. |
| `task` | short text | Optional. The task of a how-to or a procedure; part of the identity key. |
| `supersedes` | list of wiki-links | On the new note, when it replaces another note. |
| `superseded_by` | wiki-link | On the old note. A state or proposal also gets `validity: superseded`. |
| `owner` | wiki-link to an entity of kind person or team | Optional. |

Write a wiki-link value as a quoted string, for example `subject: ["[[Clients/acme]]"]`. A wiki-link names the
path in the vault without `.md` (the note key without the vault name and without `.md`): the note key
`Work/Clients/acme.md` is the link `[[Clients/acme]]`. Obsidian reads a link relative to the vault root, so a
link with the vault name does not resolve there.

The class of a type, when the person or the vault gives no other class:

| `type` | `class` |
| --- | --- |
| `research`, `meeting`, `log`, `review`, `decision` | `record` |
| `plan`, `brainstorm`, `spec` | `proposal` |
| `guide`, `reference`, `summary`, `drivers` | `state` |
| any other type | decide from the content: does it describe how something is now (state), what someone intends (proposal), or what happened (record)? |

**Bodies.** The body of a state note states the current truth only. It never says "previously", "formerly",
"was changed", "superseded" or "the old value was". History is data in frontmatter (`supersedes`,
`superseded_by`, `as_of`) and in records. A record stays true about its date; do not rewrite it with new facts.

## Modes

| Mode | Started by | Step 7 | Writes |
| --- | --- | --- | --- |
| real | the person, with the text to write | the person approves one diff | the vault files of the change set |
| fixture | a replay runner, with `mirror=<absolute path>` | skipped | only files under the mirror |

**Fixture mode input.** `mirror` (required): the folder that the MCP server indexes as its vault root, under a
bench home. `draft` (required): the candidate text, or the absolute path of a file outside the mirror that holds
it. `path` (optional): the intended note key. Before step 1:

1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/kb-write.sh" bench "<mirror>"`. Exit 1 means no ancestor folder of
   the mirror holds `.ragnarok-bench`: refuse fixture mode, write nothing, and give the final record with
   `"outcome": "refused"`.
2. Prove that the server indexes the mirror. Call `vault_rules`. For each vault, find one existing note file
   under `<mirror>/<folder>` that matches no `private_patterns` entry (for example with
   `find "<mirror>/<folder>" -name '*.md' -not -path '*/.*'`), and call `validate(paths=["<absolute path of that
   file>"])`. The server maps an absolute path to a note key only when the path is under one of its own vault
   folders, and it gives an error for a path that is not in its index. Any tool error (not the issues of that
   note) means that the server does not index the mirror: refuse the same way.
3. The fixture server must be the only ragnarok MCP server in the session; the runner provides it. Its tools can
   have another prefix than `mcp__plugin_ragnarok_ragnarok__`: use the tools of that one server.
4. The mirror must be a real copy: no symbolic links and no hard links to files outside it. The helper script
   refuses such a file in step 8.
5. Never ask a question. Where real mode asks the person, fixture mode uses the default that each step names.
6. Use the Write and Edit tools only on paths under the mirror. The draft file is input; never change it.

## The steps

Each step has an input, the tool calls, an output and a gate to the next step. Keep a run log in your context:
the candidates with their reasons, the verdicts with quotes, the actions and each `validate` result. The final
report and the final record come from it.

### Step 1: admission

- **Input.** The candidate text. `vault_rules` (call it now, if fixture mode did not).
- **Do.** Ask the questions in this order. The first "yes" decides.

  | # | Question | If yes |
  | --- | --- | --- |
  | A1 | Is the value in a system of record? Compare with `write.systems_of_record` of `vault_rules` (each has `data`, `system`, `skill`), and with the usual ones (CRM, HR system, ticket status, Git). | `route` to that system or skill. No note holds the value. A note can explain what the value means and link to the source; that part can continue as its own candidate. |
  | A2 | Does it change faster than a person reads it again (a deploy state, a ticket status)? | `route` to the ticket or the project summary. |
  | A3 | Is it an instruction to an agent about how to do its work, with a trigger? | `route` to a skill. The domain facts that the skill reads can continue as their own candidate. |
  | A4 | Is it unverified: a hypothesis, a proposal, a decision that nobody applied? | `route` to its project folder, as a proposal note (`class: proposal`, `validity: open`). |
  | A5 | Does it fail the reuse test? All three must be true to pass: an audience (more than one person, or one person on more than one occasion, needs it); a counterfactual (without it, someone repeats a mistake or a large search); an owner (one person or team accepts it). | `reject`, with the reason. |
  | — | No "yes" | `admit`. |

- **Output.** `admit`, `route` (with the destination) or `reject`, and a reason that a person can read.
- **Gate.**
  - `admit`: go to step 2.
  - `route` to a project folder: in real mode, ask the person to confirm, then go to step 2 with that folder as
    the target. Fixture mode: go to step 2.
  - `route` to a system of record, a ticket or a skill: stop. Tell the person where the value belongs and which
    skill reads it. Nothing is written.
  - `reject`: stop with the reason. Nothing is written.
  - A5 needs the author: propose the audience and the owner, and ask the person. Fixture mode: treat A5 as
    passed unless the text is plainly transient (a reminder, a one-time status).

### Step 2: classify

- **Input.** The admitted text, `vault_rules`, and `find_entities` (with `name=` for each candidate subject, and
  `kind="person"` or `kind="team"` for an owner).
- **Do.** Decide each item and write the draft frontmatter:

  | Item | How |
  | --- | --- |
  | `type` | A type that the vault already uses for this kind of note (look at the `type` of similar `search` results). |
  | `class`, `validity` | The class table above. A new state is `current`; a new proposal is `open` (or `accepted` when the text says it was applied). |
  | `as_of` | The date that the text gives for its claims, else today. |
  | `subject` | The entity notes that `find_entities` returns, most specific first. If an entity that the note is about has no note: real mode, propose a new entity note (`type: entity`, `kind`, `aliases`) as an extra draft of the change set; fixture mode, leave it out. With no fitting entity, leave out `subject`: the note then has no identity key. |
  | `task` | Only for a how-to or a procedure: the task in a few words. |
  | `owner` | Only when the text or the person names a person or team that has an entity note. |
  | `project`, `area`, `status`, `description` | As the vault uses them; `description` is one sentence that stands alone. |
  | Target note key | From the area and project rules and the archive folder of `vault_rules`, next to similar notes. In fixture mode a given `path` is the target. |

- **Output.** A draft: frontmatter and body.
- **Gate.** Check the target key of each new note of the change set:
  - It must not match a `private_patterns` entry. Match like Python `fnmatchcase` on the note key; `*` also
    matches `/`.
  - It must not be under the archive folder.
  - Its note file must not exist. Check the file (`test -e "<note file>"`), not only the index.

  On a failed check: real mode, choose another folder or name and ask the person; fixture mode, refuse (write
  nothing, `outcome: refused`). Then go to step 3.

### Step 3: collision candidates

- **Input.** The draft and its target key.
- **Do.** Call `find_collisions(draft=<full draft text>, path=<target key>)`. Leave `allow_private` unset.
- **Output.** `candidates`: at most 10, each with `path`, `title`, `type`, `status`, `class`, `validity`, `as_of`,
  `subject`, `superseded_by`, `reasons` (`identity`, `search`, `links_out`, `links_to_supersedes`), `rank` and
  `distance` (the raw cosine distance of its best chunk; lower is closer). Also `warnings`.
- **Gate.** A tool error stops the run (a `PrivateNotAllowed` error is the private refusal). No candidates: go to
  step 5 with no collision. Else go to step 4. A distance only selects candidates; it never decides a verdict.

### Step 4: a verdict for each candidate

- **Input.** Each candidate.
- **Do.** Call `open_note(path=<candidate>)` (for a long note, open the outline, then the sections that matter
  with `heading=`). Compare the identity keys: the candidate's `type` and `subject`, and the `task` of its
  `frontmatter`. Give exactly one verdict:

  | Verdict | Definition |
  | --- | --- |
  | `same` | The draft holds no information that the candidate does not hold. An equal body is always `same`. |
  | `extends` | New information about the same subject and type; the candidate is the note where it belongs. |
  | `supersedes` | The draft replaces the content of the candidate (newer facts about the same thing). |
  | `overlaps` | A part of the draft is already in the candidate, and the rest is new. |
  | `contradicts` | A claim of the draft conflicts with a claim of the candidate (see below). |
  | `unrelated` | No shared information. |

  Each verdict except `unrelated` has a quote: the exact sentence or table row of the candidate that supports
  it. For `contradicts`, quote the claim of each note.

  **The contradiction check.** A contradiction is a property of two claims, not of two notes.
  1. Split the draft and the candidate into claims: subject, attribute, value, scope (environment, tenant,
     version), time (`as_of` or a stated period) and source.
  2. Compare only claims with the same subject and attribute.
  3. These pairs are not a contradiction: the periods do not overlap; the scopes differ; one claim is a record
     (what was decided or measured on a date) and the other a state (how it is now).
  4. A pair that is left is `contradicts`. A verdict of `contradicts` is a flag for the person, not a decision.

  **A proposal candidate.** For a candidate with `class: proposal` and `validity: open`, also decide: does the
  draft show that the proposal is now done (the draft is a state that realizes it)? Or does the text say that the
  proposal was dropped? Note it with the verdict; step 5 uses it.

- **Output.** A table: candidate, reasons, distance, verdict, quote, identity key equal (yes or no).
- **Gate.** Any `same`: go to step 5, which stops the run. Else go to step 5.

### Step 5: one resolution for each collision

- **Input.** The verdicts.
- **Do.** Choose one action for each candidate with this table:

  | Verdict | Action |
  | --- | --- |
  | `same` | Stop. Show the existing note. Nothing is written. |
  | `extends`, the candidate is a state or a proposal | Merge: rewrite the existing note in place with the new content. Its path and links stay. |
  | `extends`, the candidate is a record | Link: write the draft as a new note with a link to the record. A record is not rewritten with new facts. |
  | `supersedes`, same identity key, the candidate is a state | Merge: rewrite the existing state note in place, with a new `as_of`. |
  | `supersedes`, other identity key, or the candidate is not a state | Supersede: write the new note with `supersedes`. The old note gets `validity: superseded` and `superseded_by`. |
  | `contradicts` | Resolve by the rules R1 to R4 below, in order. When one rule decides, supersede or merge. When no rule decides, stop and ask the person; nothing is written until the person decides. |
  | `overlaps` | Keep both. Replace the copied part of one note with a link to the other. |
  | a proposal that a state now realizes | Accept: the proposal gets `validity: accepted`, and a link to the state note. |
  | a proposal that the person dropped | Abandon: the proposal gets `validity: rejected`, with the reason. |
  | `unrelated` | No action. |

  The rules for `contradicts`, in order:

  | # | Rule | Result |
  | --- | --- | --- |
  | R1 | One value comes from a system of record (`write.systems_of_record`, or a CRM, HR system, Git, cost data). | The system of record wins. The note does not copy the value; it names or links the source. If the listed skill can read the value, use it to check which claim is true (fixture mode: do not call a system-of-record skill; R1 decides only from the notes). Then merge or supersede. |
  | R2 | Scope or time explains the difference. | Add the scope or the period to the claims. No conflict remains: judge the pair again (usually `extends`, `overlaps` or `unrelated`). |
  | R3 | The new claim has newer evidence of equal or higher authority. | The new claim wins: merge into a state with the same identity key, else supersede. |
  | R4 | The owner of the subject decides. | Real mode: ask the person whether they own the subject and which claim is true, then merge or supersede. Fixture mode: R4 does not apply. |
  | — | No rule decides | Stop and ask the person. Nothing is written until the person decides. Fixture mode: stop with action `ask`. |

  **Combine the actions of all candidates** in this order:
  1. Any `same`: stop. Nothing is written.
  2. Any `contradicts` that no rule decides: stop with action `ask`. Nothing is written.
  3. With a merge target: the merge target absorbs the draft, and the draft is not written as a new note. Each
     candidate with a supersede action gets `superseded_by` the merge target, and the merge target lists each of
     them in its `supersedes`.
  4. Without a merge target: the draft is written as a new note. Its `supersedes` lists every candidate with a
     supersede action, and each of them gets `superseded_by` the new note.
  5. Accept, abandon and link actions are added to either branch. In branch 3, "the new note" of these actions is
     the merge target.

  Details of the actions:
  - **Merge** has one target. With more than one candidate for a merge, take the one with the same identity key,
    else ask the person (fixture mode: the first in the `find_collisions` order). Judge the other merge candidates
    again as `supersedes` or `overlaps`. Keep the target's path, existing keys and links. Rewrite its body so
    that it holds the old and the new facts, current truth only. For a state, set `as_of` to the new date.
  - **Supersede**: the replacing note lists each old note in `supersedes`, for example
    `supersedes: ["[[Notes/old]]"]`. The old note gets `superseded_by: "[[Notes/new]]"`, and, for a state or a
    proposal, `validity: superseded`. A record gets only `superseded_by`. The body of the old note does not
    change.
  - **Link** (the overlaps action, and `extends` into a record). Keep the shared part in the note whose identity
    key owns it (usually the state note about that subject). In the other note, replace the copied part with one
    sentence and a wiki-link to the owner. The two notes are a pair; the existing one is the target.
  - **Accept** sets `validity: accepted` on the proposal and adds a wiki-link to the state note in its body.
    **Abandon** sets `validity: rejected` and adds the reason in one sentence.
  - **Labels of a changed note.** Each existing note that the run changes must pass checks 1 and 2 of `validate`
    after the change. If it has no `class`, add it (from the class table, else from the content); if it is a
    state or a proposal with no `validity`, add it.
  - With no candidate, or only `unrelated` candidates, write the draft as a new note (action `new`).
  - Real mode: the person can always change an action in step 7.

- **Output.** The change set: the full new text of each changed or new note, with the action and the reason for
  each.
- **Gate.** A `same` action, or a `contradicts` that no rule decides: stop and report (fixture mode: the final
  record). Else go to step 6.

### Step 6: validation

- **Input.** Each draft of the change set, with its note key.
- **Do.**
  1. For each existing note in the change set, call `validate(paths=[<key>, ...])` on the current files. These
     are the baseline issues: issues that a note had before this run.
  2. For each draft, call `validate(draft=<full text>, path=<note key>)`. A draft at the key of an existing note
     takes the place of that note in the check.
- **Output.** For each draft: `error_count`, `warning_count` and `issues` (each with `path`, `check`,
  `severity`, `kind`, `message`).
- **Gate (hard).** Each draft must have no error of check 1 or check 2 (the keys and values of the model, the
  required `class` and `validity`). Pass when each other error of each draft is one of these:
  - a baseline error that the run cannot fix in that note: the same note already had it (same `kind` and
    `message`), and it is in a part that the run does not change (for example a broken link in a body that the
    run does not rewrite);
  - a pending target: a `missing-target` or `broken-link` error whose target is a new note of the same change set
    (for example `superseded_by` on the old note before the new note exists).

  Any other error is a fail: go back to step 2 or 5, correct the draft, and validate again. After three failed
  rounds, stop and report the errors; nothing is written. For an `unknown-key` warning, remove the key unless the
  person wants it (fixture mode: remove it). A `double-identity` error is never a pending error: change the
  action to a merge into the other current note.

### Step 7: approval (real mode only)

- **Input.** The change set and the run log.
- **Do.** Show one message with:
  1. the admission result and the reason;
  2. the candidate table of step 4 (path, reasons, distance, verdict, quote);
  3. each action with its reason;
  4. one unified diff of all files of the change set. Write each draft to a new staging folder
     (`mktemp -d "${TMPDIR:-/tmp}/kb-write-drafts.XXXXXX"`) and run `diff -u <note file> <draft file>`. Use
     `diff -u /dev/null <draft file>` only for a new note whose note file does not exist (check it again now);
  5. the `validate` result, with the warnings and the accepted baseline and pending errors.

  Then ask: write all of it, change something, or stop.
- **Output.** The answer of the person.
- **Gate.** Only an explicit yes goes to step 8. A change goes back to the step that it affects (an action:
  step 5; a label, or the folder or name of a new note: step 2), then step 6 and step 7 again. Only the path of a
  new note can change; an existing note keeps its path. The rewrite of inbound links after a path change is out of
  scope. No, or no answer: stop; nothing is written.

### Step 8: backup and write

- **Input.** The approved change set (fixture mode: the change set that passed step 6).
- **Do.**
  1. Make a run id: `date -u +%Y%m%dT%H%M%SZ`.
  2. Make a new backup folder for this run, outside every vault and outside the mirror. `mktemp -d` makes it
     unique, so that a restore never touches the files of another run:
     - real mode: `mkdir -p "<home>/data/kb-write-backups"`, then
       `mktemp -d "<home>/data/kb-write-backups/<run id>.XXXXXX"`, where the home is the output of
       `bash "${CLAUDE_PLUGIN_ROOT}/scripts/ragnarok-home.sh"`;
     - fixture mode: `mktemp -d "${TMPDIR:-/tmp}/kb-write.XXXXXX"`. No backup or staging file is written in the
       bench home.
  3. Collect the note files of the change set. Back them all up in one call before the first write:

     ```bash
     bash "${CLAUDE_PLUGIN_ROOT}/scripts/kb-write.sh" save "<backup folder>" "<note file>" ...
     ```

     In fixture mode, set `KB_WRITE_WITHIN="<mirror>"` for that call: the script refuses a file outside the
     mirror and a file with more than one hard link. The script always refuses a symbolic link and a path with a
     newline or a tab. A non-zero exit stops the run before any write. The script prints `saved<TAB><path>` for
     an existing file and `created<TAB><path>` for a missing file. If it prints `saved` for a new note, the file
     exists: stop before any write.
  4. Write each file with the Write or Edit tool: the new notes first, then the changed notes.
- **Output.** The written files, the backup folder and its `manifest.tsv`.
- **Gate.** A failed write: restore at once (the restore command of step 9), then report with
  `outcome: restored`. Else go to step 9.

### Step 9: post-write check

- **Input.** The note keys of all files that step 8 wrote or changed.
- **Do.**
  1. Call `validate(paths=[<each key>])`. Each tool call first scans the vaults and indexes up to 20 changed notes,
     newest first, so this call usually sees the new files. Call `validate` again (each call indexes up to 20 more
     notes), at most three more times, while one of these is true:
     - its `warnings` say that the index is not current;
     - it fails with a `FileNotFoundError` for a key that step 8 wrote (the scan deferred that note).

     If it still fails after the retries, the check fails. Real mode: after the restore, tell the person to run
     `ragnarok index` with the same install and the same `RAGNAROK_HOME` as the server, and then to run the skill
     again. Do not run another `ragnarok-mcp` version for this.
  2. Compare with the baseline errors of step 6. Pending-target errors must be gone now.
- **Output.** The `validate` result of the changed notes.
- **Gate (hard).** Pass: no error of check 1 or check 2, and no other error except a baseline error that step 6
  accepted. Fail: restore all files:

  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/scripts/kb-write.sh" restore "<backup folder>"
  ```

  In fixture mode, set `KB_WRITE_WITHIN="<mirror>"` for the restore too: the script then refuses a manifest with
  a path outside the mirror before it changes anything. The script copies each saved file back, deletes each
  created file and removes each folder that the write made.
  Then call `validate(paths=[...])` on the restored existing notes, so that the index scans the restore, and
  report the errors that caused the restore.

## The final report

Real mode: tell the person the outcome in a few lines: the action for each collision, the files written, the
backup folder, and the `validate` result. Keep the backup folder; the person deletes it later.

Both modes end with the final record: one line that starts with `KB-WRITE-RECORD`, a space and one JSON object on
the same line, as the last line of the answer. A replay runner reads the last such line.

```text
KB-WRITE-RECORD {"record":"kb-write/1","mode":"fixture","run_id":"20260101T120000Z","mirror":"/abs/mirror","admission":"admit","action":"supersede","targets":["Work/Notes/old.md"],"new_notes":["Work/Notes/new.md"],"changed_files":["Work/Notes/new.md","Work/Notes/old.md"],"collisions":[{"path":"Work/Notes/old.md","verdict":"supersedes","action":"supersede"}],"validate":{"error_count":0,"warning_count":0},"written":true,"outcome":"written","backup":"/abs/backup"}
```

| Field | Value |
| --- | --- |
| `record` | Always `kb-write/1`. |
| `mode` | `real` or `fixture`. |
| `run_id` | The run id of step 8, or `null` when nothing was written. |
| `mirror` | The mirror path in fixture mode, else `null`. |
| `admission` | `admit`, `route` or `reject`; `null` when the run was refused before step 1. |
| `action` | The decided action of the run, also when nothing was written (check `written` and `outcome`). `refused`, `route` and `reject` apply only when the run stopped before step 5: `route` only for a route to a system of record, a ticket or a skill; a route to a project folder takes its action from step 5. Else the main action of step 5, the first that applies of `same`, `ask`, `merge`, `supersede`, `accept`, `abandon`, `link`, `new`. `link` is the overlaps action (and `extends` into a record). `ask` is a contradiction that no rule decides. |
| `targets` | The note keys of all existing notes that the main action applies to: the notes that hold the same content (`same`), the merge target and each note that gets `superseded_by` the merge target (`merge`), all old notes (`supersede`), the proposals (`accept`, `abandon`), the other note of each pair (`link`). Empty for `new`. |
| `new_notes` | The note keys of the notes that the run created. |
| `changed_files` | The note keys of all files written or created, sorted (the paths of the backup manifest, as note keys). Empty when nothing was written or after a restore. |
| `collisions` | Each candidate with its `path`, `verdict` and `action` (`merge`, `supersede`, `link`, `accept`, `abandon`, `same`, `ask` or `none`). |
| `validate` | `error_count` and `warning_count` of step 9, or of the last step 6 round when nothing was written. |
| `written` | `true` when the run wrote files and kept them (`outcome` is `written`), else `false`. A scorer checks it together with `action` and `targets`. |
| `outcome` | `written`, `nothing-written`, `restored` (a write in step 8 or the check of step 9 failed, and the backup was restored), `refused` (fixture mode refused, a target that fails the step 2 gate in fixture mode, a private refusal, or a missing tool) or `failed` (an error after which the restore also failed; report it). |
| `backup` | The backup folder, or `null`. |
