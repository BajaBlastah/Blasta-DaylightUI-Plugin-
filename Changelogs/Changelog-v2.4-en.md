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
