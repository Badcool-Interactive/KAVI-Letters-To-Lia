extends RefCounted
## Rewarded-ad service. STUB ONLY: no ad SDK is integrated.
## VOLT-RUN-PLAN §9: voluntary rewarded ads only (max 3/day), never during
## gameplay, story or after a failure. Before wiring a real SDK: Families
## Policy, COPPA/GDPR age handling, certified SDK list and a legal review.
## A real provider must implement the same three methods.

const DAILY_CAP := 3
const PROVIDER := "stub"

var save

func _today() -> String:
	var d := Time.get_date_dict_from_system(true)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func remaining_today() -> int:
	if save.data.ads_date != _today():
		save.data.ads_date = _today()
		save.data.ads_today = 0
	return maxi(DAILY_CAP - int(save.data.ads_today), 0)

func can_show() -> bool:
	return remaining_today() > 0

## Calls `on_reward` after the (placeholder) ad completes.
func show_rewarded(host: Node, on_reward: Callable) -> void:
	if not can_show():
		return
	save.data.ads_today = int(save.data.ads_today) + 1
	save.save()
	host.get_tree().create_timer(2.0, true, false, true).timeout.connect(on_reward)
