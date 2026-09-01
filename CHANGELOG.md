# RaidLead Changelog

## v1.9.2

### Fixes
- **"Off" in the healer assignments did nothing.** The button was anchored to the Earth Shield dropdown, which put it underneath the list's scrollbar - the scrollbar swallowed the clicks, so nothing happened and no error appeared. It also stayed stranded at the far edge for non-shamans (e.g. a paladin), where the Earth Shield fields are hidden. The button now sits at a fixed position on the right of each row, clear of the scrollbar.
- **Whispered role replies were ignored after a "Role Check".** The Role Check button only sent the in-addon popup and never switched on the chat/whisper listener, so players who simply whispered a number (e.g. `4`) were silently discarded and kept showing as Unknown. All three entry points - Role Check, Ask All and Ask Missing - now read chat and whisper replies the same way.
- **Role checks time out after 5 minutes instead of 90 seconds.** 90s was too short for players mid-pull; late answers were dropped without a word, which looked exactly like a broken role check. Stop it early any time with the Stop button.

## v1.9.1

### New
- **Ask Missing** (Heal Assign tab). Chases only the players still showing an unknown role, instead of re-polling the whole raid because of two or three stragglers.
  - Players running RaidLead get the **role popup** - sent as a targeted whisper, so nobody else is disturbed.
  - Everyone else gets a **plain whisper** they can answer with a number (1 = Tank, 2 = Heal, 3 = Melee, 4 = Ranged).
  - The button shows how many are missing, and hovering it lists exactly **who** (class-coloured). Offline players and yourself are skipped.
  - Whispers are paced one at a time so a large group can't trip the server's chat flood protection.

### Fixes
- Starting a second role check left the **first** check's 90-second auto-stop timer running, which could cut the new check short.

### Changed
- Roster header buttons renamed to fit alongside the new one: *Request Role Check* -> **Role Check**, *Ask Roles (chat)* -> **Ask All**.

## v1.9.0

### Stability - addon message flood on zone changes (important)
Fixes a bug that could **disconnect the whole raid**, typically right after everyone zoned into an instance ("everyone frozen running on the spot"). Several protections were added:

- **Hard outbound rate limit.** All addon messages now go through a paced queue capped at 5/sec, with separate lanes so a large state sync can never delay a live edit. This is a structural backstop: no future change can flood the channel, whatever triggers it. The pacing is also loading-screen-safe - it can't bank up credit during a load and then fire a burst.
- **Fixed the trigger.** A zone change can briefly make the game report an empty group, which looked like "just joined a group" to every raid member at the same instant and set off a raid-wide sync storm. RaidLead now compares the actual roster to tell a zoning artifact apart from a real group join.
- **Reply storms removed.** Role, version and weapon-enchant requests used to be answered instantly by every addon user at once. Replies are now spread out and de-duplicated per requester.
- **Full-state syncs are queued, not duplicated.** When several people request a sync at once, they're served one at a time instead of each receiving their own full copy, with back-pressure so nothing is silently dropped. Nobody is starved - late requesters simply wait their turn.
- **Jitter is now properly randomised.** The staggering that spreads clients apart relied on a random number generator that was never seeded, so every client could have picked the same delay and stayed in lockstep.
- `/raidlead commstats` shows sent / dropped / queued message counts for diagnosing traffic.

### Fixes
- **Combat tab: the "Recent casts & deaths" log now scrolls.** Use the mouse wheel to page back through the history; the header shows your position (e.g. `1-6 of 23`). History capacity raised from 60 to 250 events, and the scroll position stays anchored when new events arrive mid-fight.
- **A hunter could be suggested as a Battle Rez** in the rez plan (Misdirection casters were being treated as available rezzers). Only druids are considered now.
- **Hovering a row in the combat log could throw an error** instead of showing its tooltip.

## v1.8.1

### Compatibility
- Updated for **TBC Classic 2.5.6** (Interface 20506). 2.5.6 is a service/backend-only patch with no gameplay or API changes, so this is a compatibility bump only - no functional changes.

## v1.8.0

### New Features
- **Combat Report (new "Combat" tab).** A live tracker of the raid's key utility cooldowns, read straight from the combat log (no addon messages, so it can never contribute to channel spam). It tracks:
  - **Druid Innervate & Battle Rez** and **Hunter Misdirection** - a readiness board shows each caster as *Ready* or a live countdown.
  - **Deaths** and **Warlock Soulstones** - folded into a **combat-rez pool** ("how many people can we bring back": ready Battle Rezzes + active Soulstones) and a **per-death rez plan** (who's down and who should rez them).
  - A **timeline** of casts & deaths (who cast what on whom, and when).
  - **Clear Log** resets the pull log but keeps the cooldown timers (they're real-world time - a 20-min Battle Rez legitimately spans pulls); an optional **auto-clear each pull** is available. The logger only runs while you're in a group.
- **Live healer mana in the compact view.** A section showing the overall **average** healer mana plus the **lowest** healer, colour-coded. Hover the panel for the full per-healer list (at your cursor, live-updating, lowest first).
- **Combat Report in the compact view.** A live section with the combat-rez pool and Innervate / Misdirect readiness, plus who's down. Hover the panel to see exactly **who** has each thing ready.
- **Role poll: numbers + one-click for addon users.** The chat role check now asks for a **number** (1 = Tank, 2 = Heal, 3 = Melee, 4 = Ranged) instead of typed words, and players who also run RaidLead get the **in-addon role popup** automatically - one click sets and syncs their role, no typing. Non-addon players still reply in chat.

### Improvements
- **Healer lists are role-aware.** Declared DPS of a healer class (shadow priest, ret paladin, boomkin, elemental/enhancement shaman) are now excluded from healer assignments and the mana readout. Falls back to class when roles aren't set, so run the role poll for an accurate list.
- The tab bar now auto-sizes so every tab fits on screen.

### Bug Fixes
- **Fixed the compact overlay overlapping the full view.** A scan or roster update while in compact mode could render the full grid (and bottom bar) on top of the compact overlay. Compact mode now stays clean through background updates.
- The compact healer-mana hover now appears next to the mouse instead of offset to the side.

## v1.7.1

### Bug Fixes
- **Fixed mass disconnects on instance transitions.** When the raid zoned into or out of an instance, every RaidLead user re-requested a full sync at the same moment, and every user answered everyone else - an N-by-N burst of addon messages that tripped the server's anti-spam and disconnected the raid. RaidLead now only auto-syncs on login / `/reload` (not on every zone change), and only the raid leader / assistants answer a sync request. Live assignment changes still propagate normally.

### New Features
- **Role poll ("Ask Roles in chat").** A role check that works for players WITHOUT the addon: it posts a role question to raid/party chat and reads the replies (chat or whisper), setting each player's role automatically so healer / role assignments have accurate data even when not everyone runs RaidLead. Find it on the Assign tab's Roster header (leader / assist only).
- **Role results now sync.** Roles discovered via the role poll are shared with other RaidLead users, exactly like assignments and settings already sync - but a synced / derived role never overrides a player's own self-declared role.
- **Target Sweep.** For marks too far away for the normal scan (e.g. spread-out council mobs at Maulgar), a new Target Sweep button reads marks by simply targeting or mousing over each mob one at a time - no range limit. On the Maulgar, Karathress, and Magtheridon templates and the Marks tab.

### Also included (from v1.6.2, never previously released here)
- **`/rl` is gone - use `/raidlead` (or `/rlead`).** `/rl` is WoW's built-in alias for `/reload`, so some clients reloaded the UI instead of opening the addon. All in-game help and prompts were updated.
- **Magtheridon announce fix.** The Tanks & Cube Clickers announce previously printed only the header and Main Tank; all channeler lines now send (a `|` character in the line was being dropped by the chat API).

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
