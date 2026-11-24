extends Node2D
## Generic draw node: forwards _draw to a callable (lets one script paint
## several layers with different blend modes). Accumulates the CPU time spent
## generating draw commands, for the benchmark.
var fn: Callable
var tag := ""
static var cost_usec := 0
static var profiling := false   # set by the benchmark; no timing cost otherwise
static var costs := {}   # tag -> usec this frame (benchmark breakdown)

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
