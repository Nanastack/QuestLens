# QuestLens

Quest and mission tracking for **Phoenix XI**, using **Ashita v4 on 64-bit Windows**.

**Testing release: 0.1.95** · By **Zarianna (100% vibe coded)**

## Install

1. Extract the release ZIP into your Ashita `addons` folder. The main file must be `addons/questlens/questlens.lua`.
2. In game, run `/addon load questlens`.
3. Run `/ql` to open the tracker. The quest log refreshes automatically after character login; `/ql refresh` requests it manually.

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
| `/ql refresh` | Request the current quest/mission log |
| `/ql inventory` | Open Quest Items |
| `/ql lookup <name>` | Open an item, quest, or zone guide |
| `/ql received` | Reopen recent new-quest notifications |
| `/ql updates` | Download and validate supported Phoenix quest-data updates |
| `/ql help` | Show commands |

When quest markers are enabled or a guide is open, the game log refreshes every minute. This is separate from wiki downloads. Fresh Phoenix guides are reused for 24 hours; BG fallback guides are rechecked after seven days. Refresh guide forces a new request. First-time caching is gradual, and opened or hovered pages take priority.

## Testing limits

**Quest, guide, NPC, and item-use coverage is incomplete.** No indexed use does not mean an item has no quest use.

Content groups are limited to the supported era through **Treasures of Aht Urhgan**. Wings of the Goddess and later expansion groups are disabled. Regional game logs can still contain later additions; this is not a complete audit of every quest's Phoenix availability.

The bundled marker index contains 147 starter references. Verified chain prerequisites are enforced where indexed. Fame, hidden server variables, cooldowns, and other acceptance conditions are not fully checked. A marker is a guide hint, not proof that the NPC will offer a quest. Debug preview deliberately bypasses quest checks; disable it when testing normal behavior. Normal markers use a five-yalm range and hide during cutscenes and zoning; the extended-range test option is separate.

Green repeatable world markers require a verified recipe and the full quantities in **main Inventory**, not Satchel or other storage. Requirement checks in guides use listed quantities when available; otherwise they indicate item ownership only. Unloaded storage cannot be assumed empty.

The updater refreshes supported quest identities and recognized script patterns. New identities or unsupported formats may still require an addon release. BG fallback instructions and rewards may differ from Phoenix.

See [TESTING.md](TESTING.md) for useful checks and issue details. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution.
