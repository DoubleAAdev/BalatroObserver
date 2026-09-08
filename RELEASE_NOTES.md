# v0.7.5 — Keep the last selected score

Keep the latest selected-hand score visible after playing or deselecting cards, during phase transitions, and while the connection is stale. Another selection replaces the estimate. Retained scores are labeled as the last selected hand; they are estimates, not the actual played score.

New game sessions clear the previous estimate. Unsupported new selections show their explanation instead of an unrelated old score.

Validation: browser checks cover retention after play, deselection, stale and unavailable snapshots, replacement by another hand, and session reset.
