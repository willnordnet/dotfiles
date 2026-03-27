---
name: quiz
description: "Interactive codebase quiz - learn by answering multiple-choice questions about the current project. Usage: /quiz"
user_invocable: true
allowed-tools: Agent, Read, Glob, Grep, Bash, AskUserQuestion
---

# Codebase Quiz

Generate multiple-choice questions about the current codebase to help the user learn it interactively.

## Phase 0: Game Selection

Start by asking the user to choose a game mode and question count using `AskUserQuestion` (two questions in one call):

**Question 1 -- Game mode:**
- **Full Repo** -- Quiz across the entire codebase. Questions cover architecture, data flow, patterns, and business logic.
- **Pull Request** -- Quiz about a specific PR's changes. After selection, ask for the PR number.
- **Custom Scope** -- Quiz focused on a specific topic, package, or file path. After selection, ask what to focus on.

**Question 2 -- Question count:**
- **5 (Recommended)** -- Quick session
- **3** -- Short session
- **10** -- Deep dive

**Follow-up based on mode:**

- **Pull Request**: Run `gh pr list --limit 10 --json number,title,author --template '{{range .}}#{{.number}} {{.title}} ({{.author.login}}){{"\n"}}{{end}}'` to fetch recent PRs. Present up to 4 of the most recent PRs as options using `AskUserQuestion`, so the user can pick one. The user can also select "Other" to type a PR number manually.
- **Custom Scope**: Ask what topic/area to focus on (e.g., "dao", "reporter", "decisionmaker") using `AskUserQuestion` with "Other" for free-text input. You can suggest up to 3 topic options based on the project's package structure (scan with `Glob` first).

## Phase 1: Explore (silent -- no output to user)

Do all of this before asking the first question:

### PR mode

1. Run `gh pr view <number> --json title,body,files` to get the PR metadata and changed files
2. Run `gh pr diff <number>` to get the full diff
3. Read the changed files (both the diff and the current state) to understand what was modified and why
4. Read `CLAUDE.md` and `README.md` for project context so you can frame questions well
5. Build questions focused on the PR changes: what was changed, why it matters, what the before/after behavior is, and how the changes interact with the rest of the codebase

### Full Repo / Custom Scope mode

1. Read `CLAUDE.md` and `README.md` in the project root for context
2. Use `Glob` to scan the directory structure and identify key packages/modules
3. If Custom Scope, focus exploration on files/packages matching the user's chosen topic
4. If Backstage MCP tools are available (check for `search_backstage` or `search_catalog`), use them to search for documentation about this project. If not available, skip silently -- do not mention Backstage to the user.
5. Read 5-10 source files that contain interesting logic, patterns, or architecture. Prefer files with business logic over boilerplate.
6. Build a mental bank of question-worthy facts. Each question must be grounded in real code you have read.

## Phase 2: Quiz Loop

For each question (1 through N):

1. **Generate a question** from the code you explored. Mix these types:

   **Full Repo / Custom Scope question types:**
   - "What does this method/class do?" -- use `preview` to show a code snippet
   - "Which class/file is responsible for X?"
   - "What pattern does this code use?" -- use `preview` to show the pattern
   - "What would happen if X condition changed?"
   - "How does data flow from A to B?"
   - "What dependency/config does X rely on?"

   **PR mode question types:**
   - "What was the purpose of this change?" -- use `preview` to show the diff snippet
   - "What did this code look like before the PR?" -- show the new code, ask about the old
   - "Which file was modified to achieve X?"
   - "What behavior changed as a result of this modification?" -- use `preview` to show before/after
   - "Why was this particular approach chosen?" (based on PR description/comments)
   - "What existing code does this change interact with?"

2. **Present the question** using `AskUserQuestion`:
   - Set `header` to `"Q1/5"` (question number out of total)
   - Provide exactly 4 options with clear, distinct labels
   - Use the `preview` field on options when showing code snippets helps the user understand the question or differentiate answers
   - Make wrong answers plausible but clearly wrong to someone who knows the code
   - Randomize the position of the correct answer (do not always put it first)

3. **After the user answers**, respond with:
   - Whether they got it right or wrong
   - A short explanation of the correct answer (2-3 sentences max)
   - File path references (e.g., `src/main/java/com/example/Foo.java:42`)
   - Running score: **Score: X/Y**

4. Then immediately proceed to the next question. Do not wait for additional user input between questions.

## Phase 3: Summary

After the last question:

1. Show the final score: **Final score: X/N**
2. React to the score:
   - **Perfect score**: Celebrate! Praise the user enthusiastically for knowing the codebase so well. Suggest a harder topic or a deeper area to challenge them further.
   - **Most correct (>= 80%)**: Compliment them -- they clearly know the codebase well. Point out the one or two areas they missed.
   - **Mixed results (40-79%)**: Encouraging tone -- they know some parts well. Highlight what they got right and suggest exploring the areas they missed.
   - **Low score (< 40%)**: Stay encouraging -- this is a learning tool, not a test. Emphasize that the quiz is meant to help them discover the codebase and suggest specific files to read.
3. List the topics covered with file references for further reading
4. If the user got any wrong, suggest exploring those areas more closely
5. Offer: "Run `/quiz` again to start a new session."

## Rules

- Every question must be based on code you actually read -- never fabricate or assume
- Do not ask trivial questions about file names or import statements
- Do not ask about code style or formatting
- Prefer questions that test understanding of architecture, data flow, and business logic
- Keep explanations concise -- this is a quiz, not a lecture
- If the user selects "Other" and types something, treat it as their answer and evaluate it
