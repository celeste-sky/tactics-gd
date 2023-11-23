extends Node2D

@export var move_highlight = Color(0, 1.0, 0, 0.4)

var moving_player = null
var cells = {}

func _ready():
    for c in get_children():
        if c is Player or c is Tank:
            cells[to_coord(c.position)] = {occupant = c}

func _process(_delta):
    pass

func _input(event):
    if event.is_action_pressed("exit"):
        get_tree().quit()

func highlight(coord: Vector2i, color: Color):
    var rect = ColorRect.new()
    rect.color = color
    rect.position.x = coord.x * 64
    rect.position.y = coord.y * 64
    rect.size = Vector2(64, 64)
    rect.gui_input.connect(self._on_highlight_input.bind(rect))
    $Highlights.add_child(rect)

func clear_highlight():
    for child in $Highlights.get_children():
        child.queue_free()

func highlight_move(mover: Node2D):
    clear_highlight()

    # BFS through neighboring cells, up to move cost
    var start = {coord = to_coord(mover.position), cost = 0}
    var visited = {start.coord: start}
    var q = [start]
    while q.size() > 0:
        # maintain priority queue (inefficiently but shouldn't matter)
        q.sort_custom(func(a, b): return b.cost > a.cost)
        var cell = q.pop_front()

        highlight(cell.coord, move_highlight)

        for neigh in $Map.get_surrounding_cells(cell.coord):
            var data = $Map.get_cell_tile_data(0, neigh)
            if data == null:
                # i.e. off the map
                continue
            if neigh in cells and cells[neigh].occupant != null:
                continue

            var cost = cell.cost + data.get_custom_data("travel_cost")

            if neigh in visited:
                if cost < visited[neigh].cost:
                    # Found a shorter path (i.e. going around a high cost
                    # obstacle usually). It should hold that neigh is still
                    # in the priority queue....
                    visited[neigh].cost = cost
                continue

            if cost <= mover.max_travel_cost:
                visited[neigh] = {coord = neigh, cost = cost}
                q.append(visited[neigh])

func move_mover(mover: Node2D, coord: Vector2i):
    var old = to_coord(mover.position)
    cells[old].occupant = null
    if coord not in cells:
        cells[coord] = {occupant = mover}
    else:
        cells[coord].occupant = mover
    mover.position = to_pixel(coord)

func to_coord(pixel: Vector2i):
    @warning_ignore("integer_division")
    return Vector2i(pixel.x / 64, pixel.y / 64)

func to_pixel(coord: Vector2i):
    return Vector2i(coord.x * 64 + 32, coord.y * 64 + 32)

func _on_player_clicked(player: Node2D):
    print("clicked player " + player.name)
    if player.has_moved:
        return
    moving_player = player
    highlight_move(player)

func _on_tank_clicked(tank: Node2D):
    print("clicked tank " + tank.name)

func _on_highlight_input(event: InputEvent, rect: ColorRect):
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT and moving_player:
            $UI/EndTurn.disabled = false
            move_mover(moving_player, to_coord(rect.position))
            moving_player.has_moved = true
        clear_highlight()

func _on_end_turn_pressed():
    print("End Turn")
    for child in self.get_children():
        if child is Player:
            child.has_moved = false
    $UI/EndTurn.disabled = true
