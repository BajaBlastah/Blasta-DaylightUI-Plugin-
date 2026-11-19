# Blasta (DaylightUI Plugin) 1.9.0

**Two big changes, so nothing gets confusing:**

1. **New name:** the plugin is now called **Blasta (DaylightUI Plugin)**. Before it was "Daylight Blasta".
2. **New menu:** all Blasta settings moved out of DaylightUI's pages into **Blasta's own menu** (type **/blasta**).

Blasta is a plugin by its own author and **not part of DaylightUI**. Please report Blasta bugs to Blasta (`/blasta report`), not to the DaylightUI team. Made for DaylightUI 1.9.4.

## Blasta's own menu
- **Everything in one place:** ten pages: Overview, Unit frames, Auras & DoTs, Nameplates, Action bars, Info panel & buffs, Tooltips & money, Windows, World & moments, General. Long pages have tabs.
- **DaylightUI's pages show only DaylightUI** again: no Blasta rows, badges or notes in them.
- **Short help on every tab** (German or English), plus buttons that open the window a tab changes.
- **Tall tooltip preview** in a column inside the options window: item, recipe, quest item, your own item, spell, buff, player, enemy and quest. Click a part to jump to its setting.
- **What's new** on the Overview, with a button to each new setting.
- **Reset this tab** at the end of every tab.
- **Search** in DaylightUI's options finds Blasta's rows properly.
- **Live previews with Design mode** on the unit frame and nameplate tabs: drag Blasta's parts, like the leader crown or the PvP badge, straight into place.
- **Clearer names**, e.g. "Flight & breath bars" for the flight master bar and the breath and fatigue bars.
- **Every setting keeps its value.**

## New
- **Interrupt hint:** an enemy's cast bar lights up while you can interrupt it right now (interruptible cast, your interrupt ready). Off by default, under Blasta → Nameplates.
- **Dispel highlight fits your class:** only what you can remove (now on by default), and only while you can cast your dispel.
- **More to drag in Design mode:** the raid marker on target and focus, and the time on nameplate cast bars.
- **Health and power bars** on top of the stats in the character window.
- **Compatibility check:** after a DaylightUI update Blasta tells you once if one of its parts can't run. `/blasta check` lists it.

## Fixed
- **Finisher damage color** works again with DaylightUI 1.9.4.
- **Interrupted cast bars** with Blasta's own right edge break along that edge.

## Bar animations
- Blasta's animations (Frost, Arcane, Holy, Nature, Shadowflame, Lava, Radiance, Wild, Storm, Poison, By class) now have their own **Blasta animation** choice on each bar's card in Blasta's menu, instead of sitting in DaylightUI's list. A bar that already wore one keeps it.

## Action bars
- Half-pixel button sizes and spacing down to −10 are now Blasta's own sliders (Action bars → Bars).

## Removed, because DaylightUI 1.9.4 does it itself
- **Zone levels on the world map:** now DaylightUI's own (Game window skins → World map → Zone levels).
- **Group finder side by side:** DaylightUI now shows groups and solo players side by side in a wide window. Blasta's filters, several dungeons, level ranges and one-click applying stay.
