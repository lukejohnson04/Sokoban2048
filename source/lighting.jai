Light :: struct {
    pos: Vector2;
    radius: float;
}

// Returns every point to draw triangle strips of
do_lighting :: (using game_state: *Game_State, light: Light) -> [..] Vector2 {
    // Get all blocks within radius
    corners: [..] Vector2;
    corners.allocator = temp;
    light_pos := v2i.{xx light.pos.x, xx light.pos.y};

    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            if level.grid[x][y].type == .NONE continue;
            for corner: 0..3 {
                pos := Vector2.{xx x, xx y};
                pos.x += corner % 2;
                pos.y += corner / 2;

                if distance(Vector2.{xx pos.x, xx pos.y}, Vector2.{xx light_pos.x, xx light_pos.y}) <= light.radius {
                    array_add(*corners, pos);
                }
            }
        }
    }

    // 

    return corners;
}