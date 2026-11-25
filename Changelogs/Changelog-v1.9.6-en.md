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
