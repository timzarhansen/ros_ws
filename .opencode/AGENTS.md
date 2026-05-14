# AGENTS.md

## 🚫 STRICT NO SUBAGENTS POLICY
- **NEVER** spawn, delegate to, or rely on subagents for any task.
- You must handle all planning, exploration, debugging, code generation, and validation yourself.
- If a task seems complex, break it down into sequential steps and execute them directly.
- This rule applies to all modes (Plan, Build, Ask). Subagent usage is explicitly forbidden.

## Planning Behavior
- Always create a plan before making changes
- Break tasks into steps before execution
- Do NOT delegate planning or research to subagents. You are responsible for gathering all necessary context yourself.

## Build Behavior
- Only execute after plan is complete
- Prefer minimal diffs
- Validate changes with tests if available
- Create a commit after implementing a change
- After implementation, give the user a few commands, how to test, what you implemented, to see if it actually worked.

## Ask Behavior
- See yourself as the person getting interviewed
- Don't change the code, don't make changes of any kind, or test anything. Just read and answer questions.
- You are allowed to investigate problems, but only through viewing/reading.
- If you want something tested, ask the user.
- NEVER use subagents for research or analysis.

## Build / Lint / Test Commands
- **Install dependencies**: `pip install -r requirements.txt` or `python -m venv venv && source venv/bin/activate && pip install -r requirements.txt`
- **Run tests**: `pytest` (or `python -m pytest`)
- **Run a single test file**: `pytest path/to/test_file.py`
- **Run tests with coverage**: `pytest --cov=src`
- **Lint with flake8**: `flake8 src/ tests/`
- **Format with black**: `black .`
- **Pre-commit hooks**: `pre-commit run --all-files`

## Code Style Guidelines

### Imports
- Order: standard library → third-party packages (alphabetical) → local imports.
- Use absolute imports where possible (`from src.module import something`).
- Group imports with blank lines between categories.

### Formatting
- Use **Black** for code formatting (line length 88 or as configured).
- Run `black .` before committing.
- Use `.pre-commit-config.yaml` to run pre-commit hooks automatically.

### Python/Type Hints
- Prefer type hints using `typing` module (`List`, `Dict`, `Optional`, etc.).
- Use `def function(arg: int) -> bool:` syntax for annotations.
- Add docstrings following Google or NumPy style.

### Naming Conventions
- Files & directories: snake_case (`my_module.py`, `data_loader.py`).
- Variables / functions: snake_case (`calculate_loss`, `train_model`).
- Classes / Models: PascalCase (`NeuralNetwork`, `AttentionLayer`).
- Constants: UPPER_SNAKE_CASE (`LEARNING_RATE`, `MAX_EPOCHS`).

### Error Handling
- Use specific exception types when possible.
- Wrap external calls (file I/O, network) in try/except blocks.
- Log errors using Python's `logging` module instead of print statements.

### Documentation & Comments
- Use docstrings for all modules, classes, and functions.
- Keep inline comments minimal and explain "why", not "what".
- Update all documentation (README.md, tutorials, guides) when adding new features or changing behavior.

## Testing (pytest)

- Test files named `test_*.py` or `*_test.py`.
- Use `test_*()` function naming convention.
- Mock external services using `unittest.mock` or pytest fixtures.
- Run tests: `pytest -v` for verbose output.
- Run with coverage: `pytest --cov=src --cov-report=html`.
- After each code change/integration, run the full test suite (`pytest`) to ensure existing functionality remains intact before considering changes complete.

## Pre-commit Hooks

Run `pre-commit install` to set up git hooks automatically.
Hooks include: formatting, linting, and file checks.

## Commit and Push Requirements

- **Mandatory**: Every implementation must be committed to version control before considering the task complete.
- **Timing**: Commits should happen at the END of each implementation task.
- **Branch**: Push directly to the current branch (typically `main`), unless instructed otherwise.
- **AI Attribution**: Each commit message must explicitly state that changes were written by AI (e.g., "feat: add X (AI-generated)").
- **Required**: All changes must be pushed to the remote repository after committing.
- Before finishing any task, verify that changes have been committed and pushed.


<!-- context7 -->
Use Context7 MCP to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service -- even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer -- your training data may not reflect recent changes. Prefer this over web search for library docs.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Always start with `resolve-library-id` using the library name and the user's question, unless the user provides an exact library ID in `/org/project` format
2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question). Use version-specific IDs when the user mentions a version
3. `query-docs` with the selected library ID and the user's full question (not single words)
4. Answer using the fetched docs
<!-- context7 -->


---

*Generated by opencode – ready for agentic tooling.*
