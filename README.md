# Blasta (DaylightUI Plugin)
A quality-of-life plugin for DaylightUI in World of Warcraft. Blasta is not part of DaylightUI itself: please report Blasta bugs here, not to the DaylightUI team.


## Contributions

Pull requests, bug reports, and suggestions are always welcome!

Please keep in mind that Blasta is my first addon project and I'm still learning. I also use AI assistance during development, so I may need additional explanations or time to review certain changes.

I appreciate every contribution, but I may decline PRs that I can't confidently review, test, or maintain.

## Changelog

See the [full changelog](Changelogs/CHANGELOG.md) and the [2.4 release notes](Changelogs/Changelog-v2.4-en.md).

## Old quest items

Click the quest icon in the bag toolbar, or use **Bags > Old quest items > Review quest items**. QuestieDB must be enabled. This temporarily filters the existing bag to known quest-class items with no related quest in the current quest log. Click an item to select its actual stack (marked red), then click it again to confirm deletion. A rapid double-click does not confirm. The game may require its own confirmation. Click the quest icon again or close the bag to leave cleanup mode; entering combat also ends the mode.

Quest starters, active quest items, locked/protected items, and unknown associations are skipped. An absent quest does not mean an item is no longer useful: you may need it for a future or abandoned quest. Eligible items show **Related quest not in quest log** and known quest names in the tooltip. In cleanup mode, the tooltip also explains the next click.

## Refined character sheet

With Blasta Character Panel enabled, choose **Character sheet layout: Classic / Equipment grid**. Classic restores the previous equipment around the model. The grid places the model left, equipment middle and native stats right. All 19 equipment slots remain separately usable without equipment scrolling.

Armor, Jewelry and Weapons follow Daylight's native header font, color settings and underlines. There are no item-row separators or additional dark background; the window keeps its normal Daylight appearance and quality gradients. The necklace uses one normal-width slot, rings/trinkets have their own paired rows, and shirt/tabard are two icon-only cosmetic slots under the model. Main/offhand get one weapon row; ranged gets a second row with native ammo support.

In the grid, durability shows a small warning dot only at or below the repair-warning threshold. Ordinary wear has no extra indicator, bar or percentage badge. The exact durability remains in the game tooltip; enchant text stays beside the item. Classic keeps the previous durability text. Health and resources appear as normal rows under Attributes. The complete native stat list has no role tabs or resource bars; Attributes aligns with Armor. Centered item-level and durability icons with tooltip labels sit beneath the model. Native model controls, item tooltips, equipment swapping and equipment sets remain intact. Existing layout and appearance preferences are preserved.

## Talent layout test

Under Blasta → Windows → Talents, toggle **Enable Blasta talent layout (test)**. The test starts enabled and uses a shared Daylight surface, larger square icons, character-style headings, aligned rank badges, compact round specialization icons without extra borders, native animated prerequisite arrows and native rank-progress frames. All talent data and actions remain native. Turn it off to restore the previous appearance; Inspect and Legacy trees keep their existing layout.
