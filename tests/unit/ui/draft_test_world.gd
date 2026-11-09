class_name DraftTestWorld
extends RefCounted
## Test helper (M4-16): a controller whose run reached the wave-10 draft with the stopgap off, and the offers set by
## patch id so a test can show standard and gamble cards without depending on the seed.


static func controller_with_draft(offer_ids: Array[String], picks: Dictionary[String, int] = {}) -> RunController:
	var c := RunController.new()
	c.last_run_path = "user://runs/test_draft_ui.json"
	c.auto_pick_draft = false
	@warning_ignore("return_value_discarded")
	c.start_run(7, true)
	@warning_ignore("return_value_discarded")
	c.fast_forward(11 * Ticks.WAVE_TICKS)
	var w: SimWorld = c.world
	var ids: Array[String] = []
	for d: PatchDef in w.config.patches:
		ids.append(d.id)
	var offers := PackedInt32Array()
	for id: String in offer_ids:
		offers.append(ids.find(id))
	w.draft.offers = offers
	for id: String in picks:
		for n: int in picks[id]:
			@warning_ignore("return_value_discarded")
			w.patches.add(ids.find(id))
	return c
