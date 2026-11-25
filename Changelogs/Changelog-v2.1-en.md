# Blasta (DaylightUI Plugin) 2.1

## Tooltips

- Spell and equipment tooltips use a single compact facts row. Equipment shows armor class or weapon type, item level, and required level. Rings and trinkets use the type **Jewelry**. The slot and binding share one line above the strip.
- The equipment strip uses DaylightUI's quality color for item level and its category colors for armor and weapon types. Unmet level requirements stay red.
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
