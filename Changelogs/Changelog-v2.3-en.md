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
