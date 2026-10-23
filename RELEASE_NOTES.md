# QuestLens 0.2.18 — testing release

A new testing build with personal guide notes and highlights, clearer item ownership, improved pinning, and more useful quest hints.

## What’s new since the GitHub 0.1.98 release

- **Highlight guide text** in four colors. Keep several highlights or replace your previous selection, with undo and clear controls.
- **Save personal notes** below each guide. Notes and highlights are saved separately for each character and guide, and survive reloads.
- **See owned quest materials** in Related items. Verified requirements get a green ownership check; other owned items get an Owned label. Inventory and loaded storage locations are shown.
- **Pin from Information pages**, including follow-up links and nation-specific quests. Pages that cannot be identified automatically offer Pin as quest.
- **Quest Items shows completion and repeatability** when known. Kazham airship keys are included; owning the pass marks that task complete.
- **Repeatable turn-ins support alternatives**, including one Cornette for Mandragora-Mad. Ready markers count main Inventory only.
- **NPC hints check more quest prerequisites**, including supported quest chains, jobs, and levels. Markers now appear within 9 yalms.
- **Local NPC greetings** can wave, welcome, or huh within 12 yalms. The Debug tab includes an on/off switch and delay setting.
- **Improved guide rendering**, clearer quest notices, and `/ql reload` for easier updating.
- **Better guide matching:** Wild Card opens the quest rather than the Corsair ability; nation-specific Mission 2-3 guides open the correct page. Supported Phoenix summaries without a walkthrough can use BG-Wiki.
- **Clearer retail-guide warnings** explain where BG-Wiki instructions may differ from Phoenix.
- **A simpler README** with the existing in-game screenshot and bundled moogle/item graphics.

## Fixes included

- Highlighting no longer drags the Information window. Turn Highlight text off when you want to move the window or follow a link.
- Follow-up links preserve the correct nation when pinning and reopening a guide.
- Kazham pass completion stops missing-key reminders for that completed task.
- Guides retain cached information when a refresh fails.

## Updating

Extract **questlens-0.2.18.zip** into your Ashita `addons` folder, keeping your existing `settings` and `cache` folders. Run `/ql reload`.

If progress is empty after reloading, zone once. Tracking remains passive: refreshing the display, opening guides, and enabling markers do not request extra quest logs from the game server. Wiki downloads are separate, and NPC greetings stay local.

## Still being tested

Coverage is incomplete. Fame and other acceptance conditions are not fully checked. Ownership checks in guides do not guarantee the full turn-in quantity. BG-Wiki may describe retail features outside Phoenix’s era.

Please report your version, zone, quest/item/NPC, what happened, and how to reproduce it. Screenshots and approximate FPS are helpful for visual or performance issues.
