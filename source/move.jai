Move_Delta :: struct {
    coord: v2i;
    old_value: int;
    new_value: int;
}

MAX_MOVE_DELTAS :: 16;
Move_Delta_Data :: struct {
    count: s32;
    deltas: [MAX_MOVE_DELTAS] Move_Delta;
    old_player_pos: v2i;
    new_player_pos: v2i;
}

MAX_UNDO :: 100;
Move_Stack :: Stack_Circular(Move_Delta_Data, MAX_UNDO);

add_move_delta :: (data: *Move_Delta_Data) -> *Move_Delta {
    assert(data.count < MAX_MOVE_DELTAS);
    data.count += 1;
    return *data.deltas[data.count - 1];
}

player_move :: (using game_state: *Game_State, move: v2i) -> bool {
    using level;
    new_pos := player_pos + move;
    success := false;

    delta_data : Move_Delta_Data;
    delta_data.old_player_pos = player_pos;

    if new_pos.x < 0 || new_pos.x >= level.dimensions.x || new_pos.y < 0 || new_pos.y >= level.dimensions.y {
        return false;
    } else if level.grid[new_pos.x][new_pos.y] == 0 {
        success = true;

        player_pos = new_pos;
    } else if level.grid[new_pos.x][new_pos.y] == BLOCK_SIGNED_PHOTOGRAPH {
        success = true;

        player_pos = new_pos;

        delta := add_move_delta(*delta_data);
        delta.coord = new_pos;
        delta.old_value = BLOCK_SIGNED_PHOTOGRAPH;
        delta.new_value = 0;

        level.grid[new_pos.x][new_pos.y] = 0;

    } else {
        stack : Stack(v2i);

        iter_pos := player_pos;

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
            } else {
                stack_push(*stack, iter_pos);
            }
        }

        if !success {
            prev := v2i.{-1, -1};
            while stack_is_empty(*stack) == false {
                pos := stack_pop(*stack);
                defer prev = pos;
                if prev == .{-1, -1} {
                    continue;
                }

                curr_block := level.grid[pos.x][pos.y];
                prev_block := level.grid[prev.x][prev.y];
                // See if two blocks can be combined, and if so, combine them and replace one with air
                if abs(curr_block) == abs(prev_block) {
                    prev_new_value : int;
                    if curr_block < 0 && prev_block < 0 {
                        prev_new_value = prev_block - 1;
                    } else {
                        prev_new_value = abs(prev_block) + 1;
                    }

                    delta := add_move_delta(*delta_data);
                    delta.coord = prev;
                    delta.old_value = prev_block;
                    delta.new_value = prev_new_value;

                    delta = add_move_delta(*delta_data);
                    delta.coord = pos;
                    delta.old_value = curr_block;
                    delta.new_value = 0;

                    level.grid[prev.x][prev.y] = prev_new_value;
                    level.grid[pos.x][pos.y] = 0;
                    success = true;
                    break;
                }
            }
        } if success {
            // This is for specifically when there's an air block
            player_pos = new_pos;
            while stack_is_empty(*stack) == false {
                pos := stack_pop(*stack);
                block_new_pos := pos + move;

                delta := add_move_delta(*delta_data);
                delta.coord = block_new_pos;
                delta.old_value = level.grid[block_new_pos.x][block_new_pos.y];
                delta.new_value = level.grid[pos.x][pos.y];

                delta = add_move_delta(*delta_data);
                delta.coord = pos;
                delta.old_value = level.grid[pos.x][pos.y];
                delta.new_value = 0;

                level.grid[block_new_pos.x][block_new_pos.y] = level.grid[pos.x][pos.y];
                level.grid[pos.x][pos.y] = 0;
            }
        }
    }

    delta_data.new_player_pos = new_pos;
    
    stack_push(*move_stack, delta_data);

    return success;
}

move_undo :: (using game_state: *Game_State) {
    if stack_is_empty(*move_stack) return;

    delta_data := stack_pop(*move_stack);
    level.player_pos = delta_data.old_player_pos;
    
    // Since each move delta represents a single tile change, the order they're implemented matters.
    // For example, we could change a block to air, and then later change that same block to another block.
    // We could calculate a simplified delta list when making a move, but we can also just reverse the
    // Order we undo them, which works just fine.
    for #v2 < 0..delta_data.count-1 {
        delta := delta_data.deltas[it];
        level.grid[delta.coord.x][delta.coord.y] = delta.old_value;
    }
}