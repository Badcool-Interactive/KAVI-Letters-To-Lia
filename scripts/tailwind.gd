extends RefCounted
## Tailwind: perfect-execution tiers x1..x4. A mistake drops exactly one tier.

const THRESHOLDS := [0, 3, 8, 15]

var perfects := 0
var best_tier := 1

func tier() -> int:
	var t := 1
	for i in THRESHOLDS.size():
		if perfects >= THRESHOLDS[i]:
			t = i + 1
	return t

## Returns true when this perfect raised the tier.
func perfect() -> bool:
	var before := tier()
	perfects += 1
	best_tier = maxi(best_tier, tier())
	return tier() > before

func mistake() -> void:
	var t := tier()
	perfects = THRESHOLDS[maxi(t - 2, 0)]

## 0..1 progress toward the next tier.
func progress() -> float:
	var t := tier()
	if t >= 4:
		return 1.0
	var a: float = THRESHOLDS[t - 1]
	var b: float = THRESHOLDS[t]
	return (perfects - a) / (b - a)

func reset() -> void:
	perfects = 0
