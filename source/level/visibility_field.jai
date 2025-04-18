
Visibility_Node :: struct {
    coord: v2i;
    visible: bool;
    visited: bool;
}
Visibility_Field :: [Level.MAX_WIDTH][Level.MAX_HEIGHT] Visibility_Node;

vfield_generate_flood_fill :: (using game_state: *Game_State) {
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            field[x][y] = .{.{x, y}, false, false};

        }
    }

    queue: Queue(v2i, 1000);
    queue_add(*queue, level.player_pos);

    dirs := v2i.[.{1,0}, .{0,1}, .{-1,0}, .{0,-1}];

    while queue_is_empty(*queue) == false {
        coord := queue_remove(*queue);
        if field[coord.x][coord.y].visited continue;
        field[coord.x][coord.y].visible = true;
        field[coord.x][coord.y].visited = true;
        for dir: dirs {
            pos := coord + dir;
            
            if !is_in_bounds(pos, *level) continue;
            if field[pos.x][pos.y].visited          continue;
            block := level.grid[pos.x][pos.y];

            if block.type == .WALL || block_is_goal(block) {
                field[pos.x][pos.y].visible = true;
                field[pos.x][pos.y].visited = true;
                continue;
            }
            


            queue_add(*queue, pos);
        }
    }
}