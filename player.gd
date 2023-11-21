extends Area2D
class_name Player

@export var max_travel_cost = 6

var has_moved = false

signal clicked(Node2D)

func _input_event(viewport, event, shape_idx):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            self.clicked.emit(self)
