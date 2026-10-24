# Pacing

Written by `tools/pacing.sh`: a fresh save played by the human-paced bot (`game/scenes/test/human_bot.gd`), headless at a fixed 60 fps, so the clock below is play time. Every first-time unlock, discovery and story beat is stamped as it happens (`game/systems/novelty.gd`).

**Rules** (MISSION.md): no gap over 8:00 in the first hour, none over 15:00 after it, and the first clue by 15:00.

**Verdict: PASS**

Run: 72:26 of play, 57 new things, first clue at 5:34. bot seed 7, catches 27, deliveries 12, blooms 1, bits 9675

## Timeline

| Time | Kind | What |
|---|---|---|
| 0:02 | story | Letter: Your mailbox is installed |
| 1:52 | story | Marigold: marigold arrival |
| 2:25 | story | Tumble: tumble meets |
| 2:41 | story | Bramble: bramble first sale |
| 2:54 | tool | Got Fennel's old Treat Pouch |
| 3:13 | story | Fennel: fennel first pen |
| 3:38 | story | Pip: pip first letter |
| 3:53 | mechanic | Built the first pen |
| 3:53 | upgrade | Built a Paddock |
| 4:06 | story | Fennel: fennel bloom hint |
| 4:08 | mechanic | First catch with the Scoop |
| 4:08 | pony | First unicorn Drifter |
| 4:08 | mechanic | Tossed a treat from the Treat Pouch |
| 4:16 | pony | Caught Twilight Sparkle |
| 4:43 | npc | Bramble's new stock: Steward's Monocle |
| 4:49 | story | Marigold: marigold depot |
| 5:10 | mechanic | First delivery to the Depot |
| 5:10 | story | Letter: Thank you for your first shipment |
| 5:22 | story | Marigold: marigold first collection |
| 5:22 | npc | Bramble's new stock: Pony Whistle |
| 5:34 | clue | Tumble: tumble depot |
| 5:56 | area | Bramble's market stall |
| 6:01 | mechanic | Bought feed at the market |
| 6:16 | pony | First pegasus Drifter |
| 6:40 | story | Letter: Employee Appreciation Survey |
| 6:52 | npc | Bramble's new stock: Depot Cart |
| 6:57 | clue | Marigold: marigold vivid |
| 7:04 | npc | Bramble's new stock: Gem Chute |
| 7:14 | clue | Bramble: bramble dye |
| 7:33 | clue | Fennel: fennel postcards |
| 7:55 | clue | Pip: pip cloud line |
| 8:43 | clue | Letter: Your quarterly performance summary |
| 9:01 | event | A sun shower brings pegasus Drifters down |
| 9:13 | pony | First earth Drifter |
| 11:44 | pony | Caught Rarity |
| 13:00 | event | Tumble spots Scootaloo out in the grass |
| 13:31 | pony | Caught Scootaloo |
| 17:01 | event | The Palace on the Strip opens |
| 17:21 | area | First visit: The Strip |
| 17:38 | mechanic | First game at the casino |
| 20:00 | event | Tumble spots Pinkie Pie out in the grass |
| 23:31 | clue | A postcard from a delivered pony, in hoofwriting that is not hers |
| 26:00 | clue | Pip photographs you for the Corporation newsletter |
| 29:01 | event | Tumble spots Sweetie Belle out in the grass |
| 30:01 | event | Race day at the track |
| 35:01 | npc | Pip asks you to find a lost foal |
| 36:08 | mechanic | First Bloom: Mossy Glimmer earns her cutie mark |
| 36:36 | npc | Bramble's new stock: Scoop Launcher |
| 36:40 | story | Fennel: fennel after bloom |
| 40:01 | clue | A Collector stops at the fence and takes notes |
| 45:00 | pony | Starry Drifters, the rarest coat, wander in |
| 50:01 | event | Tumble spots Soarin out in the grass |
| 52:00 | event | Rainbow Dash's Sonic Rainboom over the valley |
| 57:00 | npc | Derpy's mail mix-up at the mailbox |
| 63:01 | event | The Great and Powerful Trixie plays the Strip |
| 67:36 | story | Letter: Your first collection day |
| 71:00 | event | Tumble spots Vinyl Scratch out in the grass |

## Gaps

| From | To | Gap | Limit | | Between |
|---|---|---|---|---|---|
| 0:00 | 0:02 | 0:02 | 8:00 | ok | start of play, then Letter: Your mailbox is installed |
| 0:02 | 1:52 | 1:49 | 8:00 | ok | Letter: Your mailbox is installed, then Marigold: marigold arrival |
| 1:52 | 2:25 | 0:33 | 8:00 | ok | Marigold: marigold arrival, then Tumble: tumble meets |
| 2:25 | 2:41 | 0:16 | 8:00 | ok | Tumble: tumble meets, then Bramble: bramble first sale |
| 2:41 | 2:54 | 0:13 | 8:00 | ok | Bramble: bramble first sale, then Got Fennel's old Treat Pouch |
| 2:54 | 3:13 | 0:20 | 8:00 | ok | Got Fennel's old Treat Pouch, then Fennel: fennel first pen |
| 3:13 | 3:38 | 0:24 | 8:00 | ok | Fennel: fennel first pen, then Pip: pip first letter |
| 3:38 | 3:53 | 0:16 | 8:00 | ok | Pip: pip first letter, then Built the first pen |
| 3:53 | 3:53 | 0:00 | 8:00 | ok | Built the first pen, then Built a Paddock |
| 3:53 | 4:06 | 0:13 | 8:00 | ok | Built a Paddock, then Fennel: fennel bloom hint |
| 4:06 | 4:08 | 0:01 | 8:00 | ok | Fennel: fennel bloom hint, then First catch with the Scoop |
| 4:08 | 4:08 | 0:00 | 8:00 | ok | First catch with the Scoop, then First unicorn Drifter |
| 4:08 | 4:08 | 0:01 | 8:00 | ok | First unicorn Drifter, then Tossed a treat from the Treat Pouch |
| 4:08 | 4:16 | 0:08 | 8:00 | ok | Tossed a treat from the Treat Pouch, then Caught Twilight Sparkle |
| 4:16 | 4:43 | 0:27 | 8:00 | ok | Caught Twilight Sparkle, then Bramble's new stock: Steward's Monocle |
| 4:43 | 4:49 | 0:06 | 8:00 | ok | Bramble's new stock: Steward's Monocle, then Marigold: marigold depot |
| 4:49 | 5:10 | 0:21 | 8:00 | ok | Marigold: marigold depot, then First delivery to the Depot |
| 5:10 | 5:10 | 0:00 | 8:00 | ok | First delivery to the Depot, then Letter: Thank you for your first shipment |
| 5:10 | 5:22 | 0:12 | 8:00 | ok | Letter: Thank you for your first shipment, then Marigold: marigold first collection |
| 5:22 | 5:22 | 0:00 | 8:00 | ok | Marigold: marigold first collection, then Bramble's new stock: Pony Whistle |
| 5:22 | 5:34 | 0:12 | 8:00 | ok | Bramble's new stock: Pony Whistle, then Tumble: tumble depot |
| 5:34 | 5:56 | 0:22 | 8:00 | ok | Tumble: tumble depot, then Bramble's market stall |
| 5:56 | 6:01 | 0:05 | 8:00 | ok | Bramble's market stall, then Bought feed at the market |
| 6:01 | 6:16 | 0:15 | 8:00 | ok | Bought feed at the market, then First pegasus Drifter |
| 6:16 | 6:40 | 0:24 | 8:00 | ok | First pegasus Drifter, then Letter: Employee Appreciation Survey |
| 6:40 | 6:52 | 0:12 | 8:00 | ok | Letter: Employee Appreciation Survey, then Bramble's new stock: Depot Cart |
| 6:52 | 6:57 | 0:05 | 8:00 | ok | Bramble's new stock: Depot Cart, then Marigold: marigold vivid |
| 6:57 | 7:04 | 0:07 | 8:00 | ok | Marigold: marigold vivid, then Bramble's new stock: Gem Chute |
| 7:04 | 7:14 | 0:09 | 8:00 | ok | Bramble's new stock: Gem Chute, then Bramble: bramble dye |
| 7:14 | 7:33 | 0:20 | 8:00 | ok | Bramble: bramble dye, then Fennel: fennel postcards |
| 7:33 | 7:55 | 0:21 | 8:00 | ok | Fennel: fennel postcards, then Pip: pip cloud line |
| 7:55 | 8:43 | 0:48 | 8:00 | ok | Pip: pip cloud line, then Letter: Your quarterly performance summary |
| 8:43 | 9:01 | 0:18 | 8:00 | ok | Letter: Your quarterly performance summary, then A sun shower brings pegasus Drifters down |
| 9:01 | 9:13 | 0:12 | 8:00 | ok | A sun shower brings pegasus Drifters down, then First earth Drifter |
| 9:13 | 11:44 | 2:31 | 8:00 | ok | First earth Drifter, then Caught Rarity |
| 11:44 | 13:00 | 1:16 | 8:00 | ok | Caught Rarity, then Tumble spots Scootaloo out in the grass |
| 13:00 | 13:31 | 0:31 | 8:00 | ok | Tumble spots Scootaloo out in the grass, then Caught Scootaloo |
| 13:31 | 17:01 | 3:30 | 8:00 | ok | Caught Scootaloo, then The Palace on the Strip opens |
| 17:01 | 17:21 | 0:20 | 8:00 | ok | The Palace on the Strip opens, then First visit: The Strip |
| 17:21 | 17:38 | 0:17 | 8:00 | ok | First visit: The Strip, then First game at the casino |
| 17:38 | 20:00 | 2:22 | 8:00 | ok | First game at the casino, then Tumble spots Pinkie Pie out in the grass |
| 20:00 | 23:31 | 3:31 | 8:00 | ok | Tumble spots Pinkie Pie out in the grass, then A postcard from a delivered pony, in hoofwriting that is not hers |
| 23:31 | 26:00 | 2:29 | 8:00 | ok | A postcard from a delivered pony, in hoofwriting that is not hers, then Pip photographs you for the Corporation newsletter |
| 26:00 | 29:01 | 3:00 | 8:00 | ok | Pip photographs you for the Corporation newsletter, then Tumble spots Sweetie Belle out in the grass |
| 29:01 | 30:01 | 1:00 | 8:00 | ok | Tumble spots Sweetie Belle out in the grass, then Race day at the track |
| 30:01 | 35:01 | 5:01 | 8:00 | ok | Race day at the track, then Pip asks you to find a lost foal |
| 35:01 | 36:08 | 1:07 | 8:00 | ok | Pip asks you to find a lost foal, then First Bloom: Mossy Glimmer earns her cutie mark |
| 36:08 | 36:36 | 0:28 | 8:00 | ok | First Bloom: Mossy Glimmer earns her cutie mark, then Bramble's new stock: Scoop Launcher |
| 36:36 | 36:40 | 0:04 | 8:00 | ok | Bramble's new stock: Scoop Launcher, then Fennel: fennel after bloom |
| 36:40 | 40:01 | 3:21 | 8:00 | ok | Fennel: fennel after bloom, then A Collector stops at the fence and takes notes |
| 40:01 | 45:00 | 4:59 | 8:00 | ok | A Collector stops at the fence and takes notes, then Starry Drifters, the rarest coat, wander in |
| 45:00 | 50:01 | 5:01 | 8:00 | ok | Starry Drifters, the rarest coat, wander in, then Tumble spots Soarin out in the grass |
| 50:01 | 52:00 | 1:59 | 8:00 | ok | Tumble spots Soarin out in the grass, then Rainbow Dash's Sonic Rainboom over the valley |
| 52:00 | 57:00 | 5:00 | 8:00 | ok | Rainbow Dash's Sonic Rainboom over the valley, then Derpy's mail mix-up at the mailbox |
| 57:00 | 63:01 | 6:01 | 8:00 | ok | Derpy's mail mix-up at the mailbox, then The Great and Powerful Trixie plays the Strip |
| 63:01 | 67:36 | 4:36 | 15:00 | ok | The Great and Powerful Trixie plays the Strip, then Letter: Your first collection day |
| 67:36 | 71:00 | 3:24 | 15:00 | ok | Letter: Your first collection day, then Tumble spots Vinyl Scratch out in the grass |
| 71:00 | 72:26 | 1:26 | 15:00 | ok | Tumble spots Vinyl Scratch out in the grass, then end of run |

Longest gap: 6:01.
