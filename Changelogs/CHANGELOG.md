# Blasta (DaylightUI Plugin) 2.4

Made for DaylightUI 2.4.0: a raid marker ring on the target's portrait, equal coin shares in the loot feed, bag text sizes at the bank too, and two things DaylightUI now does itself, so Blasta's own versions are gone and your choices move over.

## What's new

- **What's new pages:** after login Blasta shows what a new version brings, once per account, in DaylightUI's own setup guide window right after DaylightUI's pages. For 2.4: the raid marker ring with a moving preview on your own portrait and its three settings, the coin colors with sample rows and the choice, and what moved to DaylightUI. Settings on these pages apply at once.
- See them again any time with **Blasta → General → What's new → Show what's new in 2.4**, or `/blasta new` (`/blasta neu`).
- **Blasta tour:** one page per area of Blasta (unit frames, cast bars, auras, nameplates, action bars, bags and loot, windows, world and info, tooltips) in the same window, each with the live preview from that page of Blasta's menu and the settings most worth trying. Only what your Blasta really has shows up: an area with nothing loaded is left out. Start it with **Start the tour** on Blasta's **Overview** or `/blasta tour`; it never opens by itself, and Blasta's menu closes when it starts.
- Blasta's **Overview** also has a button for **What's new**, and its "New in Blasta" list shows the 2.4 news.

## Target frame

- **Raid marker ring** in **Blasta → Unit frames → Target → Portrait** (off by default): a small arrow on the target's portrait opens a dark ring around it with DaylightUI's eight raid markers. Click one to mark your target and the ring closes; the chip beside the arrow takes the marker off.
  - **Open the marker ring:** **On click**, or **On hover** for marking quickly: the ring opens as soon as the mouse is on the arrow and closes a moment after it leaves.
  - **Marker arrow position:** moves the arrow anywhere around the portrait's rim, in degrees clockwise from the top (135, bottom right, by default). The chip follows on the same line.
  - **One piece with the portrait:** the arrow and the chip wear the portrait's own band, in its width and colors. The ring's edge is a thin 2 px line in the same colors (or gradient), without the band's black outline, and follows the portrait ring on every new target.
  - **Round or square:** with a square or angled portrait, the ring is square too, its markers on the corners and the middles of the sides, the arrow sits on the square's edge, and the arrow and the chip wear the portrait's square frame.
  - **Animation:** the ring grows out of the portrait in a short animation, the markers riding out and growing with it, the chip rolling out of the arrow and the arrow turning; closing runs it all back in. With DaylightUI's motion off it opens and closes at once.
  - **No tooltips in the way:** the marker or chip under the mouse lights up in your accent color instead. The arrow shows no tooltip on hover either.
  - Blasta's Shadow Word: Death marker on the target's health bar fades out under the open ring.
  - Works in combat too, like DaylightUI's leader drawer. Out of combat the ring also closes on a new target or a click elsewhere. In a raid, the arrow only shows for the leader and assistants.

## Loot feed

- **Coin color → All coins** now gives each coin looted an equal share of the bar, from the highest to the lowest: half each for two coins, a third each for three, with a short soft blend between them. Before, the colors ran as one long gradient, so the lower coins barely showed.

## Bags and bank

- **Bag category text size** and **Bag stack count size** now apply to the bank and to the window for the bank and alts too, not only to the bags.

## Moved to DaylightUI

- **Breath bar edges:** DaylightUI 2.4.0 sets each end of the breath bar on its own: **Skins → Alerts and timers → Breath bar left end / right end** (Straight, Leans / or Leans \). Blasta's **Left edge direction** and **Right edge direction** for the breath bar are removed. Your choices carry over: top corner out is the usual angle, bottom corner out the flipped one. The fatigue and feign death bars follow, as before.
- **Reverse unit frame slant:** DaylightUI 2.4.0 has a menu for each end of every unit frame (player, target, target of target, focus, pet, party, party pets, raid and PvP frames), and attached bars lean with it. Blasta's **Reverse unit frame slant** is removed. Where it was on, both ends of that frame are now flipped in DaylightUI, so the frame keeps its look. Each end can now be changed on its own.

## Experience bar

- DaylightUI 2.4.0's bar animations on the experience and reputation bar now end exactly where Blasta's angled or rounded ends do, instead of showing past them. This also covers a style picked or changed later.
- Both ends flipped (bottom corner out on both sides) now uses DaylightUI's own shape, border and shadow included, instead of two half bars.

## Angled ends

- The nameplate health bar, the compact party resource bar and the other Blasta bars with **Left/Right edge direction** use DaylightUI's own flip for both ends, so a flipped end gets DaylightUI's border and shadow. With an older DaylightUI, Blasta falls back to its previous way.
- Blasta's 11 bar animations (Frost, Arcane … By class) also show in DaylightUI 2.4.0's new bar animation choice for the experience and reputation bar.

# Blasta (DaylightUI Plugin) 2.3

## Windows

- **Cut corner on all windows** in **Blasta → Windows → General**: every DaylightUI window gets the same cut corner at the bottom right as the chat and the damage meter: character window, talents and spellbook, professions, social, group finder, mail, quest and talk window, vendor and trainer, bags and bank. The cut is a little larger than on the chat. The resize grip runs along the cut and stays clear of the window's buttons. Off by default.

## Bags

- Fixed: **B** could stop opening the bags until the next reload. If Blasta's filter bar or **Old quest items** ran into an error while the bag was being laid out, DaylightUI kept the unfinished, empty bag. Now DaylightUI lays the bag out on its own, the filter goes back to **All** and the error is reported once (BugSack, `/blasta report`).
- Category headings, stack counts, item borders and quest marks get the same protection: an error there no longer interrupts the bag.
- **Old quest items** opens the bag the same way DaylightUI does at the bank, without opening the game's bags, and only starts once the bag window is ready.

## Character window

- The same protection for **C**: an error in Blasta's character window additions can no longer keep the window from opening.
- Enchantments in the equipment list are shown in a soft enchanting gold, so they stand apart from item names and durability colors.
- In the equipment grid, an enchantment and the durability stay on one line. Without room, the durability is shortened to "Dur. 100%" ("Haltb." in German), then the enchantment ends in "..."; the durability itself is never cut, and the tooltip shows the full enchantment.

## Talents

- **Blasta talent layout (test)** in **Blasta → Windows → Talents**: talent icons at DaylightUI's own size on a shared Daylight background, the tree name with its icon over a thin line, and the point thresholds (0, 5, 10 …) beside the rows. Talents you can't pick yet (too few points in the tree, or the required talent missing) are gray, and show their colors while you hover them. A talent that becomes available fades from gray into its colors along with DaylightUI's wake animation, and a newly reached row lights up: its number glows in your accent color and a light runs once across the row. With DaylightUI's motion turned off, these switch at once. On by default; turn it off to get the previous view back. Only your own talent window changes; inspect and Legacy trees keep their look.
- `/blasta check` includes the talent layout.

## Loot feed

- **Coin color** in **Blasta → World → Loot → Blasta loot feed**: looted coins no longer always show a gold gradient. **Highest coin** (the new default) uses the highest coin looted: gold as soon as there is gold, silver for silver and copper, copper for copper alone. **All coins** blends from the highest coin looted to the lowest and skips coins at zero. **Always gold** keeps the previous look.
- The loot feed preview shows a copper, a silver and a gold row (2g 34s 56c for the whole gold to silver to copper gradient), so each coin color can be checked right away.

## Loot window

- The square one-pixel icon border no longer jumps between thicknesses when the skin resizes the icon or the window is scaled, and DaylightUI's round outline no longer flashes up for a frame when the loot list builds a new row.

## Tooltips

- Disenchanting materials (dusts, essences, shards and Nexus Crystal) show their auction price even if you haven't seen the item yet this session.

## Nameplates

- Nameplate debuffs keep Blasta's size. A debuff that appeared on a plate during a fight kept DaylightUI's size until the fight was over, and DaylightUI's refit after combat or a scale change also reset it. Blasta now sets its size in the same moment DaylightUI sizes the icon.

## Performance and maintenance

- **Buff reminders** only listen to aura changes on you and your party. Before, every aura change on every nameplate and raid member in range reached Blasta and was thrown away there, many times a second in a fight.
- Removed an unused aura preview, five unused helpers and a dozen unused local variables. Nothing you can see changes.

# Blasta (DaylightUI Plugin) 2.2

## Character sheet

- **Character sheet layout** chooses between **Classic**, with the equipment around the model, and the new **Equipment grid**. Existing profiles keep their earlier choice until you pick one.
- The equipment grid puts the model on the left, every equipment slot in the middle under **Armor**, **Jewelry** and **Weapons**, and the stats on the right. Each group ends with a single slot on the left (feet, neck, ranged), so the gaps line up. Shirt and tabard sit as icons below the model, and the window grows a little taller when the screen has room.
- Group headings use the same font, colors and one-pixel underline as the stat headings.
- Below the model, the average item level and the overall durability sit beside two icons, with tooltip labels. The item level icon is DaylightUI's own.
- **Show durability at or below** now works in the grid. With item names on, the durability percentage appears in the line under the name, after the enchantment if there is one. With icons only, a small dot on the icon marks worn gear.
- **Quality gradient style** offers **Automatic**, **Fade out** and **Cut corner**. Cut corner keeps a faint tint to the end and cuts only the lower corner away from the icon. Automatic uses Cut corner in the grid and Fade out in the classic layout.
- In English, the durability line reads "Durability 42%" instead of an internal text key.

## Training

- When several cities charge the same discounted price, the tooltip shows one line: **Same price everywhere** when no trainer city charges more, otherwise the cities by name. The lowest total at the bottom of the window follows the same rule.

## Bags

- New items stay in **Recent** for its full duration instead of going straight into Blasta's material groups, such as **Leather**. With **Also show new items in their group**, they appear in Recent and in their material group. With Recent turned off, Blasta sorts them directly as before.
- **Also show new items in their group** is translated into German.
- **Old quest items** filters the bag to quest items whose known quests are no longer in your quest log. Select a stack and click again to delete it. Requires QuestieDB. Quest starters, active quest items and locked or protected items are skipped, and everything is checked again right before deletion. Bag tooltips mark these items as **Related quest not in quest log**.

## Loot

- The square one-pixel loot icon border no longer falls back to the original frame when the skin rebuilds a loot row right after Blasta styles it.

## Info panel

- Money in narrow data texts drops copper, then silver, to fit, and shortens very large gold amounts only in the narrowest slots. The tooltip keeps the exact amount.

# Blasta (DaylightUI Plugin) 2.1.1

## Fixes

- Target outlines follow the left nameplate edge when Top corner projects or Bottom corner projects is selected, including after target updates and plate reuse.
- Preserve Glowey's Addon Skins settings across reloads. The legacy migration copies only Blasta-owned settings, keeps existing Blasta values, and leaves the Addon Skins profile intact. This prevents disabled Blizzard Auction House and Auctionator switches from being reset.

# Blasta (DaylightUI Plugin) 2.1

## Compatibility

- Blasta's AFK card follows the AFK screen position set in DaylightUI 2.2.6's Unlock mode.

## Tooltips

- Spell and equipment tooltips use a single compact facts row. Equipment shows armor class or weapon type, item level, and required level. Rings and trinkets use the type **Jewelry**. The slot and binding share one line above the strip.
- The equipment strip uses DaylightUI's quality color for item level and its category colors for armor and weapon types. Required character levels show in green when met and red when too high.
- Tooltip frames and facts strips have a slightly deeper bottom-right cut. The item strip has a continuous outline along the cut. The icon's quality border follows its own cut and aligns with the strip's left edge.
- Linked item comparisons use the rendered card widths to choose a side. When horizontal space is tight, comparison cards can stack vertically.
- Food, potions, and other items show the required level beside the item type when both fit.
- Profession tools and items without an equipment slot use the compact item header, with type and binding on one line and no equipment strip.

## Loot and inventory

- DaylightUI bags have separate font-size controls for category headings and their counters, and for the stack counts on item icons.
- An optional merchant shortcut sells eligible stacks from a category when you right-click its heading. It includes combined stacks and skips locked and protected items. The shortcut is off by default.
- Category sales use DaylightUI's coin formatting for their chat summary. A reporting error no longer interrupts cleanup or blocks the next sale.
- Category sales switch from the game's Buyback tab to the shop before selling. Items under **Recent** can be sold the same way. Shift-right-click still opens the Recent menu.

- When loot does not fit, **Make room for loot** slides out on the side with space and shares the loot window's frame. The drawer stays readable above the shared background, and closing it restores the standard loot window.
- The drawer shows sellable poor and common stacks that would make enough room, ordered by the vendor value of the whole stack. Hearthstones, quest items, and items with no vendor value are excluded. Stacks worth more than the loot are highlighted.
- **Replace** rechecks the selected stack and its destination, then deletes the stack and automatically attempts to take the loot as soon as space is confirmed. Blasta retries once if necessary. WoW can still require its own confirmation for certain items.
- Choose Blasta or Delete Cheapest Item per character from a DaylightUI dialog when both are installed. The choice is also available from **Loot** settings.
- Loot window icons can use a square one-pixel quality border or the original style. The square border is reapplied when WoW reuses a loot row and keeps the native quest indicator.
- Reuse one bag snapshot when comparing several loot items. Refresh the drawer on relevant bag or item-data changes and skip repeated layout updates.

## Icon feedback

- Aura reminder icons show a white outline on hover that follows the cut corner.
- Quest tracker item buttons show a hover outline and report recognized range, cooldown, or usability restrictions in the tooltip.

## Settings

- Under **World & moments**, **Loot** combines the loot window, bag space helper, loot rolls, and loot feed. **Chat** combines chat corners, the micro menu, and whisper windows, with selectable previews.
- Under **Info panel & buffs → Buffs**, the minimap aura corner option now sits with spacing and animation. Existing settings are retained and the overview links to their new locations.

# Blasta (DaylightUI Plugin) 2.0

## Tooltips

- Spell tooltips group cast time, cost, range, and cooldown into a compact strip, with the spell school near the title and the rank aligned with the title on the right.
- Tooltip icons have a small cut in the bottom-right corner. The border follows the cut and uses the item's quality color where applicable.
- Hold **Shift** over an item in your bags to see the vendor and auction values for the total quantity across your bag stacks. The price label shows the quantity, and bank items are excluded.
- Removed the auction price's **Seen … ago** line from Blasta item tooltips.

## Chat and damage meter

- Choose **Off**, **Bottom left**, or **Bottom right** for the chat and separate damage meter windows. Each has its own setting.
- The chat setting also styles Blasta's chat micro menu, whisper tiles, and whisper windows.
- The damage meter reserves space below its rows so the cut stays clear of progress bars, names, and amounts.

## Buffs and unit frames

- The minimap buff display offers optional cut-corner icons and even spacing between categories.
- Minimap buff and debuff slide animations are suppressed by default to avoid replaying on refreshes during looting and combat transitions. Restore them in Blasta's buff settings.
- Aura reminders offer a cut bottom-right corner.
- The friendly-target outline blends with Blasta's dispel highlight and gives the highlight priority when it appears.

## Settings

- **New in Blasta 2.0** links to the updated features. New settings are marked on their own pages.

# Blasta (DaylightUI Plugin) 1.9.8

## Spellbook training

- The **Training** tab in DaylightUI's spellbook now works without What's Training? installed. Blasta supplies the WoW: Forever data for all nine classes, including spell ranks, requirements, quest rewards, weapon skills, hunter pet abilities, and warlock grimoires. The bundled data includes its MIT license and source attribution.
- Training tooltips list discounted trainer factions together under **Training discounts**, directly below the regular cost. Equally cheap options are both marked. The prices are estimates based on your current reputation.
- The Training tab shows the lowest estimated total for a trainer faction that covers all currently learnable paid spells.
- When What's Training? is enabled, a DaylightUI dialog lets you choose which add-on supplies the Training tab for this character. Use `/blasta training` to change the choice later.

## Tooltips

- Tooltips opened by clicking a link in chat have a working close button on the Blasta panel.
- Blasta honors DaylightUI's **Spell and item IDs** setting for spells, buffs, and debuffs. The spell ID is shown once, even when Blasta's detail rows are hidden.

## Action bars

- Equipped items use the regular action bar border. The stock green outline stays hidden after equipment changes.

## Quest tracking

- An optional setting tracks quests in your current zone and frees slots by untracking quests elsewhere. Pinned quests and your priority quest are protected. Tracking waits until you land after a taxi ride or flight.

## Maintenance

- Removed two unused helpers and two legacy Lua files that were no longer loaded.

# Blasta (DaylightUI Plugin) 1.9.7

## Character window

- Fixed a Lua error when opening the character window with an empty equipment slot on DaylightUI 2.2.4, including when Blasta's character-window styling is disabled.
- Enchantment text uses DaylightUI's accent color when the old enchantment color is unavailable. Durability warnings retain their own colors.

## Loot feed

- Loot quantities and bag totals stay at their configured text size when stacks merge. The count has a sharper, higher-contrast style, and the bag total uses a valid color code.

# Blasta (DaylightUI Plugin) 1.9.6

## Nameplates

- Under **Blasta → Nameplates → Threat**, choose **Pull threshold**, **Relative threat**, or **Both threat values**. The pull percentage matches the target frame on your selected enemy. Relative threat can exceed 100%.
- **Threat state colors** color the number independently of the display mode. By default, green means you hold aggro, yellow warns of a possible change, and red means aggro is elsewhere. Unavailable states use a neutral tint. **Green while holding aggro** can swap green and red.
- Fixed the fitted debuff row spacing being deferred on live plates in combat. Live plates and the preview now use the same spacing calculation.

## Cast bars

- DaylightUI 2.2.2 and later draw channel ticks on your own cast bar. Enable them under **Unit frames → Player → Cast bar → Channel ticks**.
- Blasta still supplies tick markers for other unit cast bars and enemy nameplates. Older DaylightUI versions can still use Blasta's own player markers.

## Tooltips

- Item tooltips show each RestedXP guide once, even when its first entry carries the guide heading.
- Disenchant results show material prices and their expected value, using DaylightUI's remembered prices when Auctionator has none. If some material prices are missing, the total is labeled as a minimum.

- The Buff Reminder tooltip shows the rank the button casts.

## Character window

- Fixed a Lua error in equipment rows on DaylightUI versions that use the accent for enchantments.

Compatibility checks were run against DaylightUI 2.2.3.

# Blasta (DaylightUI Plugin) 1.9.5

## Nameplates

- Enable **Threat %** under **Blasta → Nameplates → Threat**. It is off by default and uses DaylightUI’s existing per-enemy threat number in a group or with a pet.
- Drag the number in Design mode. Its position, font and size are shared with DaylightUI’s nameplate settings.
- The optional color gradient runs from green at 0% through yellow to red at 100%. Tanks can reverse it to make 100% green.

## Fixes

- Blasta’s settings tabs wrap onto additional rows as the window narrows. The settings below move down to leave room for all tabs.
- The target-frame preview draws the spell name and remaining cast time in front of the cast bar without clipping them at the slide animation’s top edge.
- The red auto-attack flash follows slanted action buttons and fills square buttons all the way to their corners.

Compatibility checks were run against DaylightUI 2.2.1.

# Blasta (DaylightUI Plugin) 1.9.4

## Chat

- **Blasta Micro Menu** opens from the three dots in the chat header with a short slide and fade. It includes the World of Warcraft: Forever menu entries, their tooltips, and your current keybindings.
- Choose whether the menu opens above the left or right edge of the chat, or beside it on the right. The settings preview shows the selected position, and the top line follows DaylightUI's accent settings, including class colors.
- The micro menu is opt-in. While it is enabled, Blasta hides the standard menu. Turning Blasta's menu off restores the previous DaylightUI setting.
- **Whisper conversation from the chat's edge** now has an animated preview showing how the chat frame extends around the conversation.

## Flight timer

- **Land early** is a compact text action centered below the flight timer. The banner extends around it and keeps DaylightUI's background settings.
- When WoW offers early landing, the action can appear even if DaylightUI has no intermediate stop recorded. The separate WoW button is hidden while the integrated action takes over. The settings preview shows the new placement.

## Loot roll window

- The roll window now has the same cut bottom-right corner as Blasta's tooltips. The roll markers sit farther left to clear the corner.
- An optional square loot icon uses a one-pixel quality-colored border. The **Loot Roll Window** tab previews the corner, roll markers, and icon.

## Loss of control

- New layout with the remaining time inside a cut-corner effect icon and the effect name above a thin countdown line.
- Resize the indicator from **28 to 72 px**. The entire indicator stays centered on its mover, and the **Test** button runs a timed sample at the actual in-game position.
- The ring remains available. The settings preview shows one style at a time.

## Nameplates and tooltips

- Added a vertical spacing slider for nameplate debuff rows. **0** keeps automatic spacing, and the preview shows the gap when multiple rows are configured.
- Fixed duplicate quest progress on mob tooltips when the objective text already included the count. The progress appears once beside the drop chance.


# Blasta (DaylightUI Plugin) 1.9.3 — 2026-11-21

## Tooltips

- Quest-mob tooltips show your progress and the drop chance on the same row. Drop rates come from Questie when its drop-rate option is enabled, even if Questie’s own tooltips are turned off.
- Hold **Shift** to see party progress. Each identified player is listed once, and completed objectives are shown in green.
- Item tooltips show a colored **GS** label below the icon.
- Spell tooltips show the spell’s own cooldown and omit the global cooldown.
- Fixed a jump to the bottom-left corner at combat start when DaylightUI temporarily moves the original tooltip off-screen.
- Repeated tooltips reuse quest progress until the quest log changes.

## Professions

- The selected recipe’s **Profit** section can use saved Auctionator prices when DaylightUI has no price for an item. The section shows material costs, expected sale price, the auction house cut, and estimated net profit when prices are available.
- The recipe list keeps DaylightUI’s profit column visible with Blasta’s skill-up chance subtitle enabled.

## Chat

- Whisper buttons above the chat show full names and wrap as needed. Unread counts, pins, and click actions are preserved.
- The whisper layout avoids a second layout pass when a conversation opens above the chat.

## Unit frames

- **Level badge position:** DaylightUI handles the position and shows a single pair of offset sliders. Those same sliders also adjust the badge on the portrait ring when Blasta is active.

## Removed from the release package

- Retired code for Blasta’s old flight timer and its RestedXP Elegant skin. Both files were already outside the add-on’s load list.


# Blasta (DaylightUI Plugin) 1.9.2 — 2026-11-20

Made for DaylightUI 2.0. Checked against every DaylightUI 2.0 file Blasta works with: every Blasta part still finds what it hooks.

## Tooltips

- **The frame of DaylightUI's cards** — No colored frame all around anymore: DaylightUI's own tooltip border and background (its thickness and opacity settings), a colored light along the top (the item's quality, a player's class or reaction, a spell's school) and the cut bottom-right corner, like DaylightUI 2.0's rich tooltips.
- **DaylightUI's text colors** — The name and item level in the quality's light color; armor type, slot and binding in DaylightUI's colors (cloth, leather, mail, plate, weapons, jewelry…); a stat's number in its stat color with the word in DaylightUI's text color; armor, damage, speed and damage per second numbers in the accent; equip, use and enchantment effects in DaylightUI's green; damage and healing numbers in spell descriptions in their colors; stat changes in DaylightUI's green and red. A requirement you don't meet and armor or weapons you can't use stay red.
- **Placed like DaylightUI's tooltips** — The hidden game tooltip is now exactly the card's size and the card lies on it, as DaylightUI 2.0 does with its own cards. So DaylightUI places it: beside a recipe in the profession window instead of over the recipe list, turned to the other side where the screen runs out.
- **Comparison cards in a row** — Beside the main card, away from what you hover, on the side with room for all of them. They no longer slide over each other at the screen edge.
- **Soft fade out** — The Blasta card fades out like DaylightUI 2.0's tooltips, instead of DaylightUI's fading copy showing the hidden game tooltip for a moment. Not while a window just refills its tooltip, so the profession window no longer flickers.
- **Spell macros** on your action bars (a @mouseover heal, say) get Blasta's spell tooltip for the spell they cast. The current client already names a spell macro's spell on the button, which Blasta reads now; else it finds the spell through the macro or the tooltip's own lines.
- **Shadow damage and the other schools** — "Increases damage done by Shadow spells…" read as Spell Damage on German clients whose wording doesn't say "durch Schattenzauber". Blasta now finds the school anywhere in the line: +13 Schattenschaden, +20 Feuerschaden and so on.
- **Healing items** show healing and spell damage on their own lines ("+8 Healing", "+3 Spell Damage") instead of one spell power value.
- **One card at a time** — DaylightUI 2.0's rich cards stay off while Blasta's tooltip style is on.
- **Buff tooltip** — Blasta's card also covers DaylightUI's own buff tooltip. The aura icons on unit frames, nameplates and beside the minimap show the client's own tooltip, which no addon can reach.

## Character window

- **Item level text size** — The item level on the equipment icons has its own size (6–20). **Blasta → Windows → Character window**.
- **No needless second line for item names** — A name just a little too long for the room beside its icon stays on one line and reaches a bit further toward the model instead of breaking.

## Talents

- **Talent rows with their points** — Each row of a talent tree shows how many points in that tree it takes (0, 5, 10 …) on its left, with a band across the tree: reached rows normal, the next row in your accent color, the rest dimmed. Under each tree's name: how many more points open the next row ("3 more to open row 6"). Also in the inspect window.

## Chat

- **Whisper conversation from the chat's edge** — A whisper conversation opened beside the chat slides out as part of it, the way DaylightUI's damage meter slides out of the minimap. On by default: **Blasta → World & moments → Whisper conversation**.

## Nameplates

- **Cast bar text like your own cast bar** — On enemy cast bars the spell name and the cast time each get a text size and can each be moved. **Cast bar height** is now also on Blasta's cast bar tab. All of it shows in the options preview. **Blasta → Nameplates → Cast bar**.

## Experience bar

- **Border, corners and shadow are DaylightUI's** — DaylightUI gives the experience bar its own border, corners and shadow (**Info panel → Experience bar → Own border and shadow**). A border or shape you had set in Blasta moves over once. Blasta's slanted ends, text positions and gain effects stay.

## Crowd control alert

- **Icon fills the ring** up to its inner edge.
- **Nothing jumps at the end** — Ring and text fade out where they are.

## Profession window

- **Tidier Learnable header** — Just how many you can learn now; the sort link is one word, **Category** or **Skill**, and no longer runs into the title.

## Fixed

- **Nameplate aura heights** no longer fall back to DaylightUI's size now and then.
- **Recipes no longer stay red in the bags after a skill-up.**
- **Options messages** — Blasta's pages no longer report "missing label" or "no default for mapTravelRoutes".
- **Moving the time on nameplate cast bars** no longer causes an error on enemy plates ("Can't measure restricted regions").

## Removed (DaylightUI has them now)

- **Tooltip border thickness** — DaylightUI 2.0 has its own (Tooltips → Look). Your value was stored under the same name, so it stays.
- **Shorten nameplate names** — DaylightUI shortens long nameplate names to initials itself (Nameplates → Name → Shorten long names). If Blasta's switch was on, DaylightUI's is turned on once. Blasta's abbreviated target names on the target frame stay.
- **Flight timer extras** — DaylightUI's flight timer is a banner that floats over the world with your route; Blasta's options for the old bar had nothing left to work on.
- **Old 1.9.5 outline code** — DaylightUI draws thin outlines again.
- **Old files Blasta no longer loaded** — The former skins of other addons and the old RXP extras.


# Blasta (DaylightUI Plugin) 1.9.1 — 2026-11-19

Made for DaylightUI 1.9.5. Every Blasta setting still works with it.

## Profession window

- **Professions panel** — A column on the right of DaylightUI's profession window, part of the same window: every profession you know as a card with its icon, skill and maximum, a bar (orange at the rank's limit, green when maxed) and what's next, under Primary and Secondary. Click a card to switch to that profession; hover it for details. The profession tabs above the list are hidden while the panel is on. **Blasta → Windows → Professions panel**.
- **Learnable recipes** — Recipes you could learn now or soon show at the bottom of the recipe list, in DaylightUI's own style: names colored by how likely they give a skill point (orange, yellow, green, gray), with the skill needed, where to learn them (trainer, vendor, drop, quest) and what's still missing. Click one for its requirements, skill range and materials. Sort them by **skill** or **category** with the link above the group. No separate trainer window needed. Recipe data from [WhatsTraining](https://github.com/fusionpit/WhatsTraining) (MIT, see THIRD-PARTY.md).

## Nameplates

- **Fit debuffs to the nameplate** — Set how many debuffs per row and how many rows (1–3). Your debuff size stays; only when a full row would stick out past the health bar do the icons shrink until it fits exactly edge to edge. Replaces DaylightUI's *Max debuffs shown* while on. **Blasta → Nameplates → Nameplate auras**.
- **Right edge direction** — The right end of enemy nameplates can now lean the other way too: **Top corner projects** (DaylightUI's look), **Bottom corner projects** or **Straight**. The fill, heal and shield bars, the target glow and a cast bar set to follow the plate turn with it. Next to **Left edge direction** in **Blasta → Nameplates**.
- **Lines inside the bar follow the left end** — The fill's edge, heals and shields, the DoT veil, the execute line and Shadow Word: Death's mark now always lean like the plate's left end, so the plate keeps its perspective whichever way the right end leans. With a straight left end they follow the right end; with a straight right end they stay upright.
- **Cast bar flush under the plate** — The cast bar's top edge now runs exactly along the health bar's bottom edge, corner to corner, and its ends continue the plate's lean. It no longer shrinks or shifts in the options preview.
- **Elite dragon on the turned-over corner** — With the right end turned over, the elite dragon moves in to the bar's top-right corner.
- **Centered on the bar as drawn** — The name, debuffs and other pieces centered above or below the bar now sit on the middle of the bar's slanted edge, not the middle of its frame, so they no longer lean a few pixels left with Blasta's left edge shapes.

## Look

- **Crowd control alert as a ring** — When you're stunned, feared or silenced, the alert shows the icon round in the middle with the time on it, a ring around it that runs down with the effect, and the name underneath. Works in combat too. Icon size, ring thickness, color (accent, class or your own), track opacity, the name and the text sizes of name and time are adjustable, with a live preview above the settings. Off by default: **Blasta → World & moments → Crowd control alert**.
- **DaylightUI's new font rendering** — Blasta's own texts (bag item levels, aura bar texts and the like) use DaylightUI 1.9.5's new outline (SLUG) like the rest of the interface, with the old outline as a fallback.

## Performance

- **Nameplate auras** — With all of Blasta's nameplate aura options at DaylightUI's look (no square icons, thin borders, own heights or fitted debuffs), Blasta no longer looks at nameplate aura changes at all. In a fight these come many times a second for every plate in range.
- **Dispel highlight** — Without motion the highlight is checked five times a second instead of forty; with motion it pulses as smoothly as before.

## Fixed
- **AFK screen clock** — The big clock no longer runs its digits into each other: with DaylightUI 1.9.5's new outline it grew too thick at that size, so the clock now has a soft shadow instead.
- **Channel tick markers on your cast bar** — DaylightUI 1.9.5 moved your cast bar's card to the player frame's page, so Blasta's **Channel tick markers** switch had vanished there. It's back (Unit frames → Player → Cast bar), and Blasta now finds the card wherever DaylightUI puts it. A switch you had on stays on.

## Party frames

- **Dispel highlight with a detached power bar** — On party frames whose power bar (or portrait) sits apart from the frame, the dispel highlight now covers just the frame again instead of reaching into the gap.

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
