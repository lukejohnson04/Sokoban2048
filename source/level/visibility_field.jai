
Visibility_Node :: struct {
    visible: bool;
    visited: bool;
}

Visibility_Field :: [Level.MAX_WIDTH][Level.MAX_HEIGHT] Visibility_Node;

vfield_generate_flood_fill :: (level: *Level, field: [][Level.MAX_HEIGHT] Visibility_Node) {
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            field[x][y] = .{false, false};
        }
    }

    queue: Queue(v2i, 1000);
    queue_add(*queue, level.player_pos);

    dirs :: v2i.[.{1,0}, .{0,1}, .{-1,0}, .{0,-1}];

    while outter := queue_is_empty(*queue) == false {
        coord := queue_remove(*queue);
        node := *field[coord.x][coord.y];
        if node.visited {
            continue;
        }
        node.visible = true;
        node.visited = true;
        
        for dir: dirs {
            pos := coord + dir;
            
            if !is_in_bounds(pos, level) continue;
            new_node := *field[pos.x][pos.y];

            if new_node.visited {
                continue;
            }
            block := level.grid[pos.x][pos.y];

            if block.type == .WALL || block_is_goal(block) || block.type == .BOULDER {
                new_node.visible = true;
                new_node.visited = true;
                continue;
            }
            
            queue_add(*queue, pos);
            if queue.count == queue.MAX_SIZE {
                break outter;
            }
        }
    }
}