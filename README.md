# QuestLens

<img width="2622" height="1133" alt="Screenshot 2026-10-10 104303" src="https://github.com/user-attachments/assets/51364c2a-7f88-4583-8250-cae76b065f37" />

Quest and mission tracking for **Phoenix XI**, using **Ashita v4 on 64-bit Windows**.

**Testing release: 0.2.1** · By **Zarianna (100% vibe coded)**

## Install

1. Extract the release ZIP into your Ashita `addons` folder. The main file must be `addons/questlens/questlens.lua`.
2. In game, run `/addon load questlens`.
3. Run `/ql` to open the tracker. QuestLens reads quest and mission updates that the game sends naturally. If loaded after those packets have arrived, it may need a zone change before the log is available.

For a GitHub checkout, place this repository's contents directly in `addons/questlens`.
The addon starts with its windows closed. Add `/addon load questlens` to your Ashita startup script if desired.

Requires Ashita's bundled Lua libraries and Windows PowerShell. No Python or FancyChat installation is needed. The bundled curl helper handles wiki and source downloads with verified HTTPS. The addon folder must be writable: caches and per-character settings are created on first use. Internet access is needed for uncached guides and data updates.

## Features

- Active, pinned, unaccepted, completed, and ignored quests; active and completed missions.
- Phoenix Wiki guides, with labeled BG-Wiki fallbacks when a Phoenix guide is unavailable.
- In-addon item previews, linked item icons, related pages, maps, and guide navigation.
- Quest Items: indexed quest requirements for items in Inventory and supported loaded storage. Reward-only associations are excluded.
- Per-character saved pins, ignored quests, and tracking settings.
- Optional nearby NPC moogle markers, including repeatable markers and Inventory-only ready-to-trade checks for verified recipes.
- New quest chat notices and an internal notification with Open guide and Pin buttons.
- Background caching of active guides, item-associated guides, and owned-item information.
- Manual Phoenix source-data updates; automatic weekly source-change checks.

Normal information links stay inside QuestLens. The explicitly labeled Phoenix wiki, BG-Wiki, and FFXIclopedia buttons open your external browser.

## Commands

| Command | Action |
| --- | --- |
| `/ql` | Toggle the tracker |
| `/ql show` / `/ql hide` | Show or hide panels |
| `/ql reload` | Reload QuestLens |
| `/ql refresh` | Rebuild the display from locally received quest/mission data |
| `/ql inventory` | Open Quest Items |
| `/ql lookup <name>` | Open an item, quest, or zone guide |
| `/ql received` | Reopen recent new-quest notifications |
| `/ql updates` | Download and validate supported Phoenix quest-data updates |
| `/ql help` | Show commands |

Quest tracking is passive: login, markers, guides, and manual refresh never request a quest log from the game server. Incoming `0x056` packets update quest and mission state, including acceptance and completion. Zoning clears the previous zone snapshot and waits for incoming data. `/ql refresh` and **Refresh display (local)** rebuild the display without fetching missing game data. Notifications and marker changes appear when the game supplies the corresponding update.

Wiki downloads are separate. Fresh Phoenix guides are reused for 24 hours; BG fallback guides are rechecked after seven days. Refresh guide forces a new request. First-time caching is gradual, and opened or hovered pages take priority.

## Testing limits

**Quest, guide, NPC, and item-use coverage is incomplete.** No indexed use does not mean an item has no quest use.

Content groups are limited to the supported era through **Treasures of Aht Urhgan**. Wings of the Goddess and later expansion groups are disabled. Regional game logs can still contain later additions; this is not a complete audit of every quest's Phoenix availability.

The bundled marker index contains 307 starter references. Verified chain prerequisites are enforced where indexed. Fame, hidden server variables, cooldowns, and other acceptance conditions are not fully checked. A marker is a guide hint, not proof that the NPC will offer a quest. Debug preview deliberately bypasses quest checks; disable it when testing normal behavior. Normal markers use a nine-yalm range and hide during cutscenes and zoning; the extended-range test option is separate.

Green repeatable world markers require a verified recipe and the full quantities in **main Inventory**, not Satchel or other storage. Requirement checks in guides use listed quantities when available; otherwise they indicate item ownership only. Unloaded storage cannot be assumed empty.

The updater refreshes supported quest identities and recognized script patterns. New identities or unsupported formats may still require an addon release. BG fallback guides describe retail FFXI and may not match the Phoenix server era, including fast travel, quest requirements and rewards.

See [TESTING.md](TESTING.md) for useful checks and issue details. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution.

Debug includes an enabled-by-default local NPC greeting preview. This synthesizes an incoming motion-only emote for the client using Ashita AddIncomingPacket; it does not send packets or emote commands to the game server. Eligible humanoid quest NPCs within nine yalms can wave occasionally. Model support and facing behavior require in-game testing. Toggle off stops new waves; any animation already started can finish. Preview resets on reload.

Debug: Wave targeted NPC now attempts one local wave on a targeted humanoid NPC within nine yalms, bypassing quest checks and cooldowns. It temporarily adjusts local yaw toward the player and checks after 4.5 seconds, restoring original yaw only if it still matches our temporary setting. Newer game direction and changed NPC identities are preserved. No packets are sent to the server.

Local Debug greetings randomly choose wave or welcome; the manual button is Greet targeted NPC now.

Debug wave/welcome greetings use a 12-yalm range. Moogle markers remain limited to nine yalms.

Debug: Seconds between emotes ranges from 5 to 300 seconds (default 20, resets on reload). Automatic local greetings randomly choose wave, welcome or huh. The manual greeting button bypasses this delay.

Debug greetings turn once, wait 0.3 seconds, then play the local emote. Facing is not tracked or rewritten during the animation. After a six-second animation window, original rotation is restored only if unchanged by the game. Active greetings cannot be restarted; pending emotes are cancelled on zoning, cutscenes, entity changes, moving out of range or unload.

National mission 2-3 sub-stages use their origin nation guide: Windurst/The Three Kingdoms, San d'Oria/Journey Abroad, and Bastok/The Emissary. Destination suffixes do not switch the nation guide.

Automatic local NPC greetings are enabled by default. The Debug toggle can disable them for the current session; reloading enables them again.
