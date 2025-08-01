
Move_Delta :: struct {
    coord: v2i;
    old_value: Block;
    new_value: Block;
}

MAX_MOVE_DELTAS :: 16;
Move_Delta_Data :: struct {
    count: s32;
    deltas: [MAX_MOVE_DELTAS] Move_Delta;
    // Change this to just one variable "new player delta"
    old_player_pos: v2i;
    new_player_pos: v2i;
}

add_move_delta :: (data: *Move_Delta_Data) -> *Move_Delta {
    assert(data.count < MAX_MOVE_DELTAS);
    data.count += 1;
    return *data.deltas[data.count - 1];
}


move_player :: (move: v2i) -> success: bool, combines_block: bool, activates_goal_block: bool {
    using context.game_state;
    using level;
    new_pos := player_pos + move;

    success := false;
    combines_block := false;
    activates_goal_block := false;

    delta_data : Move_Delta_Data;
    delta_data.old_player_pos = player_pos;

    new_pos_type := get_block_type(level.grid[new_pos.x][new_pos.y]);
    if new_pos_type == .PORTAL {
        portal_pos := get_matching_portal(level.grid[new_pos.x][new_pos.y], new_pos);
        new_pos = portal_pos + move;
        new_pos_type = get_block_type(level.grid[new_pos.x][new_pos.y]);
    }
    // Off the map
    if new_pos.x < 0 || new_pos.x >= level.dimensions.x || new_pos.y < 0 || new_pos.y >= level.dimensions.y {
        return false, false, false;
    // Player walks into interactable
    } else if new_pos_type == .INTERACTABLE {
        generate_interaction_queue(*dialogue_state, level.grid[new_pos.x][new_pos.y]);
        apply_turn();
        return true, false, false;
    // Player walks into spike
    } else if new_pos_type == .SPIKED {
        return false, false, false;
    // Player walks into air or onto barrier block. Easy case.
    } else if new_pos_type == .NONE || new_pos_type == .BLOCK_BARRIER {
        success = true;
        player_pos = new_pos;
    } else {
        // Player walks into portal
        stack : Stack(v2i);

        iter_pos := player_pos;

        push_into_object := false;
        destroy_block := false;

        prev_block_portal := false;
        // search for air block
        while true {
            iter_pos += move;
            block := level.grid[iter_pos.x][iter_pos.y];
            // Boundary break
            if iter_pos.x < 0 || iter_pos.x >= level.dimensions.x || iter_pos.y < 0 || iter_pos.y >= level.dimensions.y {
                break;
            }
            if block_is_goal(block) {
                stack_push(*stack, iter_pos);
                push_into_object = true;
                break;
            }

            block_type := get_block_type(block);
            if block_type == .SPIKED {
                destroy_block = true;
                success = true;
                break;
            }
            if block_type == .WALL || block_type == .BLOCK_BARRIER || block_type == .INTERACTABLE {
                push_into_object = true;
                break;
            }
            if block_type == .PORTAL {
                portal_pos := get_matching_portal(block, iter_pos);
                iter_pos = portal_pos;
                prev_block_portal = true;
                continue;
            }


            // Encounter air block
            if block_type == .NONE {
                success = true;
                break;
            } else {
                stack_push(*stack, iter_pos);
            }
            prev_block_portal = false;
        }

        if push_into_object {
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
                curr_block_type := get_block_type(curr_block);
                prev_block_type := get_block_type(prev_block);

                if curr_block_type == .NUMBERED && prev_block_type == .NUMBERED && curr_block.id == prev_block.id  {
                    new_block := prev_block;
                    new_block.id += 1;
                    combines_block = true;

                    if block_is_goal(curr_block) || block_is_goal(prev_block) {
                        // Goal block cleared
                        activates_goal_block = true;

                        if curr_block.flags & .VANISH_GOAL || prev_block.flags & .VANISH_GOAL {
                            new_block = BLOCK_NONE;
                        } else {
                            new_block.flags &= ~Block.Flag.GOAL;
                            new_block.flags &= ~Block.Flag.VANISH_GOAL;
                        }
                    }

                    delta := add_move_delta(*delta_data);
                    delta.coord = prev;
                    delta.old_value = prev_block;
                    delta.new_value = new_block;

                    delta = add_move_delta(*delta_data);
                    delta.coord = pos;
                    delta.old_value = curr_block;
                    delta.new_value = BLOCK_NONE;

                    level.grid[prev.x][prev.y] = new_block;
                    level.grid[pos.x][pos.y] = BLOCK_NONE;
                    success = true;
                    print("Combination\n");
                    break;
                }
            }
        } if success {
            // This is for specifically when there's an air block or spiked block
            // This includes combinations that create an air block
            player_pos = new_pos;
            while stack_is_empty(*stack) == false {
                pos := stack_pop(*stack);
                block_new_pos := pos + move;
                if get_block_type(level.grid[block_new_pos.x][block_new_pos.y]) == .PORTAL {
                    block_new_pos = get_matching_portal(level.grid[block_new_pos.x][block_new_pos.y], block_new_pos);
                    block_new_pos += move;
                }

                delta: *Move_Delta;

                if destroy_block {
                    // Remove this line to make an incinerator
                    destroy_block = false;
                } else {
                    delta = add_move_delta(*delta_data);
                    delta.coord = block_new_pos;
                    delta.old_value = level.grid[block_new_pos.x][block_new_pos.y];
                    delta.new_value = level.grid[pos.x][pos.y];
                    level.grid[block_new_pos.x][block_new_pos.y] = level.grid[pos.x][pos.y];
                }
                delta = add_move_delta(*delta_data);
                delta.coord = pos;
                delta.old_value = level.grid[pos.x][pos.y];
                delta.new_value = BLOCK_NONE;
                level.grid[pos.x][pos.y] = BLOCK_NONE;
            }
        }
    }

    if success {
        delta_data.new_player_pos = new_pos;

        turn_memory.curr.type = .MOVE;
        turn_memory.curr.move_delta = delta_data;
        turn_memory.curr.next = turn_memory.curr + 1;
        turn_memory.curr += 1;
        turn_memory.curr.prev = turn_memory.curr - 1;
        turn_memory.curr.next = null;
        turn_count += 1;
    }

    return success, combines_block, activates_goal_block;
}

goto_last_checkpoint :: () -> bool {
    using context.game_state;
    return false;
}

#load "turn.jai";