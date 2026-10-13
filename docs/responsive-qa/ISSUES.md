# Responsive QA Issue Log

Record every finding here before or while fixing it. Keep closed issues so the final audit can distinguish discovered defects from screens that were already ship-ready.

| ID | Screen / state | Device | Issue | Severity | Suggested fix | Status | Evidence |
|---|---|---|---|---|---|---|---|
| RQA-001 | Platform Schools | Tablet portrait | The desktop table activated at 834 px and reduced the school-name column to a few characters per line. | High | Base table/card selection on available list width and require at least 960 px for the table. | Fixed | Commit `b93f9d5`; tablet visual baseline passes. |

## Status values

- Open
- In progress
- Fixed, awaiting verification
- Fixed
- Accepted limitation
- Blocked
