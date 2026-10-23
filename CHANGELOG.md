# Patch notes

## 0.2.18 - 2026-10-23

Prepared a refreshed GitHub testing release with player-facing documentation and a summary of changes since 0.1.98. See [release notes](RELEASE_NOTES.md) for highlights, item ownership, pinning, NPC hints, guide fixes, and update instructions.

## 0.2.17 - 2026-10-22

Added requirement ownership checks and neutral ownership/location labels to Related items in quest guides.


## 0.2.16 - 2026-10-18

Fixed guide text selection moving the Information window by blocking parent and child window movement during highlighting.


## 0.2.15 - 2026-10-18

Added saved guide text highlights with four colors, keep/replace controls, undo/clear, and personal notes per character and guide.


## 0.2.14 - 2026-10-17

Corrected Wild Card BG-Wiki quest mapping and added missing-walkthrough fallback across known quests and missions. Cached Phoenix summaries can now refresh automatically.


## 0.2.13 - 2026-10-16

A refreshed testing build with clearer item tracking, improved pinning, and better NPC hints.

## Highlights

- **Pin from Information pages**, including follow-up links, nation-specific quests, and quests outside the bundled catalog. Pins reopen the correct nation guide.
- **Quest Items shows completion and repeatability** when known. Non-repeatable and unknown-repeatability labels stay hidden.
- **Kazham airship keys now appear in Quest Items.** Owning the Kazham pass marks the task complete and stops missing-key warnings.
- **Repeatable turn-ins support alternatives.** Mandragora-Mad recognizes any one of its five valid items, including a single Cornette in main Inventory. Ready turn-ins use a **green trade hand** instead of a completion checkmark.
- **NPC markers check more prerequisites:** indexed job/level conditions cover 54 quests, including Ceraulian's Dragoon artifact quest. Fame and hidden server conditions remain unverified.
- **Guide rendering does less work each frame**, with cached text measurements and combined text drawing. Actual FPS improvement depends on the scene and setup.
- **Clearer chat notices and BG-Wiki warnings**, plus `/ql reload` for convenient addon reloads.
- **Local NPC greetings:** random wave, welcome, or huh within 12 yalms, with turn-before-emote timing and facing restoration. The Debug tab provides the toggle, delay control, and manual preview buttons.

## Updating

Extract **questlens-0.2.13.zip** into your Ashita `addons` folder, keeping your existing `settings` and `cache` folders. Run `/ql reload`.

If the quest list is empty after reloading, zone once. `/ql refresh` only rebuilds data already available locally. Tracking remains passive, and local NPC greetings send nothing to the game server.

This is a testing release. Quest/item coverage is incomplete, and retail BG-Wiki guidance can differ from Phoenix. Please include your addon version, zone, and reproduction steps when reporting a problem.
