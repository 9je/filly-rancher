# Pacing

Written by `tools/pacing.sh`: a fresh save played by the human-paced bot (`game/scenes/test/human_bot.gd`), headless at a fixed 60 fps, so the clock below is play time. Every first-time unlock, discovery and story beat is stamped as it happens (`game/systems/novelty.gd`).

**Rules** (MISSION.md): no gap over 8:00 in the first hour, none over 15:00 after it, and the first clue by 15:00.

**Verdict: FAIL**
- early gap of 14:56 after "Pip asks you to find a lost foal" (limit 8:00)

Run: 60:16 of play, 48 new things, first clue at 5:33. bot seed 7, catches 24, deliveries 18, blooms 0, bits 2656

## Timeline

| Time | Kind | What |
|---|---|---|
| 0:02 | story | Letter: Your mailbox is installed |
| 1:55 | story | Marigold: marigold arrival |
| 2:16 | story | Tumble: tumble meets |
| 2:32 | story | Bramble: bramble first sale |
| 2:44 | tool | Got Fennel's old Treat Pouch |
| 3:04 | story | Fennel: fennel first pen |
| 3:29 | story | Pip: pip first letter |
| 3:45 | mechanic | Built the first pen |
| 3:45 | upgrade | Built a Paddock |
| 3:59 | story | Fennel: fennel bloom hint |
| 4:00 | mechanic | Tossed a treat from the Treat Pouch |
| 4:07 | pony | First pegasus Drifter |
| 4:07 | mechanic | First catch with the Scoop |
| 4:13 | pony | First unicorn Drifter |
| 4:17 | pony | Caught Twilight Sparkle |
| 4:44 | npc | Bramble's new stock: Steward's Monocle |
| 4:50 | story | Marigold: marigold depot |
| 5:09 | mechanic | First delivery to the Depot |
| 5:09 | story | Letter: Thank you for your first shipment |
| 5:20 | story | Marigold: marigold first collection |
| 5:20 | npc | Bramble's new stock: Pony Whistle |
| 5:33 | clue | Tumble: tumble depot |
| 7:18 | area | Bramble's market stall |
| 7:23 | mechanic | Bought feed at the market |
| 8:01 | story | Letter: Employee Appreciation Survey |
| 8:12 | npc | Bramble's new stock: Depot Cart |
| 8:18 | clue | Marigold: marigold vivid |
| 8:24 | npc | Bramble's new stock: Gem Chute |
| 8:34 | clue | Bramble: bramble dye |
| 8:53 | clue | Fennel: fennel postcards |
| 9:15 | clue | Pip: pip cloud line |
| 9:15 | event | A sun shower brings pegasus Drifters down |
| 11:52 | clue | Letter: Your quarterly performance summary |
| 13:00 | event | Tumble spots Vinyl Scratch out in the grass |
| 17:01 | event | The Palace on the Strip opens |
| 17:26 | area | First visit: The Strip |
| 17:49 | mechanic | First game at the casino |
| 18:20 | pony | First earth Drifter |
| 22:00 | event | Tumble spots Scootaloo out in the grass |
| 23:24 | clue | A postcard from a delivered pony, in hoofwriting that is not hers |
| 27:23 | pony | Caught Scootaloo |
| 30:01 | event | Race day at the track |
| 31:01 | event | Tumble spots Soarin out in the grass |
| 31:17 | pony | Caught Soarin |
| 35:05 | npc | Pip asks you to find a lost foal |
| 50:01 | event | Tumble spots Octavia out in the grass |
| 57:23 | event | An Escape Artist hopped the Paddock fence |
| 60:16 | pony | Caught Octavia |

## Gaps

| From | To | Gap | Limit | | Between |
|---|---|---|---|---|---|
| 0:00 | 0:02 | 0:02 | 8:00 | ok | start of play, then Letter: Your mailbox is installed |
| 0:02 | 1:55 | 1:53 | 8:00 | ok | Letter: Your mailbox is installed, then Marigold: marigold arrival |
| 1:55 | 2:16 | 0:21 | 8:00 | ok | Marigold: marigold arrival, then Tumble: tumble meets |
| 2:16 | 2:32 | 0:16 | 8:00 | ok | Tumble: tumble meets, then Bramble: bramble first sale |
| 2:32 | 2:44 | 0:13 | 8:00 | ok | Bramble: bramble first sale, then Got Fennel's old Treat Pouch |
| 2:44 | 3:04 | 0:20 | 8:00 | ok | Got Fennel's old Treat Pouch, then Fennel: fennel first pen |
| 3:04 | 3:29 | 0:24 | 8:00 | ok | Fennel: fennel first pen, then Pip: pip first letter |
| 3:29 | 3:45 | 0:16 | 8:00 | ok | Pip: pip first letter, then Built the first pen |
| 3:45 | 3:45 | 0:00 | 8:00 | ok | Built the first pen, then Built a Paddock |
| 3:45 | 3:59 | 0:15 | 8:00 | ok | Built a Paddock, then Fennel: fennel bloom hint |
| 3:59 | 4:00 | 0:01 | 8:00 | ok | Fennel: fennel bloom hint, then Tossed a treat from the Treat Pouch |
| 4:00 | 4:07 | 0:07 | 8:00 | ok | Tossed a treat from the Treat Pouch, then First pegasus Drifter |
| 4:07 | 4:07 | 0:00 | 8:00 | ok | First pegasus Drifter, then First catch with the Scoop |
| 4:07 | 4:13 | 0:06 | 8:00 | ok | First catch with the Scoop, then First unicorn Drifter |
| 4:13 | 4:17 | 0:04 | 8:00 | ok | First unicorn Drifter, then Caught Twilight Sparkle |
| 4:17 | 4:44 | 0:27 | 8:00 | ok | Caught Twilight Sparkle, then Bramble's new stock: Steward's Monocle |
| 4:44 | 4:50 | 0:06 | 8:00 | ok | Bramble's new stock: Steward's Monocle, then Marigold: marigold depot |
| 4:50 | 5:09 | 0:19 | 8:00 | ok | Marigold: marigold depot, then First delivery to the Depot |
| 5:09 | 5:09 | 0:00 | 8:00 | ok | First delivery to the Depot, then Letter: Thank you for your first shipment |
| 5:09 | 5:20 | 0:11 | 8:00 | ok | Letter: Thank you for your first shipment, then Marigold: marigold first collection |
| 5:20 | 5:20 | 0:00 | 8:00 | ok | Marigold: marigold first collection, then Bramble's new stock: Pony Whistle |
| 5:20 | 5:33 | 0:13 | 8:00 | ok | Bramble's new stock: Pony Whistle, then Tumble: tumble depot |
| 5:33 | 7:18 | 1:46 | 8:00 | ok | Tumble: tumble depot, then Bramble's market stall |
| 7:18 | 7:23 | 0:04 | 8:00 | ok | Bramble's market stall, then Bought feed at the market |
| 7:23 | 8:01 | 0:38 | 8:00 | ok | Bought feed at the market, then Letter: Employee Appreciation Survey |
| 8:01 | 8:12 | 0:11 | 8:00 | ok | Letter: Employee Appreciation Survey, then Bramble's new stock: Depot Cart |
| 8:12 | 8:18 | 0:05 | 8:00 | ok | Bramble's new stock: Depot Cart, then Marigold: marigold vivid |
| 8:18 | 8:24 | 0:06 | 8:00 | ok | Marigold: marigold vivid, then Bramble's new stock: Gem Chute |
| 8:24 | 8:34 | 0:10 | 8:00 | ok | Bramble's new stock: Gem Chute, then Bramble: bramble dye |
| 8:34 | 8:53 | 0:19 | 8:00 | ok | Bramble: bramble dye, then Fennel: fennel postcards |
| 8:53 | 9:15 | 0:22 | 8:00 | ok | Fennel: fennel postcards, then Pip: pip cloud line |
| 9:15 | 9:15 | 0:00 | 8:00 | ok | Pip: pip cloud line, then A sun shower brings pegasus Drifters down |
| 9:15 | 11:52 | 2:37 | 8:00 | ok | A sun shower brings pegasus Drifters down, then Letter: Your quarterly performance summary |
| 11:52 | 13:00 | 1:08 | 8:00 | ok | Letter: Your quarterly performance summary, then Tumble spots Vinyl Scratch out in the grass |
| 13:00 | 17:01 | 4:00 | 8:00 | ok | Tumble spots Vinyl Scratch out in the grass, then The Palace on the Strip opens |
| 17:01 | 17:26 | 0:26 | 8:00 | ok | The Palace on the Strip opens, then First visit: The Strip |
| 17:26 | 17:49 | 0:22 | 8:00 | ok | First visit: The Strip, then First game at the casino |
| 17:49 | 18:20 | 0:32 | 8:00 | ok | First game at the casino, then First earth Drifter |
| 18:20 | 22:00 | 3:40 | 8:00 | ok | First earth Drifter, then Tumble spots Scootaloo out in the grass |
| 22:00 | 23:24 | 1:24 | 8:00 | ok | Tumble spots Scootaloo out in the grass, then A postcard from a delivered pony, in hoofwriting that is not hers |
| 23:24 | 27:23 | 3:59 | 8:00 | ok | A postcard from a delivered pony, in hoofwriting that is not hers, then Caught Scootaloo |
| 27:23 | 30:01 | 2:38 | 8:00 | ok | Caught Scootaloo, then Race day at the track |
| 30:01 | 31:01 | 1:00 | 8:00 | ok | Race day at the track, then Tumble spots Soarin out in the grass |
| 31:01 | 31:17 | 0:17 | 8:00 | ok | Tumble spots Soarin out in the grass, then Caught Soarin |
| 31:17 | 35:05 | 3:48 | 8:00 | ok | Caught Soarin, then Pip asks you to find a lost foal |
| 35:05 | 50:01 | 14:56 | 8:00 | **OVER** | Pip asks you to find a lost foal, then Tumble spots Octavia out in the grass |
| 50:01 | 57:23 | 7:22 | 8:00 | ok | Tumble spots Octavia out in the grass, then An Escape Artist hopped the Paddock fence |
| 57:23 | 60:16 | 2:53 | 8:00 | ok | An Escape Artist hopped the Paddock fence, then Caught Octavia |
| 60:16 | 60:16 | 0:00 | 15:00 | ok | Caught Octavia, then end of run |

Longest gap: 14:56.
