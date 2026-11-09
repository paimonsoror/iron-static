# Frames

A **frame** is the chassis configuration Cinder deploys in. Frames are **sidegrades, not upgrades**: each is stronger in one way and weaker in another, and the totals are balanced to stay comparable. A player may prefer a different frame depending on the situation.

!!! planned "Planned: milestone M3"
    The three frames are built into the simulation and their data, but the frame bay screen that lets you choose one is still in production. Today every deployment uses VANGUARD. The two further frames are Planned for milestone M6.

## The rules

- **Unlocked by play, never sold.** A frame unlocks when your best wave in Sector 1 reaches its threshold. A new profile has only VANGUARD.
- A frame's modifiers multiply Cinder's base stats first, then [Foundry](../systems/foundry.md) bonuses apply on top. The Foundry is shared: a Foundry level helps every frame.
- You choose the frame **between** deployments, in the frame bay. It is fixed for the whole deployment and recorded with it.
- Locked frames are shown in the bay with their goal (for example "REACH WAVE 8") rather than hidden.
- Changing frame costs nothing and refunds nothing.
- When a run raises your best wave past a threshold, the results screen shows a "FRAME UNLOCKED" line.

<div class="frames" markdown>
<figure markdown>
![VANGUARD on its ridge at dusk](../assets/img/frame_vanguard.jpg)
<figcaption>VANGUARD</figcaption>
</figure>
<figure markdown>
![BULWARK with a broad shoulder block and bronze trim](../assets/img/frame_bulwark.jpg)
<figcaption>BULWARK</figcaption>
</figure>
<figure markdown>
![STRIKER with slim vented plates](../assets/img/frame_striker.jpg)
<figcaption>STRIKER</figcaption>
</figure>
</div>

## The frames

| Frame | Role | Unlock (best Sector 1 wave) | Passive | Status |
|---|---|---|---|---|
| **VANGUARD** | Balanced baseline | Start | None | Simulation ready, <span class="badge planned">Planned M3</span> screen |
| **BULWARK** | Tank | 8 | Bastion | Simulation ready, <span class="badge planned">Planned M3</span> screen |
| **STRIKER** | Glass cannon | 15 | Overclock | Simulation ready, <span class="badge planned">Planned M3</span> screen |
| **SALVAGER** | Economy | 25 (placeholder) | Scrap Tithe | <span class="badge planned">Planned M6</span> |
| **LONGSHOT** | Sniper | 40 (placeholder) | First Sight | <span class="badge planned">Planned M6</span> |

### VANGUARD

The reference frame. Every multiplier is x1.0 and nothing is added, so balance for all other frames is measured against it. Today's build plays as VANGUARD. Its plates are the gunmetal and ceramic ones shown on the [Cinder](cinder.md) page.

### BULWARK

*Outlasts. Slow to kill.* A wider, heavier plate set with a broad shoulder block and bronze trim.

| Stat | Change |
|---|---|
| Hull integrity | x1.6 |
| Plating | +10 percent starting damage reduction |
| Nano repair | x1.3 |
| Cycle rate | x0.75 (slower fire) |
| Optic range | x0.92 |

**Bastion:** no single hit deals more than 20 percent of Cinder's maximum hull. A huge boss blow cannot take Cinder from healthy to dead in one hit.

It is strongest when you cannot, or do not want to, buy anything: its starting stats carry it.

### STRIKER

*Fast and fragile.* A slim, vented plate set with a twin emitter and white-hot trim.

| Stat | Change |
|---|---|
| Hull integrity | x0.65 |
| Nano repair | x0.7 |
| Laser output | x0.9 |
| Crit chance | +3 points |
| Cycle rate | x1.4 (faster fire, plus Overclock) |

**Overclock:** each kill adds +1 percent fire rate until the wave ends, up to +20 percent. The bonus resets at the start of the next wave.

It is strongest when you are actively buying upgrades and killing fast.

### SALVAGER <span class="badge planned">Planned M6</span>

*Slower kills, better income.* Scrap income x1.25, data income x1.10, laser output x0.85. **Scrap Tithe:** heavy kills (walkers, lancers, bosses) drop bonus scrap; exact numbers arrive with the frame.

### LONGSHOT <span class="badge planned">Planned M6</span>

*Reach and burst, slow cadence.* Optic range x1.33, laser output x1.4, cycle rate x0.6, with a doubled crit multiplier step. **First Sight:** the first shot at a newly acquired target always crits.

!!! note "About the numbers"
    Frame values come from the game's data table as of 2026-11-08 and are first-pass. The balance goal is that each frame's average death wave on a fresh profile lands within 10 percent of VANGUARD's, and that BULWARK beats VANGUARD when nothing is bought while STRIKER beats it with active buying. Expect small changes.

## Looks

Each frame is a variant of the same layered Cinder rig, so every frame also burns through the four [exposure bands](../systems/skin-burn.md). From top to bottom the rows below are VANGUARD, BULWARK and STRIKER; left to right, intact to white-hot.

![Three frames across four exposure bands](../assets/img/frames_bands.png)

Back to [Characters](index.md).
