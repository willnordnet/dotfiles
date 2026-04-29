---
name: prompt-review
description: "Analyze prompt history across all repos to detect friction patterns, suggest CLAUDE.md improvements, and track prompting effectiveness. Uses ~/.claude/history.jsonl. Usage: /prompt-review [stats|reset]"
user_invocable: true
argument-hint: "[stats|reset]"
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Prompt Review Skill

Analyze `~/.claude/history.jsonl` to find recurring corrections, friction patterns, and CLAUDE.md gaps across all repos. All analysis is read-only except cursor file updates.

Parse `$ARGUMENTS` to determine the subcommand. If empty, run the default analysis.

## Data Source

`~/.claude/history.jsonl` -- Claude Code's built-in global prompt history. Each line:

```json
{"display": "prompt text", "pastedContents": {}, "timestamp": 1768388330871, "project": "/path/to/repo", "sessionId": "uuid"}
```

## Cursor File

`~/.claude/prompt-review-cursor.json` -- tracks last analyzed position to avoid re-processing.

```json
{"last_analyzed_line": 1942, "last_analyzed_timestamp": "2026-04-29T15:03:16Z", "analysis_count": 1}
```

---

## Subcommand: (default) -- Analyze

Run when `$ARGUMENTS` is empty.

### Step 1: Read cursor and history

1. Read `~/.claude/prompt-review-cursor.json`. If missing, start from line 0 (full analysis).
2. Count total lines in `~/.claude/history.jsonl`:
   ```bash
   wc -l ~/.claude/history.jsonl
   ```
3. If total lines <= cursor's `last_analyzed_line`, report "No new prompts since last analysis on {date}" and stop.
4. Read new lines using offset. For large histories (>500 new lines), process in chunks of 200 lines using the Read tool with offset/limit.

### Step 2: Parse and group

Use bash + jq to extract and group:

```bash
# Get new prompts since cursor (example for offset 1943)
tail -n +{offset} ~/.claude/history.jsonl | jq -s '
  group_by(.project) |
  map({
    project: .[0].project,
    count: length,
    sessions: [.[].sessionId] | unique | length,
    prompts: [.[].display]
  }) |
  sort_by(-.count)'
```

### Step 3: Categorize each prompt

Apply these rules to each prompt's `display` text. A prompt can match multiple categories -- use the first match in priority order:

| Priority | Category | Detection rule |
|----------|----------|---------------|
| 1 | skill | Starts with "/" |
| 2 | correction | Contains: "revert", "undo", "no not", "I meant", "should be", "still not", "fix this", "don't" followed by imperative |
| 3 | confirm | Entire prompt is one of: "yes", "yes.", "continue", "go ahead", "try it", "give it a try" (case-insensitive, <15 chars) |
| 4 | review | Contains: "/review", "/simplify", "review the", "review all" |
| 5 | refactor | Contains: "simplify", "refactor", "extract", "merge", "dedup", "cleanup" |
| 6 | naming | Contains: "suggest better name", "rename", "naming", "better names" |
| 7 | test | Contains: "test", "assert", "missing test", "application test", "add test" |
| 8 | question | Ends with "?", or contains: "does this make sense", "pros and cons", "is it better", "how about" |
| 9 | non-code | Contains: "git", "intellij", "terminal", "connection", "docker", "gcloud" |
| 10 | implement | Default category for anything not matching above |

Use jq or manual inspection to categorize. For large batches, categorize by scanning for keywords.

### Step 4: Detect friction patterns

Friction signals to look for across all new prompts:

**4a. Repeated corrections** -- Group correction-category prompts by semantic theme:
- Test data realism: "use realistic", "should be K not BUY", test value corrections
- Rename scope: "revert the renaming", "only rename what was requested"
- Missing tests: "don't forget", "should be updated", "is there a test"
- Log level: "should be log.error", "use error not warn"
- Blast radius: "skip that for now", "let's not", scoping down responses

Count occurrences per theme. Flag themes with 2+ occurrences.

**4b. Friction phrases** -- Count prompts containing:
- "revert", "undo", "still not working", "I meant", "no not that"
These indicate Claude misunderstood the intent.

**4c. Confirmation ratio** -- Calculate:
```
confirmation_ratio = count(confirm category) / total_prompts
```
If >20%, note that Claude may be asking too many questions.

**4d. Cross-repo detection** -- For each friction theme, check if it appears in prompts from 2+ distinct `project` paths. If yes, it's a candidate for root CLAUDE.md. If only 1 project, it's project-specific.

### Step 5: CLAUDE.md gap detection

1. Read `~/.claude/CLAUDE.md` (root)
2. Read `{current_project}/CLAUDE.md` if it exists (use cwd)
3. For each friction theme with 2+ occurrences:
   - Search both CLAUDE.md files for keywords related to the theme
   - If a matching rule exists: report as "Covered" with the rule location
   - If no matching rule: generate a concrete suggestion with:
     - Which file (root vs project)
     - Which section to add it under
     - The suggested rule text
     - Example prompts that motivated it

### Step 6: Generate prompt tips

Analyze the prompt corpus for technique patterns:

- **Confirmation ratio**: If high, suggest combining confirmations with follow-up instructions
- **File reference usage**: Calculate % of prompts using `@file` or `@file#Lxx` syntax. If <50%, suggest using it more.
- **Average prompt length**: If very short (<20 chars avg), note that more context upfront reduces iterations
- **Session length distribution**: If many 10+ prompt sessions, suggest front-loading more context

### Step 7: Output report

Format output as markdown with these sections:

```markdown
## Prompt Review ({start_date} to {end_date})

### Stats
- {N} new prompts, {S} sessions, {R} repos
- Top repos: {repo1} ({count}), {repo2} ({count})
- Category breakdown: implement ({n}), review ({n}), refactor ({n}), correction ({n}), confirm ({n}), question ({n})

### Friction Points ({count} found)
{For each theme with 2+ occurrences:}
1. **{Theme name}** ({count}x, {scope: cross-repo|project-only})
   Examples: "{prompt1}", "{prompt2}"
   {If covered:} Status: Covered in {root|project} CLAUDE.md -- {quote the rule}
   {If gap:} Suggested rule for {root|project} CLAUDE.md ({section}):
   > {rule text}

### Rule Effectiveness
{For each CLAUDE.md rule that maps to a friction theme:}
- "{rule summary}" -- {correction_count} corrections {before|after} rule was added

### Prompt Tips
- {tip based on pattern analysis}

### Improvement Plan

#### Root CLAUDE.md (`~/.claude/CLAUDE.md`)
{For each cross-repo suggestion, grouped by target section:}

**{Section name}** (add/update):
> {rule text}
Motivation: {theme name} ({count}x across {repo1}, {repo2})

#### Project CLAUDE.md (`{project}/CLAUDE.md`)
{For each project-specific suggestion, grouped by target section:}

**{Section name}** (add/update):
> {rule text}
Motivation: {theme name} ({count}x)

#### Prompt Habits
{Prioritized list of prompting improvements:}
1. {Most impactful habit change with concrete example}
2. {Second most impactful}

#### Already Working
{Rules that show zero corrections since added -- positive reinforcement:}
- "{rule}" -- no corrections in {N} sessions
```

### Step 8: Save report

Save the full analysis report to `~/.claude/prompt-review-reports/{YYYY-MM-DD}.md`. Create the directory if needed. If a report for today already exists, append a suffix: `{YYYY-MM-DD}-2.md`.

This lets the user track improvement over time and compare friction points across reviews.

### Step 9: Update cursor

Write to `~/.claude/prompt-review-cursor.json`:

```json
{
  "last_analyzed_line": {new_total_lines - 1},
  "last_analyzed_timestamp": "{current_iso_timestamp}",
  "analysis_count": {previous + 1}
}
```

---

## Subcommand: stats

Run when `$ARGUMENTS` is "stats".

Quick read-only overview. Use bash + jq for all computation:

```bash
# Total lines and date range
echo "Total prompts: $(wc -l < ~/.claude/history.jsonl)"
# First and last timestamp
jq -r '.timestamp' ~/.claude/history.jsonl | sort -n | head -1 | awk '{printf "%d", $1/1000}' | xargs date -r
jq -r '.timestamp' ~/.claude/history.jsonl | sort -n | tail -1 | awk '{printf "%d", $1/1000}' | xargs date -r
# Per-repo breakdown
jq -r '.project' ~/.claude/history.jsonl | sort | uniq -c | sort -rn | head -10
# Sessions
jq -r '.sessionId' ~/.claude/history.jsonl | sort -u | wc -l
# Cursor status
cat ~/.claude/prompt-review-cursor.json 2>/dev/null || echo "No cursor (full analysis pending)"
```

```bash
# Past reports
ls -1 ~/.claude/prompt-review-reports/ 2>/dev/null || echo "No reports yet"
```

Output as a compact table.

---

## Subcommand: reset

Run when `$ARGUMENTS` is "reset".

1. Delete `~/.claude/prompt-review-cursor.json` if it exists
2. Confirm: "Cursor reset. Next `/prompt-review` will analyze all {N} prompts."

---

## Usage Help

If `$ARGUMENTS` is "help" or unrecognized, display:

```
/prompt-review          Analyze new prompts since last run, detect friction, suggest CLAUDE.md rules
/prompt-review stats    Quick overview: prompt counts, repos, date range
/prompt-review reset    Clear cursor to force full re-analysis
```

---

## Important Guidelines

- This skill is READ-ONLY. Never modify CLAUDE.md files, source code, or any file except `~/.claude/prompt-review-cursor.json`.
- When reading large history files, use offset/limit to avoid overwhelming context.
- Focus on actionable patterns -- skip one-off corrections that don't repeat.
- Be specific in suggestions: name the file, section, and exact rule text.
- When reporting friction points, always include 2-3 example prompts so the user can verify the pattern.
- Don't report patterns with fewer than 2 occurrences -- they might be one-offs.
- Distinguish between corrections (user fixing Claude's behavior) and refinements (user iterating on their own design). Only corrections indicate CLAUDE.md gaps.