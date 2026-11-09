# Settings and accessibility

## Settings

<span class="badge live">Implemented</span> The **Settings screen**, reachable from the title and from Home, with version number at the bottom. Further options are <span class="badge planned">Planned M4</span>.

| Setting | Options | Default | Status |
|---|---|---|---|
| Music volume | Slider | Set by the game | <span class="badge live">Implemented</span> |
| Sound (effects) volume | Slider | Set by the game | <span class="badge live">Implemented</span> |
| Mute | On or off | Off | <span class="badge live">Implemented</span> |
| Reduce motion | On or off | Off | <span class="badge live">Implemented</span> |
| Screen shake | Off, Low, Normal | Low | <span class="badge live">Implemented</span> |
| Scanlines | Off, Low, Normal | Normal | <span class="badge live">Implemented</span> |
| Number format | Short, Scientific, Engineering | Short | <span class="badge live">Implemented</span> |
| Frame rate cap | 30 or 60 | 60 | <span class="badge live">Implemented</span> |
| Reset profile (Settings > Data) | Behind a double confirmation | | <span class="badge live">Implemented</span> |

Settings are saved with your profile and are **kept when you start a new game or reset your profile**, because they describe your device, not your progress. A setting forced by a debug launch option is marked "OVERRIDDEN THIS SESSION".

**Reset profile** asks "RESET YOUR PROFILE? ALL PROGRESS IS LOST.", then asks again with the amount of data and the best wave you are about to lose. Your old save files are renamed, not deleted, and you return to the title screen.

!!! note "Quality tiers"
    The quality tier (HIGH, MID, LOW) is chosen automatically and drops effects in a fixed order if the frame rate suffers. It is not a setting you pick.

## Accessibility

What is designed in:

- **Touch targets** are large: primary targets at least 56 dp and secondary at least 48 dp; body text at least 14 sp. <span class="badge live">Implemented</span>
- **Safe areas:** notches, cutouts and gesture bars are respected. <span class="badge live">Implemented</span>
- **Wide layout:** on tablets and foldable inner screens the upgrade panel docks to the side. <span class="badge live">Implemented</span>
- **Shape first, color second:** every enemy is identifiable by silhouette, so color alone never carries meaning. <span class="badge live">Implemented</span>
- **Reduce motion** disables scanlines, vignette pulse and screen shake, and on the title screen stops drift and the logo shimmer. <span class="badge live">Implemented</span>
- **Shake is never tied to routine events** and slow-motion occurs only on a boss or Cinder death, and is presentation-only.
- **Colorblind palettes** (deuteranopia, protanopia, tritanopia), **high-contrast mode**, **left-handed mode** (mirrors the panel's small buttons), **haptics** sliders, battery saver and a keep-screen-on option: <span class="badge planned">Planned M4</span>
- **In-game explanations:** every upgrade shows its formula and the planned Intel view shows enemy statistics, so nothing is hidden behind a wiki. <span class="badge live">Implemented</span> tooltips; Intel <span class="badge planned">Planned M4</span>

## Haptics <span class="badge planned">Planned M4</span>

A short tick on purchase, a medium pulse on boss spawn and a long one on death. Off by default for small events.

Next: [Controls](controls.md).
