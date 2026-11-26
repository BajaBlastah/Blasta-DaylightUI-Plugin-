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
