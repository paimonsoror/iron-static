class_name FeedbackLink
extends RefCounted
## B1-08: the one place the feedback URL lives. It is the codex Feedback page, which links to the feedback form
## (the form link is edited in `site/docs/feedback.md`, not here). Set `URL` to "" to hide the Settings button.
## Opening goes through `OS.shell_open` (no INTERNET permission needed); tests inject an opener. No data is sent.

const URL: String = "https://paimonsoror.github.io/iron-static/feedback/"


static func is_set(url: String) -> bool:
	return url.strip_edges() != ""


## Opens `url` through `opener` (default `OS.shell_open`); false and no call when the url is empty.
static func open(url: String, opener: Callable = Callable()) -> bool:
	if not is_set(url):
		return false
	if opener.is_valid():
		@warning_ignore("return_value_discarded")
		opener.call(url)
	else:
		@warning_ignore("return_value_discarded")
		OS.shell_open(url)
	return true
