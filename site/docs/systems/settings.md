# Settings and accessibility

## Settings

The settings model is built; the **Settings screen** is <span class="badge planned">Planned M3</span> (reachable from the title and Home), with further options in M4.

| Setting | Options | Default | Status |
|---|---|---|---|
| Music volume | Slider | Set by the game | Model built |
| Sound (effects) volume | Slider | Set by the game | Model built |
| Mute | On or off | Off | Model built |
| Reduce motion | On or off | Off | Model built |
| Screen shake | Off, Low, Normal | Low | Model built |
| Scanlines | Off, Low, Normal | Normal | Model built |
| Number format | Short, Scientific, Engineering | Short | Model built |
| Frame rate cap | 30 or 60 | 60 | Model built |
| Reset profile (Settings > Data) | Behind a double confirmation | | <span class="badge planned">Planned M3</span> |

Settings are saved with your profile and are **kept when you start a new game**, because they describe your device, not your progress.

!!! note "What works today"
    The in-run build already honors the underlying switches: screen shake can be off, low or normal, and reduced-motion and quality tiers exist in the view layer. They are controlled by debug launch options until the settings screen lands. The quality tier (HIGH, MID, LOW) is chosen automatically and drops effects in a fixed order if the frame rate suffers.

## Accessibility

What is designed in:

- **Touch targets** are large: primary targets at least 56 dp and secondary at least 48 dp; body text at least 14 sp. <span class="badge live">Implemented</span>
- **Safe areas:** notches, cutouts and gesture bars are respected. <span class="badge live">Implemented</span>
- **Wide layout:** on tablets and foldable inner screens the upgrade panel docks to the side. <span class="badge live">Implemented</span>
- **Shape first, color second:** every enemy is identifiable by silhouette, so color alone never carries meaning. <span class="badge live">Implemented</span>
- **Reduce motion** disables scanlines, vignette pulse and screen shake, and on the title screen stops drift and the logo shimmer. Model built; screen <span class="badge planned">Planned M3</span>
- **Shake is never tied to routine events** and slow-motion occurs only on a boss or Cinder death, and is presentation-only.
- **Colorblind palettes** (deuteranopia, protanopia, tritanopia), **high-contrast mode**, **left-handed mode** (mirrors the panel's small buttons), **haptics** sliders, battery saver and a keep-screen-on option: <span class="badge planned">Planned M4</span>
- **In-game explanations:** every upgrade shows its formula and the planned Intel view shows enemy statistics, so nothing is hidden behind a wiki. <span class="badge live">Implemented</span> tooltips; Intel <span class="badge planned">Planned M4</span>

## Haptics <span class="badge planned">Planned M4</span>

A short tick on purchase, a medium pulse on boss spawn and a long one on death. Off by default for small events.

Next: [Controls](controls.md).
