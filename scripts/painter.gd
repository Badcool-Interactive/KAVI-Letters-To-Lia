extends Node2D
## Generic draw node: forwards _draw to a callable (lets one script paint
## several layers with different blend modes). Accumulates the CPU time spent
## generating draw commands, for the benchmark.
var fn: Callable
static var cost_usec := 0

func _draw() -> void:
	if fn.is_valid():
		var t0 := Time.get_ticks_usec()
		fn.call(self)
		cost_usec += Time.get_ticks_usec() - t0
