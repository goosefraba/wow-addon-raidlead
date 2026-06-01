# RaidLead Changelog

## v1.6.0

### New Features
- **Chat voting** — polls can now include people *without* the addon. A new "Let everyone vote in chat" option posts the question and numbered options to raid/party chat; anyone can vote by typing the number, the option name, or `y`/`n` on a Yes/No poll. Votes merge live into the same tally.
- **Silent / whisper voting** — players can whisper their choice to the poll starter instead of voting in the open, for honest "keep going or call it?" polls. Chat and whisper votes are tagged in the results.
- **No double-counting** — votes are keyed by player, and an explicit addon-popup vote always wins over a typed one, so clicking *and* typing never counts twice.
- **Manual poll control** — polls now stay open until you click **End Poll** (no more vanishing after 30s). Once closed, the button becomes **Restart** to re-run the same question with a fresh tally. A new "Auto-close after 30s" option is available at poll creation for quick checks.
- **Live per-voter list** — the Poll Results window shows who voted for what as it happens, names class-colored, with chat/whisper tags.
- **Clickable poll history** — click any past poll in the History view to see its result bars plus the full per-voter breakdown.
- **Raid-buff picker** — a new gear button on the Grid tab opens a chooser to select exactly which raid buffs you track. Unchecked buffs are hidden from the grid and never flagged as missing (great for situational buffs like Salvation, Shadow Protection, or Spirit). Columns recompact automatically.

### Improvements
- Poll result bars now stretch cleanly to the window edges and scale to the window width.
- Result bars are rendered by a single shared component, so the live results and history detail always look identical.
- Poll instructions posted to chat now explain both number-voting and the whisper option.

### Bug Fixes
- Fixed the End Poll button appearing to do nothing — the poll was closing internally but the window kept re-rendering as "open".
- Fixed attendance tracking always reporting zero (the per-player attendance map was iterated incorrectly).
- Throttled full-state sync so large assignment syncs no longer fire a burst of messages in a single frame.
- Hardened several paths against missing data (raid-buff records, database bootstrap, slash command before the UI loads).

### Under the Hood
- Reduced duplication across modules with shared helpers (database bootstrap, class colors, class lookup, whisper builders) — no behavior change.
