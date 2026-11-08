class_name ExposureSystem
extends RefCounted
## Stub (M1-07): plugs into SimWorld.step() in the order fixed by the M1 shared contracts.

# The world parameter is unused until the owning task implements this system.
@warning_ignore("unused_parameter")
# gdlint: ignore=unused-argument
static func step(world: SimWorld) -> void:
	pass
