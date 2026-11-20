extends Node2D
## Generic draw node: forwards _draw to a callable (lets one script paint
## several layers with different blend modes).
var fn: Callable

func _draw() -> void:
	if fn.is_valid():
		fn.call(self)
