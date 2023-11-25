extends CharacterBody2D
class_name Mover

@export var max_travel_cost = 6
@export var move_speed = 256.0

var has_moved = false
var next_position = null

signal clicked(Node2D)
signal next_position_reached()

func _physics_process(delta):
    if next_position == null:
        return
    var target_distance = (next_position - position).length()
    if target_distance < 1.0:
        next_position = null
        next_position_reached.emit()
        return
    var speed = min(move_speed, target_distance / delta)
    var velocity = speed * position.direction_to(next_position)
    self.move_and_collide(velocity * delta)

func _input_event(viewport, event, shape_idx):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            self.clicked.emit(self)

func move_to(position: Vector2):
    next_position = position
