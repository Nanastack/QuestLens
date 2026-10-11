# Testing QuestLens 0.1.98

Start with Debug preview and Extended test range disabled.

- Confirm incoming game data populates your log without opening the tracker automatically. Loading the addon after login may require zoning.
- Use `/ql refresh` repeatedly; it should rebuild local data without requesting a log.
- Open a guide and enable markers, then leave them running for several minutes. QuestLens should send no quest-log requests.
- Zone and confirm newly received data restores the tracker while open guides remain available.
- Open active quest and mission guides, then hover again after their cache fills.
- Check Quest Items across Inventory, Satchel, and other loaded containers.
- Pin from the tracker, item list, and guide panel; reload and confirm pins remain.
- Check completed labels, ignored quests, and restoring an ignored quest.
- Approach a known indexed quest NPC within five yalms. Test accepting and completing a quest, and an indexed chain prerequisite.
- For a verified repeatable recipe, compare items in main Inventory against the same items in storage.
- Accept a new quest and check the chat notice, Open guide, and Pin actions.
- Use Check quest data updates and confirm an unsuccessful download retains previous data.

For an issue, include the addon version, Ashita version, quest/item/NPC name, zone, expected behavior, actual behavior, and reproduction steps. Screenshots of relevant panels or Debug status are useful. State whether Debug preview or Extended test range was enabled.

Do not upload your settings folder or the entire cache. If a specific cached guide is relevant, review that file before sharing it.
