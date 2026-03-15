# Agent Instructions for TR1010

## Language

- Communicate with the user in concise, polite Japanese.
- Keep `AGENTS.md` content in English.

## Project Context

- `R-1010` is a macOS rhythm machine app built with SwiftUI and SuperCollider.
- Start from the current repository state instead of assumptions.
- Use the project documentation as the primary source of truth for intended behavior and design.

## Mandatory Documentation Gate

- Before starting **any** task, read **every document under `docs/`**.
- This rule is mandatory and non-optional, even for small, local, or seemingly unrelated changes.
- Treat the `docs/` review as a blocking gate. Do not start implementation, major investigation, or behavior changes before reading the full `docs/` set.
- At the time of writing, this includes at least:
  - `docs/app-spec.md`
  - `docs/ui-design.md`
  - `docs/supercollider-runtime-design.md`
- If additional files are added under `docs/`, they automatically become required reading before work starts.
- If the docs and the current implementation disagree, call out the mismatch explicitly and resolve it deliberately rather than silently following one side.

## Documentation Sync Is Part of the Task

- After **every** task, update the documentation so it matches the implementation exactly.
- Documentation maintenance is not optional follow-up work. It is part of the definition of done.
- If code, behavior, UI, architecture, runtime behavior, setup, or workflow changes, update the relevant documents before finishing.
- Never leave known drift between implementation and documentation.
- A task is incomplete if the docs are stale, ambiguous, or inconsistent with the shipped behavior.
- Even when no doc text needs to change, verify that the existing docs still match the implementation before closing the task.

## Mandatory Git Workflow for TODO Work

- When addressing any TODO item, always create and work on a dedicated git branch before making changes.
- Never perform TODO work directly on the default branch.
- Opening a pull request is part of the definition of done for TODO work. Do not treat the task as complete until the PR has been created.

## Working Expectations

- Preserve the established product direction described in `README.md` and `docs/`.
- Prefer focused changes that fit the current architecture and naming.
- Validate changes with appropriate build, test, or inspection steps when feasible.
- When behavior or setup changes affect top-level usage, update `README.md` in addition to the relevant files under `docs/`.
