# QuestLens

<img width="100%" alt="QuestLens in game" src="https://github.com/user-attachments/assets/710f6431-d367-4a44-92b9-da6c689cc059" />

Quest and mission tracking for **Phoenix XI**, with guides, item uses, and nearby NPC hints.

**Version 0.2.13 — testing release**  
By **Zarianna (100% vibe coded)**

## Install or update

1. Download **questlens-0.2.13.zip** from [Releases](https://github.com/Nanastack/QuestLens/releases).
2. Extract it into your Ashita `addons` folder. You should have `addons/questlens/questlens.lua`.
3. Run `/addon load questlens`. If updating an already loaded copy, run `/ql reload` instead.
4. Run `/ql` to open QuestLens.

When updating, keep your existing **settings** and **cache** folders. Pins and settings are saved per character.

Requires **Ashita v4 on 64-bit Windows**. Keep the included folders together; the download helpers are already bundled. An internet connection is needed to fetch guides.

**Empty quest list?** Zone once after loading or reloading. QuestLens uses updates the game sends naturally; `/ql refresh` only rebuilds the local display.

## Getting started

- **Open a guide:** click a quest or mission. Hover linked items for previews; click them for more information.
- **Pin a quest:** click the empty box beside it, including in its Information page. Pins stay saved between sessions.
- **Find item uses:** open **Quest Items**, choose a container, then select an item. Related quests show **Complete** and confirmed **Repeatable** labels when that information is available.
- **Manage your list:** use Pinned, All, Quest, Mission, Unaccepted, Completed, or Ignored. The circle/slash ignores a quest; the green arrow restores it.

**Pin as quest** is available when a guide cannot be matched automatically. These pins can be saved, but automatic completion may not be available.

## NPC markers

Nearby quest NPCs can display a moogle with:

| Symbol | Meaning |
| --- | --- |
| Yellow question mark | An indexed quest you have not accepted or completed |
| Yellow repeat arrows | A repeatable quest; turn-in items are missing or not yet verified |
| Green hand offering a coin | A verified repeatable turn-in is ready |

Ready-to-trade checks use **main Inventory only**, not other storage. Where alternatives are supported, any one valid turn-in counts.

Markers appear within **9 yalms**. Optional local NPC greetings work within **12 yalms**; turn them off in **Debug** if preferred. **Quest markers** has its own toggle. Debug test buttons can bypass the normal quest filters.

## Commands

| Command | What it does |
| --- | --- |
| `/ql` | Open or close the tracker |
| `/ql inventory` | Open Quest Items |
| `/ql reload` | Reload the addon |
| `/ql refresh` | Rebuild the display from available character data |
| `/ql lookup <name>` | Look up a quest, item, or zone |
| `/ql received` | Reopen recent new-quest notices |
| `/ql updates` | Check and update supported quest reference data |
| `/ql help` | Show available commands |

## Before you rely on a guide

**Coverage is incomplete.** Supported content is aimed at the Phoenix era through **Treasures of Aht Urhgan**. A missing item match does not mean the item has no use. Markers check known prerequisites, but fame and other server conditions may still prevent acceptance.

Phoenix Wiki is preferred. **BG-Wiki fallback guides describe retail FFXI**: fast travel, requirements, rewards, and other details may differ from Phoenix.

Quest tracking does not request extra logs from the game server. Wiki downloads are separate; NPC greetings are local effects and are not sent to the server.

See [patch notes](CHANGELOG.md), [troubleshooting and feedback](TESTING.md), and [third-party notices](THIRD_PARTY_NOTICES.md).
