class_name FrameBayModel
extends RefCounted
## Pure texts and numbers of the frame bay (M3-29), derived from `FrameCard` (built by `FrameRules.cards`).
## Nothing here touches nodes or `Game`; all text goes through `Strings`.

## What the primary button does for a card: locked = deny, SELECT = select the frame, CONFIRM = the frame is
## already selected, so the button continues the flow.
enum Action { LOCKED, SELECT, CONFIRM }

## A bar is full at this percent change.
const BAR_FULL_PCT: float = 100.0
## Label key per FrameCard.STAT_KEYS entry (full literal keys so the string-key scan can verify them).
const STAT_LABEL_KEYS: Dictionary = {
	"hull": "frame.stat.hull",
	"rate": "frame.stat.rate",
	"damage": "frame.stat.damage",
	"range": "frame.stat.range",
	"crit": "frame.stat.crit",
	"repair": "frame.stat.repair",
}


## Signed whole percent: "+60%", "-25%", "0%" (ASCII minus).
static func delta_text(pct: float) -> String:
	var n: int = roundi(pct)
	if n > 0:
		return "+%d%%" % n
	if n < 0:
		return "-%d%%" % -n
	return "0%"


## 1 better, -1 worse, 0 equal (after rounding to a whole percent).
static func sign_of(pct: float) -> int:
	return signi(roundi(pct))


## Bar fill fraction, -1.0 .. 1.0.
static func bar_fraction(pct: float) -> float:
	return clampf(pct / BAR_FULL_PCT, -1.0, 1.0)


static func stat_label(key: String) -> String:
	return Strings.get_text(str(STAT_LABEL_KEYS.get(key, "")))


## "HULL +60%".
static func row_text(card: FrameCard, key: String) -> String:
	return "%s %s" % [stat_label(key), delta_text(card.delta(key))]


## "REACH WAVE 8" ("" for an unlocked frame).
static func lock_text(card: FrameCard) -> String:
	if card.condition_key.is_empty():
		return ""
	return Strings.fill1(card.condition_key, "n", str(card.unlock_best_wave))


## "BEST W5" ("" for an unlocked frame).
static func progress_text(card: FrameCard) -> String:
	if card.progress_key.is_empty():
		return ""
	return Strings.fill1(card.progress_key, "n", str(card.best_wave))


## Fraction of the unlock threshold reached, 0..1 (1 for an unlocked frame).
static func progress_fraction(card: FrameCard) -> float:
	if not card.locked or card.unlock_best_wave <= 0:
		return 1.0
	return clampf(float(card.best_wave) / float(card.unlock_best_wave), 0.0, 1.0)


## "PR 41".
static func pr_text(card: FrameCard) -> String:
	return Strings.fill1("frame.pr", "v", str(roundi(card.power_rating)))


## Whole-percent PR change against the reference ("" when it rounds to 0).
static func pr_delta_text(card: FrameCard) -> String:
	if roundi(card.power_rating_delta) == 0:
		return ""
	return delta_text(card.power_rating_delta)


static func action_of(card: FrameCard) -> Action:
	if card.locked:
		return Action.LOCKED
	return Action.CONFIRM if card.selected else Action.SELECT


## Primary button text for a card.
static func action_text(card: FrameCard) -> String:
	match action_of(card):
		Action.LOCKED:
			return lock_text(card)
		Action.SELECT:
			return Strings.get_text("frame.select")
		_:
			return Strings.get_text("title.continue")


## Index of `id` in `cards` (0 when absent).
static func index_of(cards: Array[FrameCard], id: String) -> int:
	for i: int in cards.size():
		if cards[i].id == id:
			return i
	return 0


## Wraps `index + step` into `0 .. count - 1` (0 for an empty list).
static func wrap_index(index: int, step: int, count: int) -> int:
	if count <= 0:
		return 0
	return posmod(index + step, count)
