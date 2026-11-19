# Blasta (DaylightUI Plugin) — next version (in development)

## Unit frames

- **Reversed power bars slanted at both ends** — With **Reverse unit frame slant** on, a power bar slanted at both ends (the player's, or the target's or focus's on its own) now turns over with its fill: wider at the bottom, so the fill's edge follows the bar's end instead of leaning against it. Blasta also hands DaylightUI's own fill flip through again, so the power cost shade, bar lights and bar moments lean with the fill, and bars flipped in DaylightUI's settings (power bar, cast bar, swing timer) keep their flip. Flight timer, breath bars and nameplates use the same flip. Thanks to [AlexisWalravens](https://github.com/AlexisWalravens) ([pull request #2](https://github.com/BajaBlastah/Blasta-DaylightUI-Plugin-/pull/2)).


# Blasta (DaylightUI Plugin) 1.9.0 — 2026-11-18

**Two big changes, so nothing gets confusing:** the plugin is now called **Blasta (DaylightUI Plugin)** (before: Daylight Blasta), and **all of its settings moved into its own menu**. Blasta is a plugin by its own author, not part of DaylightUI: please send Blasta bugs to Blasta, not to the DaylightUI team. Made for DaylightUI 1.9.4.

## New name

- **Blasta (DaylightUI Plugin)** — The name DaylightUI asks every plugin to carry, in the game's addon list (in Blasta's blue-to-lime colors), in Key Bindings and in the login message. Inside DaylightUI's options it just says Blasta. Your settings stay as they were.

## Blasta's own menu

- **Everything in one place** — Every Blasta setting sits in Blasta's own section of DaylightUI's options window (`/blasta`). DaylightUI's pages show only DaylightUI again: no Blasta rows, badges or notes left in them.
- **Ten pages** — Overview, Unit frames, Auras & DoTs, Nameplates, Action bars, Info panel & buffs, Tooltips & money, Windows, World & moments and General. Long pages have tabs, e.g. Player, Target, Party, Raid, More frames, Look and Cast bars on Unit frames.
- **Short help on every tab** — The first card of each tab starts with a line on what the tab is for, in German or English by Blasta's language. The Windows and World tabs also have buttons that open the window they change (group finder, spellbook, character window, bags, quest log, world map).
- **Tall tooltip preview** — The Tooltips page shows the Blasta tooltip tall in a column on the right of the options window, with view chips for an item, your own item, a spell, a buff, a player, an enemy and a quest. Click **Item** again for a recipe or a quest item. The preview reads real tooltips, so it looks exactly like in the game: an item, recipe or quest item from your bags, a spell from your bars, one of your buffs, yourself, your target and a quest from your log, at the same width as in the game. Only when there's none of a kind does a made-up sample stand in. Click a part of it to jump to its setting.
- **What's new** — The Overview lists what this version adds, each with a **Show** button that opens its setting. New rows carry a "New" tag on their pages.
- **Reset this tab** — The last card of every tab ends with a button that puts only that tab's Blasta settings back to their defaults (click twice). DaylightUI's own settings shown there stay as they are.
- **Search finds the right rows** — Searching DaylightUI's options for "menu", "blasta" or "light" no longer lists every Blasta row. Blasta's rows match their English text and the language Blasta shows.
- **Live previews with Design mode** — Unit frame and nameplate tabs show DaylightUI's live preview of that frame on top. DaylightUI's Design mode works there: drag Blasta's parts like the leader crown or the PvP badge into place, and they save where they belong.
- **Clearer names** — The flight master bar and the breath and fatigue bars sit together under **Flight & breath bars**, each card named after its bar.
- **Smaller heading** — Blasta's heading in the options list is DaylightUI's normal size again and reads just "Blasta".
- **Nothing lost** — Every setting keeps its value. Settings that extend a DaylightUI feature still save with that feature, and a line on the card says when its DaylightUI module or switch is off.

## Nameplates

- **Interrupt hint** — An enemy's cast bar lights up while you could interrupt it right now: the cast can be interrupted and your interrupt is ready (DaylightUI knows it by class, rank, stance and form). Pulsing or steady, in a color of your choice, on every enemy or only your target. Off by default: **Blasta → Nameplates → Interrupt hint**.
- **Move the cast time** — The remaining time on enemy cast bars has its own left/right and up/down sliders and can be dragged in Design mode.
- **Interrupts with Blasta's cast bar edges** — When a cast bar with Blasta's own right edge is interrupted, the pieces now follow that edge. DaylightUI 1.9.4 keeps the red "Interrupted" bar for a moment itself, so Blasta no longer holds it.

## Unit frames and auras

- **Dispel highlight fits your class** — "Only mine" is now **Only what you can remove** and on by default: the highlight shows only effects your class can remove. New: **Only while you can cast it** hides it while your dispel can't be cast right now (in a form without it, silenced or out of mana). To see every dispel type again, switch it off on the card.
- **Finisher damage color works again** — DaylightUI 1.9.4 no longer splits the damage left by kind, so Blasta keeps its own record of your finishers (Rupture, Rip and the like) and colors their share separately again.
- **Raid marker in Design mode** — The raid marker on the target and focus frames has left/right and up/down sliders and can be dragged in Design mode.

## Character window

- **Health and power bars** — Health and your power (mana, rage, energy) sit as two bars on top of the stats, in place of their rows. The rest of DaylightUI's list stays as it is. Hover a bar for its tooltip. Off by default: **Blasta → Windows → Character → Health and power bars**.

## Compatibility

- **Check after DaylightUI updates** — After login Blasta checks that every part found what it needs in DaylightUI. If one stays off, it says so once in chat per DaylightUI version. `/blasta check` lists it again, and `/blasta report` adds it to the bug report.

## Bar animations

- **Blasta animations on their own** — Blasta's animations (Frost, Arcane, Holy, Nature, Shadowflame, Lava, Radiance, Wild, Storm, Poison, By class) are no longer in DaylightUI's "Bar animation" list. Each bar's card on Blasta's pages has its own **Blasta animation** choice, with the live sample, speed, strength, colors and "Only in combat". A bar that wore a Blasta animation keeps it: the pick moves over by itself.

## Action bars

- **Finer size and spacing** — Half-pixel button sizes and spacing down to −10 are Blasta's own sliders now (Action bars → Bars), the same settings as DaylightUI's. DaylightUI's own sliders are as DaylightUI made them.

## Removed (DaylightUI does it now)

- **Zone levels on the world map** — DaylightUI 1.9.4 shows the hovered zone's level range itself (Game window skins → World map → Zone levels). Blasta's own label is gone; the zone title still shows the level range of the zone you're in.
- **Group finder side by side** — DaylightUI 1.9.4 shows groups and solo players side by side in a wide window, with its own resize grip. Blasta's two columns and its own window width are gone. The filters, several dungeons, level ranges and one-click applying stay.

# Daylight Blasta 1.8.0 — 2026-11-18

## Info panel

- **Exact money is now opt-in** — The full gold, silver and copper amount no longer shows by default, since it often got cut off in the minimap info panel. Turn it on under **Blasta → Info panel & buffs → Data texts → Show exact money**.

## Dungeon finder

- **Side by side** — Groups and solo players show in two columns. Find a group opens wider for it, and below about 600 px of list width it goes back to one column, also while you drag the window smaller. Find a group remembers its own width; right-click the resize grip to reset it.
- **Opens by itself** — The filter window now opens with Find a group on Dungeons. Closed by hand, it stays closed until you open Find a group again.
- **Several dungeons** — The dungeon list in the filter window now takes several picks. It stays open while you tick dungeons, and groups for any of them show. "All dungeons" clears the picks; the button reads e.g. "Gnomeregan +2".
- **Already in the group** — The filter window has a new section to pick roles and classes a group must already have. Pick several and only groups with all of them show.
- **Solo players and open roles** — With open roles picked, solo players who can fill one of them still show instead of being hidden.
- **Level ranges** — Every dungeon in the filter list and every listing in Find a group shows its suggested levels in DaylightUI's colors (dimmed below you, a warning above). A listing for several dungeons shows one range over all of them.
- **Apply** — A group's card has an "Apply" button: it whispers the leader a short note with your level, class, roles and the dungeon (the picked ones when it's listed for several), then reads "Applied". Shift-click opens the whisper with the note to change first. `/blasta apply <text>` (or `/blasta bewerbung`) sets your own note; {level} {class} {roles} {dungeon} are filled in, `reset` brings back the default.
- **Group card** — The card beside the list no longer has a lighter background: it's see-through like the rest of the window, with a thin line between list and card.
- **Playstyle** — The German "Ziehhilfe" now reads "Mitziehen".

## Training

- **Everything ahead** — The Training page's footer shows, beside "Learn now costs", what all spells still ahead cost together: learnable now, the next levels and later, pet spells and those waiting on a requirement (not talent spells, weapon skills, known or ignored ones). Red when it's more than you carry.

## Shadow Word: Death

- **Slanted marker** — On a slanted target frame or nameplate the kill estimate's line and glow now lean with the health bar's angled edge (also with "Reverse unit frame slant"), instead of standing straight.

## Tooltips and money

- **Daylight coins everywhere** — Prices other addons add to tooltips (Auctionator's auction and vendor prices), every money box the game updates (merchant, mail, quests) and Auctionator's auction house lists now use DaylightUI's coins. Switch: **Blasta → Tooltips & money → Daylight coins everywhere**, on by default.
- **Sell price per piece** — On a stack the game's sell price was for the whole stack while Auctionator's prices are per piece. The sell price now follows Auctionator: one piece, and "Sell price x20" for the stack with Shift (or the other way round, by Auctionator's "Shift for stack price" setting). Switch: **Blasta → Tooltips & money → Sell price per piece**, on by default.

## World map

- **Boat and zeppelin routes** — Builds on DaylightUI's "Boats and zeppelins" symbols. Hovering one on a zone map draws its route as a bold solid line, with an arrow where it leaves the map. On continent and world maps a small dock symbol stands at each dock and shows its routes on hover. Lines are solid gold with a thin dark edge so they read on any map. Switch: **Blasta → World & moments → World map → Boat and zeppelin routes**, on by default.

## Zone title

- **German texts** — "Discovered", "Resting" and a few other late additions (Only in combat, Kills to the next level, Blasta report, the zone title settings) now show in German. They never reached the German table before.

## Removed

- **Addon skins** — Blasta no longer skins other addons (RareScanner, BugSack, Delete Cheapest Item, Keep or Toss, Does It Die, Camping Kit, Loot Triage, OpenMap, Spoken, Forever Fishing, Polestar, Glowing Bars, Books on Map and GearQuest). The AddonSkins page in Blasta's settings is gone, and skin switches other plugins add stay on DaylightUI's own Game window skins page. Please use **AddonSkins by Glowey_** for these skins. Old skin settings stay in your profile but do nothing.

## Fixes

- **Frame shape** — The "Frame shape" option no longer errors when DaylightUI's corner setting is empty.
- **Nameplate shape** — Angled nameplates no longer depend on DaylightUI's border setting being filled in.

# Daylight Blasta 1.7.1 — 2026-11-17

Works with DaylightUI 1.9.3.

## Experience bar

- **Gain animation** — New experience shows at once as a light piece, and the fill runs after it with a soft light on its tip: quick for a kill, longer for a big quest turn-in. Kills in a row carry on without restarting.
- **Level up** — The fill runs to the end, a band crosses the full bar, the bar drains back to the left, and it fills again. The rested part grows back after it.
- **Reputation waits** — When a quest gives experience and reputation together, the reputation bar shows after the experience animation instead of covering it.
- **Settings** — Switch and test button under **Info panel → Gain animation**. DaylightUI's rising "+N" stays. Needs Motion effects.
- **Kills to the next level** — Hovering the bar shows about how many more kills the level takes, worked out from the experience of your last ten kills. Switch under **Info panel → Gain animation**.

## Bar animations

- **Only in combat** — A new switch under each bar's **Animation strength** lets the animation rest outside a fight and start when one begins. The preview on the settings page keeps moving.

## Tooltips

- **Live preview** — DaylightUI's Tooltips page now shows a Blasta tooltip at the top that changes as you move a slider. Chips pick an item, a comparison, a spell or a unit. The sample item has a line of every kind: name, small print, base stats, bonus stats, enchantment, effect, prices and source.
- **Click a line, find its setting** — Hovering a line in the preview names its text size, and a click jumps to that slider.
- **Three clear cards** — The Blasta rows no longer sit in the middle of DaylightUI's Look card. They have their own cards: Blasta tooltips, Tooltip text sizes, and Tooltip icon and header. The text sizes go from top to bottom in the order the lines appear, each named after the lines it changes, with a button to reset them.
- **No doubled rows** — Tooltip position, cursor offsets, scale and background no longer show twice.
- **Zoom** — The preview has DaylightUI's zoom slider, from 0.6x to 1.6x, to look closely at small text or fit a tall tooltip.
- **Your item** — A new chip shows something you actually wear (your weapon first) through the real Blasta tooltip, so your own gear shows how your settings look.

## Bug reports

- **/blasta report** — Opens a window with Blasta's and DaylightUI's versions, the game version and language, which Blasta parts are on, your other addons and this session's latest Blasta errors, ready to copy into a GitHub issue.

## Zone title

- **Zone title extras** — Three new switches for DaylightUI's zone title, under **Quality of Life → Zone title extras**, all off at first:
  - **Level range** — The levels the zone is meant for show under the title, colored like a quest of that level.
  - **Newly discovered** — When the game counts a place as newly explored, "Discovered" shows over its name.
  - **Resting** — Stepping into an inn or a city shows the place's name with "Resting" under it.
- A preview button plays the title for where you are, with the extras that are on.

## Swing timer

- **Fans out with the cast bar** — With DaylightUI 1.9.3's cast bar between your frame and the target's, "Retract swing timer while casting" no longer pulls the swing timers in, so they fan out under the cast bar as DaylightUI draws them.

## Fixes

- **"Opening - No Text" on the cast bar** — Picking up quest items and similar interactions now read "Öffnen" on German clients, instead of the game's untranslated spell name.
- **Bar moments on bars angled at both ends** — No more Lua error from the light bands for damage, heals and spent power on a bar slanted at both ends, like a power bar on its own with both ends angled. A band now keeps the frame's clip only at the empty end and lets its angled lead edge cut the full end, staying within the game's three masks per texture. Thanks to [AlexisWalravens](https://github.com/AlexisWalravens) (pull request #1).

# Daylight Blasta 1.7 — 2026-11-17

Requires DaylightUI 1.9.2.

## Settings in DaylightUI's menus

- **One menu** — Every Blasta setting that extends a DaylightUI feature now sits right beside that feature in DaylightUI's own menus. A small **BLASTA** badge marks each one, and cards that hold only Blasta settings read **From Blasta**.
- **Where things moved** — Nameplate auras are under **Nameplates → Auras**. Aura icons and the dispel highlight are on the unit frame pages, aura bars on **Player**, and bar effects under **Unit frames → Look**. Per-bar slants and pixel-aligned buttons are on **Bar Layout → Bars**, and resource costs on buttons under **Action Bars → Text**. The loot feed is under **Loot feed**, the character panel under **Character window**, and square spellbook icons and the dungeon finder on **Windows**. Zone level ranges are under **Game window skins → World map**. The experience bar, data text colors and info panel spacing are under **Info panel**, and the minimap buff layout and aura reminders under **Buffs**.
- **Blasta's own menu** — It keeps only what DaylightUI has nothing like: consumable bars, language, profiles and add-on skins.
- **One preview** — Blasta's own previews are gone. Aura bars, aura fitting, moved portrait icons, the dispel highlight test and the resource-cost sample buttons all show in DaylightUI's previews.
- **Design mode** — The leader crown, PvP flag, resting icon and level text can be dragged in DaylightUI's Design mode. So can the party portrait and the compact party resource bar in the party preview.

## Action bars

- **Finer button layout** — DaylightUI's button size slider on **Bar Layout → Bars** takes half pixels, and button spacing goes down to −10.
- **Resource costs** — Missing Rage and Energy now show on clients that keep power values restricted, with a separate green text for the surplus. Abilities in macros are recognized, and costs that depend on an inactive aura use the lowest cost.
- **/blastarage** — Prints why resource numbers do or don't appear, with one line per occupied action button.

## Bar animations

- **Eleven Blasta presets** — Frost, Arcane, Holy, Nature, Shadowflame, Lava, Radiance, Wild, Storm and Poison, plus **By class**, which picks one per class and follows the shown player's class on target, focus and party bars. Pick them under **Bar animation** on any page that offers it, including nameplates, cast bars and the swing timer. Needs Motion effects.
- **Hit and heal flash** — Hits and heals flash the bar's end.
- **Smaller files** — The animation sheets take about 8 MB instead of 54 MB and look and play the same.

## Tooltips

- **Clearer layout** — Item tooltips are sorted into parts: damage per second or armor first, then stats, equip effects, other addons' lines as a small label/value table, stat changes, and prices. Where the item comes from closes the tooltip, with the dungeon journal source, source paths and the item ID.
- **Less clutter** — The repeated slot and type line, duplicate prices and other addons' key hints are left out. Durability shows only on worn items: yellow under 50 %, red under 25 %.
- **Short equip effects** — Long equip texts read as values in English and German, such as "+26 Spell Power" or "+45 Attack Power · against Beasts". Conditions always stay visible.
- **Stat changes in two columns** — When comparing items, gains are on the left and losses on the right.
- **Text sizes** — Four new sliders set the size of base stats, bonus stats, enchantments and other effects.

## Bags

- **Blasta categories** — The switch (formerly "Enable BlastaBags") is at the top of **Bags → Categories**. It adds Blasta's material categories as DaylightUI categories.
- **Filter bar** — The Blasta filter bar has its own switch now.
- **Square item icons** — New switch under **Bags → Item icons**. With it on, quest items get a square gold border and quest starters a gold "!".

## Loot feed and party frames

- **Loot feed choice** — One switch picks DaylightUI's feed or Blasta's. With Blasta's on, choose **Blasta Standard** or **Blasta Elegant**.
- **Compact party resource bar** — While it is on, DaylightUI's own party power height and gap are grayed out, since the bar's own settings replace them.

## Removed

- **Quest level after the title** — DaylightUI shows quest levels itself now.
- **Blasta's own bag category lists** — Making, renaming, hiding and deleting categories is done on DaylightUI's Categories page.

## Fixes

- The target glow shows again in DaylightUI's nameplate preview for plates angled at both ends.
- The login message shows the full Blasta gradient again, not just blue.

## Performance

- Dispel highlights only listen for aura changes on your target and yourself.
- Class bar animations check new nameplates once per frame instead of once per plate.
- The Shadow Word: Death marker no longer allocates memory on each check.

# Daylight Blasta 1.6.2

## Bar effects

- **Damage and healing** — Damage briefly highlights the lost section of the player and target health bars, with optional sparks. Healing highlights the restored section on the player and target. Party members use shorter, particle-free damage and healing highlights. Enemy nameplates can show damage feedback.
- **Resource spending** — The spent part of your resource bar flashes after the cast succeeds and the resource value updates. The flash follows angled bar edges and sends a short fan of sparks from the new fill edge. Target and party bars can highlight readable resource drops. Focus feedback and a single target spark are optional.
- **Warnings** — A low-health heartbeat can pulse on your bar and at the screen edge. Full resources shimmer, and execute embers can appear on the target and enemy nameplates.
- **Controls and previews** — Set colors and strengths, preview effects on your own frame, or switch them all off under **Bar effects → General**. Your individual settings stay saved.

## Unit frames and auras

- **Compact party resource bar** — Position a shorter resource bar under or across each member's health bar. Adjust width, height, border thickness down to 1 px, both edge shapes, and horizontal and vertical offsets. The target outline follows the health bar. Requested by Pixel.
- **Remaining DoT damage** — Choose solid fill, diagonal hatching, wide diagonal bands, fine dots, or crosshatching on the target and enemy nameplates. Patterns use your chosen color and opacity, including on a separate finisher segment when DaylightUI supplies one.
- **Aura duration bars** — Icons snap to whole screen pixels to stay square at fractional UI scales.

## Performance

- The compact resource bar applies its width after you release the slider, reducing repeated group layout updates while dragging.
- Resource-cost overlays on action buttons refresh tracked costs when auras change. Modifier and target changes rescan action slots only when a tracked button uses a macro.

# Daylight Blasta 1.6.1 — 2026-11-16

- Bag organization filters follow DaylightUI 1.8.4's optional compact header and stay below its own filter rows. Category headings, list headers and item slots stay below the Blasta filter row when the bag layout changes.
- Both Blasta loot feeds use DaylightUI's localized skill-up parser when available.
