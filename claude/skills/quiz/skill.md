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
- **5** -- Quick session
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
5. Read any test files included in the PR to understand test coverage
6. Read surrounding code not in the PR to understand what edge cases or interactions might be missed
7. Build questions across these categories: factual (what changed), design (why this approach), critique (spot potential issues), and test coverage (what's tested, what's not)

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

   **Full Repo / Custom Scope question types -- mix across categories:**

   *Business logic:*
   - "What business rule does this method enforce?" -- use `preview` to show the logic, ask what it guarantees
   - "What happens when X condition is met?" -- show a conditional branch, test understanding of the domain outcome
   - "Which component owns the decision for X?" -- e.g., pricing, validation, eligibility
   - "What is the business meaning of this state/enum/flag?" -- show code, ask what domain concept it represents
   - "What would break for the end user if this method returned a different value?"

   *Dependencies and integration:*
   - "What external service/system does X depend on?" -- e.g., database, API, message queue, cache
   - "What happens if dependency X is unavailable?" -- test understanding of fallback/retry/error behavior
   - "Which config property controls X behavior?" -- show code that reads config, ask what it configures
   - "What is the order of initialization for these components?" -- test understanding of startup/lifecycle
   - "Which module would be affected if you changed the contract of X?" -- test understanding of coupling

   *Design patterns and architecture:*
   - "What design pattern does this code use?" -- use `preview` to show the pattern, present plausible alternatives
   - "Why is this abstraction structured this way?" -- e.g., why an interface here, why a strategy pattern
   - "Which layer of the architecture does this class belong to?" -- e.g., controller, service, repository, domain
   - "What principle does this separation of concerns follow?" -- e.g., SRP, dependency inversion, hexagonal
   - "How would you extend this to support a new variant of X?" -- test understanding of extension points

   *Data flow and state:*
   - "How does data flow from A to B?" -- trace a request or event through the system
   - "What transformation happens to X between input and output?" -- show entry and exit points
   - "Where is this state persisted and how is it accessed?" -- e.g., DB, cache, in-memory
   - "What triggers this process/job/handler?" -- test understanding of event sources or schedules

   *Error handling and edge cases:*
   - "What happens when this input is null/empty/invalid?" -- use `preview` to show the code path
   - "Which exception is thrown and where is it caught?" -- trace error propagation
   - "What edge case does this guard clause protect against?" -- show defensive code, ask what it prevents
   - "What would happen if this race condition occurred?" -- for concurrent code

   *Testing and observability:*
   - "What is this test actually verifying?" -- use `preview` to show a test, ask what behavior it guards
   - "Which scenario is NOT covered by the existing tests?" -- present a genuinely untested path
   - "What metric/log would you check to verify X is working?" -- test understanding of observability

   **PR mode question types -- mix all four categories:**

   *Factual (what changed):*
   - "What was the purpose of this change?" -- use `preview` to show the diff snippet
   - "What did this code look like before the PR?" -- show the new code, ask about the old
   - "Which file was modified to achieve X?"
   - "What behavior changed as a result of this modification?" -- use `preview` to show before/after

   *Design (why this approach):*
   - "Why was this particular approach chosen over alternatives?" -- present plausible alternative designs as wrong answers
   - "What design pattern or principle does this change follow?" -- use `preview` to show the relevant code
   - "What trade-off does this implementation make?" -- e.g., performance vs. readability, consistency vs. simplicity
   - "How does this change fit into the existing architecture?" -- test understanding of where it sits in the codebase

   *Critique (spot potential issues):*
   - "What edge case is NOT handled by this change?" -- use `preview` to show the code, present real edge cases as options
   - "What could go wrong with this implementation under X condition?" -- e.g., concurrency, null input, large data
   - "Which of these is a valid concern about this change?" -- mix real concerns with non-issues
   - "If you were reviewing this PR, what would you flag?" -- present code smell or risk as one option among distractors

   *Test coverage:*
   - "Which scenario is NOT covered by the tests in this PR?" -- requires reading test files; present a genuinely untested path
   - "What assertion is missing from this test?" -- use `preview` to show the test, ask what it fails to verify
   - "Which of these inputs would expose a bug not caught by the current tests?" -- present boundary values or edge cases
   - "What type of test (unit/integration/e2e) would best cover X behavior introduced in this PR?"

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
- In PR mode, distribute questions across all four categories (factual, design, critique, test coverage). For a 5-question quiz, aim for at least one from each category. Prioritize critique and test coverage over factual -- the user can read the diff themselves
- In Full Repo / Custom Scope mode, distribute questions across categories. Prioritize business logic and design patterns -- these test real understanding. Avoid clustering multiple questions in the same category
