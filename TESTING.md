# Testing QuestLens 0.2.1

Start with Debug preview and Extended test range disabled.

- Confirm incoming game data populates your log without opening the tracker automatically. Loading the addon after login may require zoning.
- Use `/ql refresh` repeatedly; it should rebuild local data without requesting a log.
- Open a guide and enable markers, then leave them running for several minutes. QuestLens should send no quest-log requests.
- Zone and confirm newly received data restores the tracker while open guides remain available.
- Open active quest and mission guides, then hover again after their cache fills.
- Check Quest Items across Inventory, Satchel, and other loaded containers.
- Pin from the tracker, item list, and guide panel; reload and confirm pins remain.
- Check completed labels, ignored quests, and restoring an ignored quest.
- Approach a known indexed quest NPC within nine yalms. Test accepting and completing a quest, and an indexed chain prerequisite.
- For a verified repeatable recipe, compare items in main Inventory against the same items in storage.
- Accept a new quest and check the chat notice, Open guide, and Pin actions.
- Use Check quest data updates and confirm an unsuccessful download retains previous data.

For an issue, include the addon version, Ashita version, quest/item/NPC name, zone, expected behavior, actual behavior, and reproduction steps. Screenshots of relevant panels or Debug status are useful. State whether Debug preview or Extended test range was enabled.

Do not upload your settings folder or the entire cache. If a specific cached guide is relevant, review that file before sharing it.

- Test the Debug local NPC wave toggle near a quest NPC. Confirm no new waves during cutscenes/zoning or when disabled. Confirm no outgoing emote packets. Some NPC models may not support the wave animation.

Debug: Wave targeted NPC now attempts one local wave on a targeted humanoid NPC within nine yalms, bypassing quest checks and cooldowns. It temporarily adjusts local yaw toward the player and checks after 4.5 seconds, restoring original yaw only if it still matches our temporary setting. Newer game direction and changed NPC identities are preserved. No packets are sent to the server.

Local Debug greetings randomly choose wave or welcome; the manual button is Greet targeted NPC now.

Debug wave/welcome greetings use a 12-yalm range. Moogle markers remain limited to nine yalms.

Debug: Seconds between emotes ranges from 5 to 300 seconds (default 20, resets on reload). Automatic local greetings randomly choose wave, welcome or huh. The manual greeting button bypasses this delay.

Debug greetings turn once, wait 0.3 seconds, then play the local emote. Facing is not tracked or rewritten during the animation. After a six-second animation window, original rotation is restored only if unchanged by the game. Active greetings cannot be restarted; pending emotes are cancelled on zoning, cutscenes, entity changes, moving out of range or unload.

National mission 2-3 sub-stages use their origin nation guide: Windurst/The Three Kingdoms, San d'Oria/Journey Abroad, and Bastok/The Emissary. Destination suffixes do not switch the nation guide.

Automatic local NPC greetings are enabled by default. The Debug toggle can disable them for the current session; reloading enables them again.
