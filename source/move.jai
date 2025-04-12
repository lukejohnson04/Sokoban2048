player_move :: (using game_state: *Game_State, move: v2i) -> bool {
    using level;
    new_pos := player_pos + move;
    success := false;

    if new_pos.x < 0 || new_pos.x >= level.dimensions.x || new_pos.y < 0 || new_pos.y >= level.dimensions.y {
    } else if level.grid[new_pos.x][new_pos.y] == 0 {
        success = true;
        player_pos = new_pos;
    } else {
        stack : Stack(v2i);

        iter_pos := player_pos;

        impossible := false;
        // search for air block
        while true {
            iter_pos += move;
            block := level.grid[iter_pos.x][iter_pos.y];
            if iter_pos.x < 0 || iter_pos.x >= level.dimensions.x || iter_pos.y < 0 || iter_pos.y >= level.dimensions.y {
                success = false;
                break;
            }
            if block < 0 {
                stack_push(*stack, iter_pos);
                success = false;
                break;
            }

            if block == BLOCK_WALL {
                success = false;
                break;
            }

            // Encounter air block
            if block == 0 {
                success = true;
                break;
            } else if block == BLOCK_BOULDER {
                impossible = true;
                success = false;
                break;
            } else {
                stack_push(*stack, iter_pos);
            }
        }

        if success == false && !impossible {
            prev := v2i.{-1, -1};
            while stack_is_empty(*stack) == false {
                pos := stack_pop(*stack);
                defer prev = pos;
                if prev == .{-1, -1} {
                    continue;
                }
                if abs(level.grid[pos.x][pos.y]) == abs(level.grid[prev.x][prev.y]) {
                    if level.grid[pos.x][pos.y] < 0 && level.grid[prev.x][prev.y] < 0 {
                        level.grid[prev.x][prev.y] -= 1;
                    } else {
                        level.grid[prev.x][prev.y] = abs(level.grid[prev.x][prev.y]) + 1;
                    }
                    level.grid[pos.x][pos.y] = 0;
                    success = true;
                    break;
                }
            }
        } if success && !impossible {
            player_pos = new_pos;
            while stack_is_empty(*stack) == false {
                pos := stack_pop(*stack);
                block_new_pos := pos + move;
                level.grid[block_new_pos.x][block_new_pos.y] = level.grid[pos.x][pos.y];
                level.grid[pos.x][pos.y] = 0;
            }
        }
    }
    
    return success;
}