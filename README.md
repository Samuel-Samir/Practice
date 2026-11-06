# Code review practice

Five pull requests, one per exercise. Each PR adds one Swift file to `main`.
Review each PR on GitHub like a real interview:

1. Start a timer: **25 minutes** (E5: 20 minutes). Read the PR description first.
2. Use the **Files changed** tab. Click `+` next to a line to comment.
3. Write each finding as a line comment:
   `REVIEW [P#][Category] what → impact → fix`
   Severity: P0 crash / data race / data loss · P1 wrong behaviour · P2 performance / leak ·
   P3 maintainability · P4 style. Categories: Threading, Concurrency, Memory, Lifetime,
   Crash, Errors, Data, Design.
4. Finish with **Review changes → Comment** and a 3-line summary: the top issues, what is good,
   and whether you'd approve.
5. Don't merge the PRs.

| PR | Branch | Topic | Lines | Time |
|---|---|---|---|---|
| E1 | `e1-swiftui-watchlist` | SwiftUI · View + ViewModel + Service + auto-refresh | 123 | 25 min |
| E2 | `e2-uikit-news-feed` | UIKit · table view, image cache, pagination, delegate | 123 | 25 min |
| E3 | `e3-async-portfolio` | Swift concurrency · actors, tokens, continuations | 142 | 25 min |
| E4 | `e4-gcd-service-layer` | GCD · token refresh, DispatchGroup, barriers, semaphores | 111 | 25 min |
| E5 | `e5-combine-search` | Combine · debounce, flatMap, sink, assign | 91 | 20 min |
