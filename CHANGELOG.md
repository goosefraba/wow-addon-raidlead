# RaidLead Changelog

## v1.7.1

### Bug Fixes
- **Fixed mass disconnects on instance transitions.** When the raid zoned into or out of an instance, every RaidLead user re-requested a full sync at the same moment, and every user answered everyone else - an N-by-N burst of addon messages that tripped the server's anti-spam and disconnected the raid. RaidLead now only auto-syncs on login / `/reload` (not on every zone change), and only the raid leader / assistants answer a sync request. Live assignment changes still propagate normally.

### New Features
- **Target Sweep.** For marks that are too far away for the normal scan (e.g. spread-out council mobs at Maulgar), a new Target Sweep button lets you read marks by simply targeting or mousing over each mob one at a time - no range limit. Available on the Maulgar, Karathress, and Magtheridon templates and the Marks tab.
- **Ask Roles in chat.** A new role check that works for players WITHOUT the addon: it posts a role question to chat and reads the replies (chat or whisper), setting each player's role automatically so healer/role assignments have accurate data. Derived roles sync to other RaidLead users but never override a player's own self-declared role.

## v1.7.0

### New Features
- **Full boss roster on the Boss tab.** Every Karazhan, Gruul's Lair, Magtheridon's Lair, Serpentshrine Cavern, and Tempest Keep boss is now selectable, where before only a handful were. Bosses without an assignment template get a clean placeholder page; simple ones get a generic role-assignment widget automatically.
- **Boss mechanics info button.** A read-only info button on each boss opens a scrollable, formatted breakdown of the fight - phases, key abilities, and practical raid-leader tactics. Built to support multiple tactics per boss (a pill selector appears when a boss has more than one).
- **Verified tactics.** Every boss's mechanics were checked against authoritative TBC guides and corrected, with execution-level tips added (e.g. keep Strawman burning so he can't cast, prioritize Netherspite's green beam, Bloodlust the Curator's Evocation window).
- **Void Reaver** added with a full tank + orb-kiter assignment config.
- **Addon-presence dot in the grid.** A small dot by each player's name shows who is running RaidLead: green = current version, yellow = older version, none = no addon detected.

### Improvements
- **Compact view redesign for faster scanning.** Section headers are now colour-coded with icons (skull for Boss, heal cross for Healers, Bloodlust for Cooldowns, etc.), and your own assignment is highlighted in gold across the Healers, Marks, and Misdirect sections so you can find your job instantly.
- The compact Boss section now always shows a hint when no boss is selected instead of looking blank.

## v1.6.2

### Bug Fixes
- **Magtheridon announce fixed.** Clicking Announce only printed the header and Main Tank — the per-channeler tank/clicker lines were silently dropped because they contained a `|` character, which `SendChatMessage` rejects. The separator was changed and all boss announces now strip `|` defensively, so every line sends.

### Changes
- **`/rl` is no longer used** — it's a built-in WoW alias for `/reload`, which made some clients reload the UI instead of opening the addon. Use **`/raidlead`** or the new short alias **`/rlead`**. All in-game help and prompts were updated.

## v1.6.1

### New Features
- **Weapon oils / stones** — an optional **Weapon** column on the Grid tracks temporary weapon enchants (mana oils, sharpening / weight stones). Because the game only exposes weapon enchants for yourself, each RaidLead player shares their own status with the raid; players without the addon show `?`. Configure it from the Grid tab's gear popup, which now houses **all** column controls (flasks, food, weapon, raid buffs) together, with an info tooltip explaining how it works.

### Bug Fixes
- **Raid history is no longer wiped by `/rl mock`.** Loading mock test data used to clear your entire loot/attendance history first. It's now fully non-destructive: real runs are kept, only previous mock runs are replaced, and mock run IDs are prefixed so they can never overwrite a real run.

### New
- **Automatic history backup + restore.** Before any history wipe (mock load or "Clear History"), your real runs are snapshotted automatically. Recover them with the new `/rl restorehistory` command.

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
