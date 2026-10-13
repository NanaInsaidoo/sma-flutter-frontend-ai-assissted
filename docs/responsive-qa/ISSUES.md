# Responsive QA Issue Log

Record every finding here before or while fixing it. Keep closed issues so the final audit can distinguish discovered defects from screens that were already ship-ready.

| ID | Screen / state | Device | Issue | Severity | Suggested fix | Status | Evidence |
|---|---|---|---|---|---|---|---|
| RQA-001 | Platform Schools | Tablet portrait | The desktop table activated at 834 px and reduced the school-name column to a few characters per line. | High | Base table/card selection on available list width and require at least 960 px for the table. | Fixed | Commit `b93f9d5`; tablet visual baseline passes. |
| RQA-002 | School Calendar | Mobile | The month grid forced its desktop cell widths into the phone viewport and emitted repeated horizontal flex overflows. | High | Keep a readable minimum calendar width inside a local horizontal scroller so the page itself never overflows. | Fixed | Commit `0d63067`; mobile browser check and reviewed screenshot pass. |
| RQA-003 | Staff Management | Mobile | Header actions, summary cards, and the loading panel were too dense for the available width. | Medium | Stack the heading/actions, use a single-column summary below 600 px, reduce compact padding, and use a compact loading state. | Fixed | Commit `0d63067`; mobile browser check and reviewed screenshot pass. |
| RQA-004 | Evaluations & Comments | Mobile | Leadership controls overflowed by 205 px and forced the heading into near letter-by-letter wrapping. | High | Switch the leadership header and actions to a stacked compact layout at phone widths. | Fixed | Commit `0d63067`; mobile browser check and reviewed screenshot pass. |
| RQA-005 | Expenses & Petty Cash | Mobile | The title/action row overflowed by 36 px and made the title effectively unreadable. | High | Stack compact header actions and reduce page padding on narrow viewports. | Fixed | Commit `0d63067`; mobile browser check and reviewed screenshot pass. |
| RQA-006 | Requests & Approvals | Tablet portrait | The dense table layout activated at 834 px and created 66 px of horizontal page overflow. | High | Retain the card/list presentation until at least 1080 px. | Fixed | Commit `0d63067`; tablet browser check passes. |
| RQA-007 | Platform loading shell | Mobile | Two-column metric skeletons were too short for their contents and overflowed by 24 px while data loaded. | Medium | Use a single skeleton column below 600 px with a taller aspect ratio. | Fixed | Commit `0d63067`; mobile catalogue rerun passes. |
| RQA-008 | Platform school detail | Mobile | The school identity row exceeded its card by 29 px. | High | Give the identity group the available width and let its text column expand and wrap. | Fixed | Commit `0d63067`; targeted mobile visual check passes. |
| RQA-009 | Resume onboarding | Mobile | The wizard footer action row exceeded the viewport by 2.9 px. | Medium | Put the step label above a dedicated action row and reduce compact horizontal padding. | Fixed | Commit `0d63067`; targeted mobile visual check passes. |
| RQA-010 | School Calendar event list | Compact mobile | The no-op “Term Only” header control exceeded a 360 px viewport by 0.745 px. | Low | Hide the inactive control below 380 px and preserve the event count/title. | Fixed | Commit `0d63067`; compact-mobile browser check passes. |
| RQA-011 | Platform Account Managers | Mobile | The title wrapped into three visually awkward lines beside the primary action at compact widths. | Medium | Stack the title and full-width primary action below 600 px and use compact page padding. | Fixed | Commit `0d63067`; reviewed compact-mobile baseline and browser comparison pass. |

## Status values

- Open
- In progress
- Fixed, awaiting verification
- Fixed
- Accepted limitation
- Blocked
