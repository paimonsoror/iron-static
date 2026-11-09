# FAQ

## About the game

??? question "What is IRON STATIC?"
    An original portrait idle-defense game for Android. You play Cinder, a reprogrammed combat cyborg bolted to the last working relay of a dead city. Machine swarms attack from every side; Cinder fires on its own and you buy the upgrades. See the [home page](index.md).

??? question "Can I play it now?"
    Not publicly. The game is in development and has not been released. This codex describes the current build and what is planned. See [Development status](status.md).

??? question "Which platforms?"
    Android, in portrait, built to be played one-handed. Wide layouts for foldable and tablet screens are built in.

??? question "Do I need to aim or tap constantly?"
    No. Cinder aims and fires itself, and the battlefield never needs a tap. Your decisions are what to buy and when. Later, a few optional taps (salvage caches, overdrive) will give active players something extra.

## Money and ads

??? question "Is it free to play?"
    That is the plan. The design commits to rewarded, opt-in ads only, with no forced ads, no interstitials, and nothing during a run. Purchases are for convenience and time, not exclusive power. Billing, ads and the store are **Planned** (milestone M7) and are not in the build yet. See [Economy](systems/economy.md).

??? question "Can I buy power?"
    The design says no. Flux (the premium-adjacent currency) buys time, convenience slots and firmware picks; it cannot buy any stat, tournament entry, or data and cipher directly. Chance-based pulls disclose their odds.

??? question "How many currencies are there?"
    Five at most: scrap, data, flux, cipher and merit. Only scrap and data exist in the build today.

## Playing

??? question "What happens when Cinder dies?"
    The deployment ends. You keep the data you earned (banked in full), lose your scrap and run upgrades, and can redeploy at once. Best wave is kept. See [The run loop](systems/run-loop.md).

??? question "What are TIMED and PURGE?"
    Two wave modes you pick on Home. TIMED runs each wave on a 24-second clock and leftover enemies carry over. PURGE ends a wave when every enemy in it is destroyed, with a 60-second limit. PURGE unlocks when your best TIMED wave reaches 20, and each mode keeps its own best wave. See [Wave modes](systems/run-loop.md#wave-modes).
    <!-- numbers: data/wave_modes.csv -->

??? question "Does my progress save?"
    Yes. Your profile saves after every deployment and every Foundry purchase, and when the app goes to the background. If the app is killed mid-run, CONTINUE on the title screen resumes it. Saves are crash-safe and backed up. See [Saving and resuming](systems/save-resume.md).

??? question "Does the game run while the app is closed?"
    A deployment pauses when you leave the app. A separate, capped offline earning system called Standby Patrol is **Planned**; it will give a fraction of your data rate and nothing else. See [Lab, Arsenal and Standby Patrol](systems/meta-planned.md#standby-patrol).

??? question "What does the back gesture do?"
    It closes an open panel, then pauses the battle, then quits. See [Controls](systems/controls.md).

??? question "Why does my upgrade list show only a few rows?"
    Rows unlock by your best wave, and locked rows stay hidden so the screen is not cluttered. A line at the bottom shows the next unlock.

??? question "Why did I get stronger after dying?"
    That is the design. Data from each deployment buys permanent upgrades in the Foundry, so every run starts further ahead.

??? question "Which frame should I pick?"
    VANGUARD is the baseline, and the only one you start with; BULWARK unlocks at best wave 8 and STRIKER at 15. BULWARK is for outlasting with minimal buying; STRIKER is for active buying and fast kills. They are balanced to be close on average. See [Frames](characters/frames.md).

??? question "Are there human enemies?"
    No. Every enemy is a machine and you never see a person. The game is rated for machine-versus-machine violence with no gore.

## The story

??? question "Who or what is Cinder?"
    A Warden-class cybernetic organism, serial ASH-07, reprogrammed by the Accord hacker team Lantern Cell with a single directive: hold the Relay. See [Cinder and the Wardens](lore/cinder-origin.md).

??? question "Does the story ever end?"
    Not at launch. Clearing sector 12 shows one message and sets up further sectors. See [The world](lore/world.md).

??? question "Is the lore final?"
    The published lore is canon: the creator approved the extensions beyond the design documents on 2026-11-09. Future updates may add to it.

## Development

??? question "Where can I follow progress?"
    On the [Development status](status.md) page.

## Privacy

??? question "What data does the game collect?"
    None in the beta. Progress is saved on your device only. Read the [privacy policy](privacy.md).
