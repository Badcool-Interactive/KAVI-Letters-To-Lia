extends RefCounted
## Procedural full-body animal costumes. The visor still uses Kavi's own eyes,
## expressions and equipped face style.

const Art = preload("res://scripts/art.gd")
const PALETTES := {
	"cat": [Color("#aaa2d9"), Color("#7773ac"), Color("#e7a4c4"), Color("#6e6898"), Color("#e7d8ec"), "cheeks"],
	"bunny": [Color("#f1e3ec"), Color("#b3a6c4"), Color("#df92b0"), Color("#b28fbb"), Color("#fff2f0"), "oval"],
	"lion": [Color("#efa046"), Color("#bd662f"), Color("#9c441f"), Color("#b86632"), Color("#ffdb96"), "cheeks"],
	"bear": [Color("#a97556"), Color("#6e4941"), Color("#df956a"), Color("#795044"), Color("#e6ba8c"), "round"],
	"fox": [Color("#ee7741"), Color("#a34c36"), Color("#fff0d7"), Color("#50353d"), Color("#ffedd4"), "cheeks"],
	"panda": [Color("#f4eee1"), Color("#3f4253"), Color("#8aa47a"), Color("#393847"), Color("#fff8eb"), "round"],
	"frog": [Color("#82c95a"), Color("#4b9e62"), Color("#b9df6a"), Color("#40885b"), Color("#dfed9c"), "frog"],
	"penguin": [Color("#394761"), Color("#292f49"), Color("#efa757"), Color("#ed9853"), Color("#fff0da"), "drop"],
	"bee": [Color("#f8c554"), Color("#b17c32"), Color("#563e49"), Color("#514451"), Color("#ffdf79"), "oval"],
	"dino": [Color("#64bd9b"), Color("#3f806e"), Color("#b28cd5"), Color("#4d9980"), Color("#d4e99f"), "snout"],
	"tiger": [Color("#ff9a4d"), Color("#bd5f35"), Color("#563746"), Color("#a35344"), Color("#ffe1b6"), "cheeks"],
	"axolotl": [Color("#f7a2bd"), Color("#ba6c9e"), Color("#de5989"), Color("#d77eb1"), Color("#ffe0e8"), "frog"],
	"bat": [Color("#8e71bb"), Color("#574466"), Color("#e899b2"), Color("#594970"), Color("#c5aeda"), "drop"],
	"red_panda": [Color("#ca633e"), Color("#743f3d"), Color("#f4c4a0"), Color("#543942"), Color("#efbd94"), "cheeks"],
	"otter": [Color("#a67658"), Color("#74504a"), Color("#7db8ba"), Color("#654746"), Color("#e1c29d"), "oval"],
	"turtle": [Color("#7eaa67"), Color("#527358"), Color("#d7b575"), Color("#557657"), Color("#e8d594"), "snout"],
}

static var _mask_cache: Dictionary = {}

static func screen_shape(rect: Rect2, mask: String) -> PackedVector2Array:
	var key := [rect, mask]
	if _mask_cache.has(key):
		return _mask_cache[key]
	var points := _make_screen_shape(rect, mask)
	_mask_cache[key] = points
	return points

static func _make_screen_shape(rect: Rect2, mask: String) -> PackedVector2Array:
	var center := rect.get_center()
	var half := rect.size * 0.5
	var outline: PackedVector2Array
	match mask:
		"round":
			return Art.ellipse(center, half, 24)
		"oval":
			return Art.rrect(rect, half.y * 0.9, 8)
		"cheeks":
			outline = PackedVector2Array([Vector2(-0.93, -0.58), Vector2(-0.49, -0.97), Vector2(0, -0.82),
				Vector2(0.49, -0.97), Vector2(0.93, -0.58), Vector2(1.02, 0.26),
				Vector2(0.72, 0.87), Vector2(0, 1), Vector2(-0.72, 0.87), Vector2(-1.02, 0.26)])
		"frog":
			outline = PackedVector2Array([Vector2(-1, -0.24), Vector2(-0.75, -0.95), Vector2(-0.38, -1),
				Vector2(0, -0.70), Vector2(0.38, -1), Vector2(0.75, -0.95), Vector2(1, -0.24),
				Vector2(0.86, 0.62), Vector2(0.48, 0.94), Vector2(-0.48, 0.94), Vector2(-0.86, 0.62)])
		"drop":
			outline = PackedVector2Array([Vector2(-0.95, -0.60), Vector2(-0.55, -0.96), Vector2(0, -0.88),
				Vector2(0.55, -0.96), Vector2(0.95, -0.60), Vector2(0.85, 0.46),
				Vector2(0.46, 0.92), Vector2(0, 1.06), Vector2(-0.46, 0.92), Vector2(-0.85, 0.46)])
		_:
			outline = PackedVector2Array([Vector2(-0.82, -0.71), Vector2(-0.45, -0.96), Vector2(0.45, -0.96),
				Vector2(0.82, -0.71), Vector2(1.03, -0.02), Vector2(0.92, 0.68),
				Vector2(0.58, 0.95), Vector2(-0.58, 0.95), Vector2(-0.92, 0.68), Vector2(-1.03, -0.02)])
	var points := PackedVector2Array()
	for i in outline.size():
		var previous := outline[posmod(i - 1, outline.size())]
		var point := outline[i]
		var next := outline[(i + 1) % outline.size()]
		points.append(center + previous.lerp(point, 0.79) * half)
		points.append(center + point.lerp(next, 0.21) * half)
	return points

static func belly(ci: Node2D, animal: String, center: Vector2, palette: Array) -> void:
	ci.draw_colored_polygon(Art.ellipse(center, Vector2(14, 16), 18), palette[4])
	if animal == "bee":
		for y in [-6, 4]:
			ci.draw_colored_polygon(Art.rrect(Rect2(center + Vector2(-15, y), Vector2(30, 5)), 2), palette[2])
	elif animal == "tiger":
		for side in [-1.0, 1.0]:
			for y in [-7, 2, 9]:
				var tip := center + Vector2(5 * side, y + 3)
				ci.draw_colored_polygon(PackedVector2Array([center + Vector2(16 * side, y - 2), tip, center + Vector2(16 * side, y + 4)]), palette[2])
	elif animal == "turtle":
		ci.draw_line(center + Vector2(-11, -3), center + Vector2(11, -3), Color(palette[1], 0.45), 1.8)
		ci.draw_line(center + Vector2(-11, 5), center + Vector2(11, 5), Color(palette[1], 0.45), 1.8)

static func back(ci: Node2D, animal: String, palette: Array, sway: float, front: bool) -> void:
	var base := Vector2(-16, -35)
	if animal == "bee" or animal == "bat" or animal == "penguin":
		_wings(ci, animal, palette, sway, front)
	if animal == "turtle":
		var shell := Vector2(-34, -49)
		ci.draw_colored_polygon(Art.ellipse(shell, Vector2(22, 18), 20), palette[1])
		ci.draw_colored_polygon(Art.ellipse(shell + Vector2(-2, -1), Vector2(18, 14), 20), palette[0])
		var scute := Art.ellipse(shell + Vector2(-6, -1), Vector2(8, 8), 6, PI / 6.0)
		scute.append(scute[0])
		ci.draw_polyline(scute, palette[1], 2.1, Art.AA)
		ci.draw_line(shell + Vector2(-13, -2), shell + Vector2(-20, -4), palette[1], 2.1, Art.AA)
		ci.draw_line(shell + Vector2(-5, -8), shell + Vector2(-5, -14), palette[1], 2.1, Art.AA)
	if animal in ["frog", "penguin", "bee", "bat", "bear", "panda", "bunny", "turtle"]:
		if animal in ["bear", "panda", "bunny", "turtle"]:
			var nub := base + Vector2(-14, -2)
			ci.draw_colored_polygon(Art.ellipse(nub, Vector2(9, 8), 16), palette[4] if animal == "bunny" else palette[1])
		return
	var tip := base + Vector2(-34 if front else -43, 7 + sway * 6.0)
	var bend := (base + tip) * 0.5 + Vector2(0, 9 + sway * 3)
	var points := PackedVector2Array([base, bend, tip])
	var thick := 6.0
	if animal in ["dino", "axolotl", "otter"]:
		tip.y -= 8.0
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(3, -9), bend + Vector2(0, -6), tip,
			bend + Vector2(-3, 5), base + Vector2(0, 7)]), palette[0])
		if animal == "dino":
			for i in 3:
				var p := base.lerp(tip, 0.25 + 0.19 * i)
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-6, 0), p + Vector2(-2, -9), p + Vector2(6, 1)]), palette[2])
		elif animal == "axolotl":
			ci.draw_colored_polygon(Art.ellipse(tip + Vector2(7, 0), Vector2(13, 5), 14, -0.2), palette[2])
		return
	if animal in ["fox", "red_panda"]:
		thick = 15.0
		ci.draw_colored_polygon(Art.ellipse(bend.lerp(tip, 0.55), Vector2(17, 8), 18, -0.20), palette[0])
	ci.draw_polyline(points, palette[0], thick, Art.AA)
	match animal:
		"lion":
			ci.draw_colored_polygon(Art.ellipse(tip, Vector2(11, 6), 16, -0.45), palette[2])
		"fox":
			ci.draw_colored_polygon(Art.ellipse(tip + Vector2(1, 0), Vector2(10, 6), 16, -0.35), palette[4])
		"red_panda", "tiger":
			for i in 3:
				var p := bend.lerp(tip, 0.25 + i * 0.32)
				ci.draw_line(p + Vector2(-2, -thick * 0.48), p + Vector2(3, thick * 0.45), palette[1], 3.8, Art.AA)
		"cat":
			ci.draw_circle(tip, 4.1, palette[1])

static func _wings(ci: Node2D, animal: String, palette: Array, sway: float, front: bool) -> void:
	for side in [-1.0, 1.0]:
		var root := Vector2(17 * side, -53) if front else Vector2(-17, -53)
		var spread: float = side if front else -1.0
		var tip := root + Vector2(39 * spread, -15.0 + side * 9.0 + sway * 7)
		if animal == "bee":
			ci.draw_colored_polygon(Art.ellipse(root.lerp(tip, 0.62), Vector2(22, 8), 18, side * 0.42 * spread),
				Color("#d6f6fa") if side < 0 else Color("#9ddce7"))
			ci.draw_line(root, tip, Color("#e9fbfb"), 1.6, Art.AA)
		elif animal == "penguin":
			ci.draw_colored_polygon(Art.ellipse(root + Vector2(8 * spread, 16), Vector2(8, 19), 16, spread * 0.45), palette[1])
		else:
			var elbow := root.lerp(tip, 0.54) + Vector2(0, -12)
			ci.draw_colored_polygon(PackedVector2Array([root, elbow, tip, tip + Vector2(-3 * spread, 14),
				root.lerp(tip, 0.68) + Vector2(0, 7), root.lerp(tip, 0.44) + Vector2(0, 15),
				root.lerp(tip, 0.22) + Vector2(0, 8), root + Vector2(0, 13)]), palette[1])
			ci.draw_polyline(PackedVector2Array([root, elbow, tip]), palette[2], 2.0, Art.AA)
