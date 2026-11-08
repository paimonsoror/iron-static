# V1-13 particle spike

Decision: GPU-side integration in the vertex shader (`assets/shaders/particle_ring.gdshader`), CPU writes a particle once at spawn.

Finding (desktop GL 3.3 Compatibility, same code path as Android GLES3): instance COLOR and CUSTOM data arrive in `vertex()` as 16-bit halves. A packed 24-bit value (rgb, velocity) lost its low bits (first try, particles flew off-screen). Only the instance transform stays float32. Fix: origin in the transform, everything else as integers <= 2047 (exact in a half) split over the 8 half slots; layout in `src/view/particle_pack.gd` and the shader header. Sim time is a wrapping 32 s clock (birth in 1/64 s units), expired slots are cleared every 8 s so nothing revives. Rotation, spin, drag and align-to-velocity are per-kind shader tables plus a hash of INSTANCE_ID (no bits spent). No CPU fallback was needed.

Draw calls: 2 MultiMeshInstance2D (additive + alpha smoke, same shader with `blend_mix` swapped in at setup).

Desktop timing (Intel Iris Plus, `FxSpawner.last_update_usec` = events + spawning + upload, 240 frames, 400 live particles reached):
- idle (band 3 embers only): 0.08 ms
- 1 kill + 3 hits per frame: 0.32 ms
- 4 kills + 6 hits per frame (heavy): 0.54 ms
- 16 kills + 10 hits per frame (saturating, per-frame budget caps it): 1.2 ms
Per-frame cost is spawn-only; the live particle count adds nothing on the CPU. Phone numbers are for V1-20/V1-21.

Captures: `V1-13_kill_burst.png`, `V1-13_burst_seq_1..3.png` (ages 0.07, 0.13, 0.33 s), `V1-13_boss_death.png`, `V1-13_embers_b2.png`, `V1-13_crowd40.png`, `V1-13_crowd165.png` (1080x2400 desktop, `build/capture_fx.gd`).
