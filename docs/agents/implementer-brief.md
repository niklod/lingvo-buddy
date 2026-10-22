# Ticket flow with parallel agents

A lead agent splits the work into GitHub issues (tickets) and gives each ticket to one implementer sub-agent in its own git worktree. This repo has no PRs: the lead merges ticket branches into `main` and pushes `main`.

## Lead

1. Start each implementer with `isolation: "worktree"` and the brief below, with `<N>` filled in. Start tickets in parallel only when they touch different areas.
2. Merge finished branches one at a time, and only when the report names the real-app check of every visible change (step 6 of the brief): `git merge --no-ff ticket-<N>-<slug> -m "feat: <ticket title> (closes #<N>)"`. The `closes #N` closes the issue on push. Commit the merge, then `git push origin main`: the pre-push hook runs `make check`.
3. Tell later implementers what an earlier merge changed in shared code, in their brief.

Parallel tickets collide in predictable places:
- **User-DB migrations.** Each ticket adds the next `vN-...` entry in `UserSchema.migrations`. On merge, keep the order of what is already on `main` and renumber the later ticket's migration. A shipped migration never changes.
- **`App/Sources/AppDelegate.swift`** and `SnapshotRegistry.swift` take lines from most UI tickets. Expect conflicts there.
- **CSV backup.** A new column in `word_progress` or `my_words` also needs `WordBackupColumn` and `UserDatabase+Backup.swift`.

## Brief for an implementer

> You implement ticket #`<N>` of niklod/lingvo-buddy in your own git worktree.
>
> Read first: the spec (`gh issue view 1 -R niklod/lingvo-buddy`), your ticket (`gh issue view <N> -R niklod/lingvo-buddy`), `GLOSSARY.md` and the `docs/agents/` files that `CLAUDE.md` points to for your work. The design is `design/src/*.html` (source of truth for layout, colours and sizes) and `design/screenshots/*.png`. UI labels are English: translate the Russian labels of the design.
>
> 1. Check that your HEAD is based on local `main`: `git merge-base --is-ancestor main HEAD`. If it is not, run `git reset --hard main`. Create the branch `ticket-<N>-<slug>`.
> 2. Call the Skill tool with `tdd`. Build test-first where the behaviour is testable, through the public `Tutor` interface (spec "Testing Decisions").
> 3. Keep the scope to your ticket. Swift 6 strict concurrency; LingvoCore has no AppKit.
> 4. Commit locally. Titles are Conventional Commits, title only, plus the Co-Authored-By trailer. Do not push and do not open a PR: the lead merges.
> 5. Run the app only as `docs/agents/running-the-app.md` says: your own `--user-db`, and stop only your own process.
> 6. For a change the learner sees or clicks, drive the real app: `make run ARGS="--user-db <your-name> --skip-onboarding --open <view>"`, do each new action once, and check its effect (the panel on screen, the stored value, the opened page). Snapshots check layout only. The step is done when your report says what you did and what you saw.
> 7. Before you report: commit, then `make check` passes (it needs a clean tree). Then `git merge main`, resolve conflicts, commit and run `make check` again.
> 8. If you learned a trap or a convention that a later agent needs and the code cannot show, add it to the matching `docs/agents/` file (or `GLOSSARY.md` for a domain term) in your branch.
> 9. Report in under 15 lines: branch, head SHA, the real-app check, what is done, what is not done, what later tickets must know. Do not paste code.
