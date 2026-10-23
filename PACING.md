# Pacing

Written by `tools/pacing.sh`: a fresh save played by the human-paced bot (`game/scenes/test/human_bot.gd`), headless at a fixed 60 fps, so the clock below is play time. Every first-time unlock, discovery and story beat is stamped as it happens (`game/systems/novelty.gd`).

**Rules** (MISSION.md): no gap over 8:00 in the first hour, none over 15:00 after it, and the first clue by 15:00.

**Verdict: FAIL**
- early gap of 9:00 after "Tumble spots Octavia out in the grass" (limit 8:00)

Run: 70:27 of play, 62 new things, first clue at 5:22. bot seed 7, catches 73, deliveries 57, blooms 0, bits 6814

## Timeline

| Time | Kind | What |
|---|---|---|
| 0:02 | story | Letter: Your mailbox is installed |
| 1:55 | story | Marigold: marigold arrival |
| 2:10 | story | Tumble: tumble meets |
| 2:27 | story | Bramble: bramble first sale |
| 2:39 | tool | Got Fennel's old Treat Pouch |
| 2:59 | story | Fennel: fennel first pen |
| 3:23 | story | Pip: pip first letter |
| 3:40 | mechanic | Built the first pen |
| 3:40 | upgrade | Built a Paddock |
| 3:58 | story | Fennel: fennel bloom hint |
| 4:00 | mechanic | First catch with the Scoop |
| 4:00 | pony | First pegasus Drifter |
| 4:08 | pony | First earth Drifter |
| 4:10 | pony | Caught Twilight Sparkle |
| 4:37 | npc | Bramble's new stock: Steward's Monocle |
| 4:43 | story | Marigold: marigold depot |
| 4:59 | mechanic | First delivery to the Depot |
| 4:59 | story | Letter: Thank you for your first shipment |
| 5:10 | story | Marigold: marigold first collection |
| 5:10 | npc | Bramble's new stock: Pony Whistle |
| 5:22 | clue | Tumble: tumble depot |
| 5:36 | mechanic | Tossed a treat from the Treat Pouch |
| 7:10 | area | Bramble's market stall |
| 7:15 | mechanic | Bought feed at the market |
| 7:25 | pony | First unicorn Drifter |
| 7:48 | story | Letter: Employee Appreciation Survey |
| 8:00 | npc | Bramble's new stock: Depot Cart |
| 8:05 | clue | Marigold: marigold vivid |
| 8:11 | npc | Bramble's new stock: Gem Chute |
| 8:21 | clue | Bramble: bramble dye |
| 8:40 | clue | Fennel: fennel postcards |
| 9:02 | clue | Pip: pip cloud line |
| 9:03 | event | A sun shower brings pegasus Drifters down |
| 10:56 | tool | Bought Gallop Shoes |
| 11:25 | clue | Letter: Your quarterly performance summary |
| 13:01 | event | Tumble spots Soarin out in the grass |
| 15:24 | mechanic | Galloped in the Gallop Shoes |
| 17:00 | event | The Palace on the Strip opens |
| 17:49 | area | First visit: The Strip |
| 18:02 | mechanic | First game at the casino |
| 18:37 | pony | Caught Sweetie Belle |
| 19:29 | upgrade | Built a Big Pen |
| 22:14 | pony | Caught Soarin |
| 23:40 | clue | A postcard from a delivered pony, in hoofwriting that is not hers |
| 26:02 | clue | Pip photographs you for the Corporation newsletter |
| 29:25 | pony | Caught Scootaloo |
| 30:00 | event | Race day at the track |
| 31:00 | event | Tumble spots Pinkie Pie out in the grass |
| 31:37 | pony | Caught Pinkie Pie |
| 35:01 | npc | Pip asks you to find a lost foal |
| 35:45 | pony | Caught Rarity |
| 40:00 | clue | A Collector stops at the fence and takes notes |
| 40:01 | event | Tumble spots Limestone Pie out in the grass |
| 40:49 | event | An Escape Artist hopped the Paddock fence |
| 41:28 | pony | Caught Limestone Pie |
| 41:32 | pony | Caught Lotus |
| 45:01 | pony | Starry Drifters, the rarest coat, wander in |
| 49:00 | event | Tumble spots Octavia out in the grass |
| 58:01 | event | Tumble spots Vinyl Scratch out in the grass |
| 60:23 | pony | Caught Vinyl Scratch |
| 67:01 | event | Tumble spots Coco Pommel out in the grass |
| 68:44 | pony | Caught Coco Pommel |

## Gaps

| From | To | Gap | Limit | | Between |
|---|---|---|---|---|---|
| 0:00 | 0:02 | 0:02 | 8:00 | ok | start of play, then Letter: Your mailbox is installed |
| 0:02 | 1:55 | 1:53 | 8:00 | ok | Letter: Your mailbox is installed, then Marigold: marigold arrival |
| 1:55 | 2:10 | 0:16 | 8:00 | ok | Marigold: marigold arrival, then Tumble: tumble meets |
| 2:10 | 2:27 | 0:16 | 8:00 | ok | Tumble: tumble meets, then Bramble: bramble first sale |
| 2:27 | 2:39 | 0:13 | 8:00 | ok | Bramble: bramble first sale, then Got Fennel's old Treat Pouch |
| 2:39 | 2:59 | 0:20 | 8:00 | ok | Got Fennel's old Treat Pouch, then Fennel: fennel first pen |
| 2:59 | 3:23 | 0:24 | 8:00 | ok | Fennel: fennel first pen, then Pip: pip first letter |
| 3:23 | 3:40 | 0:17 | 8:00 | ok | Pip: pip first letter, then Built the first pen |
| 3:40 | 3:40 | 0:00 | 8:00 | ok | Built the first pen, then Built a Paddock |
| 3:40 | 3:58 | 0:18 | 8:00 | ok | Built a Paddock, then Fennel: fennel bloom hint |
| 3:58 | 4:00 | 0:02 | 8:00 | ok | Fennel: fennel bloom hint, then First catch with the Scoop |
| 4:00 | 4:00 | 0:00 | 8:00 | ok | First catch with the Scoop, then First pegasus Drifter |
| 4:00 | 4:08 | 0:07 | 8:00 | ok | First pegasus Drifter, then First earth Drifter |
| 4:08 | 4:10 | 0:02 | 8:00 | ok | First earth Drifter, then Caught Twilight Sparkle |
| 4:10 | 4:37 | 0:27 | 8:00 | ok | Caught Twilight Sparkle, then Bramble's new stock: Steward's Monocle |
| 4:37 | 4:43 | 0:06 | 8:00 | ok | Bramble's new stock: Steward's Monocle, then Marigold: marigold depot |
| 4:43 | 4:59 | 0:16 | 8:00 | ok | Marigold: marigold depot, then First delivery to the Depot |
| 4:59 | 4:59 | 0:00 | 8:00 | ok | First delivery to the Depot, then Letter: Thank you for your first shipment |
| 4:59 | 5:10 | 0:11 | 8:00 | ok | Letter: Thank you for your first shipment, then Marigold: marigold first collection |
| 5:10 | 5:10 | 0:00 | 8:00 | ok | Marigold: marigold first collection, then Bramble's new stock: Pony Whistle |
| 5:10 | 5:22 | 0:13 | 8:00 | ok | Bramble's new stock: Pony Whistle, then Tumble: tumble depot |
| 5:22 | 5:36 | 0:14 | 8:00 | ok | Tumble: tumble depot, then Tossed a treat from the Treat Pouch |
| 5:36 | 7:10 | 1:34 | 8:00 | ok | Tossed a treat from the Treat Pouch, then Bramble's market stall |
| 7:10 | 7:15 | 0:04 | 8:00 | ok | Bramble's market stall, then Bought feed at the market |
| 7:15 | 7:25 | 0:11 | 8:00 | ok | Bought feed at the market, then First unicorn Drifter |
| 7:25 | 7:48 | 0:23 | 8:00 | ok | First unicorn Drifter, then Letter: Employee Appreciation Survey |
| 7:48 | 8:00 | 0:11 | 8:00 | ok | Letter: Employee Appreciation Survey, then Bramble's new stock: Depot Cart |
| 8:00 | 8:05 | 0:05 | 8:00 | ok | Bramble's new stock: Depot Cart, then Marigold: marigold vivid |
| 8:05 | 8:11 | 0:07 | 8:00 | ok | Marigold: marigold vivid, then Bramble's new stock: Gem Chute |
| 8:11 | 8:21 | 0:10 | 8:00 | ok | Bramble's new stock: Gem Chute, then Bramble: bramble dye |
| 8:21 | 8:40 | 0:19 | 8:00 | ok | Bramble: bramble dye, then Fennel: fennel postcards |
| 8:40 | 9:02 | 0:22 | 8:00 | ok | Fennel: fennel postcards, then Pip: pip cloud line |
| 9:02 | 9:03 | 0:01 | 8:00 | ok | Pip: pip cloud line, then A sun shower brings pegasus Drifters down |
| 9:03 | 10:56 | 1:53 | 8:00 | ok | A sun shower brings pegasus Drifters down, then Bought Gallop Shoes |
| 10:56 | 11:25 | 0:29 | 8:00 | ok | Bought Gallop Shoes, then Letter: Your quarterly performance summary |
| 11:25 | 13:01 | 1:36 | 8:00 | ok | Letter: Your quarterly performance summary, then Tumble spots Soarin out in the grass |
| 13:01 | 15:24 | 2:23 | 8:00 | ok | Tumble spots Soarin out in the grass, then Galloped in the Gallop Shoes |
| 15:24 | 17:00 | 1:37 | 8:00 | ok | Galloped in the Gallop Shoes, then The Palace on the Strip opens |
| 17:00 | 17:49 | 0:48 | 8:00 | ok | The Palace on the Strip opens, then First visit: The Strip |
| 17:49 | 18:02 | 0:13 | 8:00 | ok | First visit: The Strip, then First game at the casino |
| 18:02 | 18:37 | 0:35 | 8:00 | ok | First game at the casino, then Caught Sweetie Belle |
| 18:37 | 19:29 | 0:52 | 8:00 | ok | Caught Sweetie Belle, then Built a Big Pen |
| 19:29 | 22:14 | 2:46 | 8:00 | ok | Built a Big Pen, then Caught Soarin |
| 22:14 | 23:40 | 1:26 | 8:00 | ok | Caught Soarin, then A postcard from a delivered pony, in hoofwriting that is not hers |
| 23:40 | 26:02 | 2:22 | 8:00 | ok | A postcard from a delivered pony, in hoofwriting that is not hers, then Pip photographs you for the Corporation newsletter |
| 26:02 | 29:25 | 3:23 | 8:00 | ok | Pip photographs you for the Corporation newsletter, then Caught Scootaloo |
| 29:25 | 30:00 | 0:35 | 8:00 | ok | Caught Scootaloo, then Race day at the track |
| 30:00 | 31:00 | 1:00 | 8:00 | ok | Race day at the track, then Tumble spots Pinkie Pie out in the grass |
| 31:00 | 31:37 | 0:37 | 8:00 | ok | Tumble spots Pinkie Pie out in the grass, then Caught Pinkie Pie |
| 31:37 | 35:01 | 3:24 | 8:00 | ok | Caught Pinkie Pie, then Pip asks you to find a lost foal |
| 35:01 | 35:45 | 0:44 | 8:00 | ok | Pip asks you to find a lost foal, then Caught Rarity |
| 35:45 | 40:00 | 4:15 | 8:00 | ok | Caught Rarity, then A Collector stops at the fence and takes notes |
| 40:00 | 40:01 | 0:01 | 8:00 | ok | A Collector stops at the fence and takes notes, then Tumble spots Limestone Pie out in the grass |
| 40:01 | 40:49 | 0:47 | 8:00 | ok | Tumble spots Limestone Pie out in the grass, then An Escape Artist hopped the Paddock fence |
| 40:49 | 41:28 | 0:39 | 8:00 | ok | An Escape Artist hopped the Paddock fence, then Caught Limestone Pie |
| 41:28 | 41:32 | 0:05 | 8:00 | ok | Caught Limestone Pie, then Caught Lotus |
| 41:32 | 45:01 | 3:29 | 8:00 | ok | Caught Lotus, then Starry Drifters, the rarest coat, wander in |
| 45:01 | 49:00 | 4:00 | 8:00 | ok | Starry Drifters, the rarest coat, wander in, then Tumble spots Octavia out in the grass |
| 49:00 | 58:01 | 9:00 | 8:00 | **OVER** | Tumble spots Octavia out in the grass, then Tumble spots Vinyl Scratch out in the grass |
| 58:01 | 60:23 | 2:22 | 8:00 | ok | Tumble spots Vinyl Scratch out in the grass, then Caught Vinyl Scratch |
| 60:23 | 67:01 | 6:38 | 15:00 | ok | Caught Vinyl Scratch, then Tumble spots Coco Pommel out in the grass |
| 67:01 | 68:44 | 1:43 | 15:00 | ok | Tumble spots Coco Pommel out in the grass, then Caught Coco Pommel |
| 68:44 | 70:27 | 1:44 | 15:00 | ok | Caught Coco Pommel, then end of run |

Longest gap: 9:00.
