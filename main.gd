extends Node2D

@export var move_highlight = Color(0, 1.0, 0, 0.4)

var moving_player = null
var cells = {}
var disable_actions = false

func _ready():
    for c in get_children():
        if c is Mover:
            cells[to_coord(c.position)] = {occupant = c}

func _process(_delta):
    pass

func _input(event):
    if event.is_action_pressed("exit"):
        get_tree().quit()

func to_coord(pixel: Vector2i):
    @warning_ignore("integer_division")
    return Vector2i(pixel.x / 64, pixel.y / 64)

func to_pixel(coord: Vector2i):
    return Vector2i(coord.x * 64 + 32, coord.y * 64 + 32)

func highlight(coord: Vector2i, color: Color, input_handler: Callable):
    var rect = ColorRect.new()
    rect.color = color
    rect.position.x = coord.x * 64
    rect.position.y = coord.y * 64
    rect.size = Vector2(64, 64)
    rect.gui_input.connect(input_handler)
    $Highlights.add_child(rect)

func clear_highlight():
    for child in $Highlights.get_children():
        child.queue_free()

func move_bfs(origin: Vector2i, visitor: Callable):
    """
    Call @p visitor with each cell ({coord: Vector2i, cost: int,
    path: List[Vector2i]} sorted by cost.
    Traversal proceeds through a given cell only if @p visitor returns true for
    that cell.
    """
    var start = {coord = origin, cost = 0, path = [origin]}
    var reached = {start.coord: start}
    var pq = [start]
    while pq.size() > 0:
        # maintain priority queue (inefficiently but shouldn't matter)
        pq.sort_custom(func(a, b): return b.cost > a.cost)

        var cell = pq.pop_front()
        if not visitor.call(cell):
            continue

        for neigh in $Map.get_surrounding_cells(cell.coord):
            var data = $Map.get_cell_tile_data(0, neigh)
            if data == null:
                # i.e. off the map
                continue

            var cost = cell.cost + data.get_custom_data("travel_cost")

            if neigh not in reached:
                reached[neigh] = {
                    coord = neigh, cost = cost, path = cell.path + [neigh]
                }
                pq.append(reached[neigh])
            elif cost < reached[neigh].cost:
                reached[neigh].cost = cost
                reached[neigh].path = cell.path + [neigh]

func highlight_move(mover: Node2D):
    clear_highlight()
    move_bfs(to_coord(mover.position), highlight_move_visitor.bind(mover))

func highlight_move_visitor(cell: Dictionary, mover: Node2D) -> bool:
    if len(cell.path) == 1:
        # first cell, would be occupied by mover, don't highlight.
        return true
    if cell.cost > mover.max_travel_cost:
        return false
    if cell.coord in cells and cells[cell.coord].occupant != null:
        return false
    highlight(cell.coord, move_highlight, on_move_input.bind(cell))
    return true

func on_move_input(event: InputEvent, cell: Dictionary):
    if event is InputEventMouseButton and event.pressed:
        clear_highlight()
        if event.button_index == MOUSE_BUTTON_LEFT and moving_player:
            $UI/EndTurn.disabled = false
            moving_player.has_moved = true
            disable_actions = true
            await move_along_path(moving_player, cell.path)
            print("move complete")
            disable_actions = false

func move_along_path(mover: Node2D, path: Array):
    var old_coord = to_coord(mover.position)
    for i in range(1, len(path)):
        print('next pos: ' + str(path[i]))
        mover.move_to(to_pixel(path[i]))
        await(mover.next_position_reached)
    cells[old_coord].occupant = null
    if path[-1] not in cells:
        cells[path[-1]] = {occupant = mover}
    else:
        cells[path[-1]].occupant = mover

func find_target_visitor(cell: Dictionary, data: Dictionary) -> bool:
    if len(cell.path) == 1:
        # skip the origin cell
        return true
    if data.target != null:
        # already found a target, stop searching
        return false
    if not cell.coord in cells:
        return true
    if cells[cell.coord].occupant is Player:
        data.target = cells[cell.coord].occupant
        data.path = cell.path
        return false
    return cells[cell.coord].occupant == null

func enemy_turn():
    for c in get_children():
        if not c is Tank:
            continue

        # Find nearest player
        var target_result = {target = null, path = null}
        move_bfs(to_coord(c.position), find_target_visitor.bind(target_result))
        print(c.name + " target: " + str(target_result))
        if target_result.target == null:
            print('no target found')
            continue

        # Move along shortest path toward player
        var move_cost = 0
        var last_reachable = 0
        for i in range(1, len(target_result.path) - 1):
            var data = $Map.get_cell_tile_data(0, target_result.path[i])
            var cost = data.get_custom_data("travel_cost")
            if move_cost + cost > c.max_travel_cost:
                break
            move_cost += cost
            last_reachable = i
        await move_along_path(
            c, target_result.path.slice(0, last_reachable + 1))

func _on_player_clicked(player: Node2D):
    if disable_actions:
        return
    print("clicked player " + player.name)
    if player.has_moved:
        return
    moving_player = player
    highlight_move(player)

func _on_tank_clicked(tank: Node2D):
    print("clicked tank " + tank.name)

func _on_end_turn_pressed():
    print("End Turn")
    $UI/EndTurn.disabled = true
    disable_actions = true
    await enemy_turn()
    for child in self.get_children():
        if child is Player:
            child.has_moved = false
    disable_actions = false
