extends Node2D
## Generic draw node: forwards _draw to a callable (lets one script paint
## several layers with different blend modes). Accumulates the CPU time spent
## generating draw commands, for the benchmark.
var fn: Callable
var tag := ""
static var cost_usec := 0
static var profiling := false   # set by the benchmark; no timing cost otherwise
static var costs := {}   # tag -> usec this frame (benchmark breakdown)

## 0.8.24: every painter draws a whole screen's worth of shapes, so its bounds
## are set to "everything" and Godot never culls it. (Owner's phone: the front
## plants vanished for seconds while the PC was fine; a wrong automatic
## culling rect on the mobile renderer is the likely cause.)
func _ready() -> void:
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, Rect2(-1.0e6, -1.0e6, 2.0e6, 2.0e6))

func _draw() -> void:
	if not fn.is_valid():
		return
	if not profiling:
		fn.call(self)
		return
	var t0 := Time.get_ticks_usec()
	fn.call(self)
	var d := Time.get_ticks_usec() - t0
	cost_usec += d
	costs[tag] = int(costs.get(tag, 0)) + d
