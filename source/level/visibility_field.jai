
Visibility_Node :: struct {
    coord: v2i;
    visible: bool;
    visited: bool;
    steps: int;
}
Visibility_Field :: [Level.MAX_WIDTH][Level.MAX_HEIGHT] Visibility_Node;

vfield_generate_flood_fill :: (level: *Level, field: [][Level.MAX_HEIGHT] Visibility_Node) {
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            field[x][y] = .{.{x, y}, false, false, 0};
        }
    }

    queue: Queue(*Visibility_Node, 1000);
    queue_add(*queue, *field[level.player_pos.x][level.player_pos.y]);

    dirs := v2i.[.{1,0}, .{0,1}, .{-1,0}, .{0,-1}];

    while queue_is_empty(*queue) == false {
        node := queue_remove(*queue);
        coord := node.coord;
        if field[coord.x][coord.y].visited {
            if field[coord.x][coord.y].steps == 0 || field[coord.x][coord.y].steps > node.steps {
                field[coord.x][coord.y].steps = node.steps;
            }
            continue;
        }
        field[coord.x][coord.y].visible = true;
        field[coord.x][coord.y].visited = true;
        if field[coord.x][coord.y].steps == 0 || field[coord.x][coord.y].steps > node.steps {
            field[coord.x][coord.y].steps = node.steps;
        } else if field[coord.x][coord.y].steps < node.steps {
            node.steps = field[coord.x][coord.y].steps;
        }
        
        for dir: dirs {
            pos := coord + dir;
            
            if !is_in_bounds(pos, level) continue;
            new_node := *field[pos.x][pos.y];
            if new_node.steps == 0 || new_node.steps > node.steps + 1 {
                new_node.steps = node.steps + 1;
            }

            if new_node.visited {
                continue;
            }
            block := level.grid[pos.x][pos.y];

            if block.type == .WALL || block_is_goal(block) || block.type == .BOULDER {
                new_node.visible = true;
                new_node.visited = true;
                if new_node.steps == 0 || new_node.steps > node.steps + 1 {
                    new_node.steps = node.steps + 1;
                }
                continue;
            }
            
            queue_add(*queue, new_node);
        }
    }
}