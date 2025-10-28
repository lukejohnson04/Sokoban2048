
Move_Delta :: struct {
    coord: v2i;
    old_value: Block;
    new_value: Block;
}

Tween_Delta :: struct {
    value: Block;
    from: v2i;
    to: v2i;
}

MAX_MOVE_DELTAS :: 16;
Move_Delta_Data :: struct {
    count: s32;
    deltas: [MAX_MOVE_DELTAS] Move_Delta;
    tween_count: s32;
    tween_changes: [MAX_MOVE_DELTAS] Tween_Delta;
    // Change this to just one variable "new player delta"
    old_player_pos: v2i;
    new_player_pos: v2i;
}

add_move_delta :: (data: *Move_Delta_Data) -> *Move_Delta {
    assert(data.count < MAX_MOVE_DELTAS);
    data.count += 1;
    return *data.deltas[data.count - 1];
}


move_player :: (move: v2i) -> success: bool {
    using context.game_state;
    using level;
    new_pos := player_pos + move;

    success := false;

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
        return false;
    // Player walks into interactable
    } else if new_pos_type == .INTERACTABLE {
        generate_interaction_queue(*dialogue_state, level.grid[new_pos.x][new_pos.y]);
        apply_turn();
        return true;
    // Player walks into spike
    } else if new_pos_type == .SPIKED {
        return false;
    // Player walks into air or onto barrier block. Easy case.
    } else if new_pos_type == .NONE || new_pos_type == .BLOCK_BARRIER {
        success = true;
        player_pos = new_pos;
    } else {
        stack : Stack(v2i);
        
        // Iterate over all blocks being pushed to see what they're pushed into.
        // A line of blocks can be pushed into air, a wall/barrier block/interactable, a portal, a goal block, or spikes.
        //
        // Air - all blocks are simply pushed by the move offset
        // Wall - Combination of blocks is recursively tried later
        // Spike - all blocks are moved and final block is destroyed
        // Goal block - Combination of blocks is recursively tried later, including the goal block itself
        // Portal - Black magic happens
        links_moved : [..] Link_Struct;
        links_moved.allocator = temp;
        push_into_wall, destroy_block := push_block_recursively(player_pos, move, *stack, *delta_data, *success, *links_moved);
        
        for outter: 0..links_moved.count-1 {
            for inner: outter+1..links_moved.count-1 {
                if links_moved[outter] == links_moved[inner] {
                    links_moved[outter] = links_moved[links_moved.count-1];
                    links_moved[inner] = links_moved[links_moved.count-2];
                    outter -= 1;
                    break;
                }
            }
        }

        for link: links_moved {
            for x: 0..level.dimensions.x-1 {
                for y: 0..level.dimensions.y-1 {
                    if level.grid[x][y].interaction_id != link.id || !(level.grid[x][y].flags & .LINKED) {
                        continue;
                    }
                    if link.pos == .{x, y} continue;

                    stack_clear(*stack);
                    cp := false;

                    links_moved_2 : [..] Link_Struct;
                    links_moved_2.allocator = temp;
                    push_block_recursively(.{x, y}, move, *stack, *delta_data, *cp, *links_moved_2);
                    break x;
                }
            }
        }

    }

    if success {
        player_pos = new_pos;
        delta_data.new_player_pos = new_pos;

        turn_memory.curr.type = .MOVE;
        turn_memory.curr.move_delta = delta_data;
        turn_memory.curr.next = turn_memory.curr + 1;
        turn_memory.curr += 1;
        turn_memory.curr.prev = turn_memory.curr - 1;
        turn_memory.curr.next = null;
        turn_count += 1;


        room_x := player_pos.x / SCREEN_TILE_WIDTH;
        room_y := player_pos.y / SCREEN_TILE_HEIGHT;

        stats.visited_room[room_x][room_y] = true;
    }

    return success;
}


// Success guaranteed indicates whether or not it's immediately possible to know the push will work and resolve.
push_block_recursively :: (initial_pos: v2i, move: v2i, stack: *Stack(v2i), delta_data: *Move_Delta_Data, success_guaranteed: *bool, links_moved: *[..] Link_Struct) -> push_into_wall : bool, destroy_block : bool {
    using context.game_state;
    using level;

    push_into_wall := false;
    destroy_block := false;
    prev_block_portal := false;

    iter_pos := initial_pos;

    // Push the initial block itself, as long as it's not the player.
    // We used to just update the player position at the very end, but this
    // procedure has been refactored to work for any block. Because of this
    // we need to remember to update the block itself.
    if initial_pos != player_pos {
        stack_push(stack, initial_pos);
    }

    while true {
        iter_pos += move;
        block := level.grid[iter_pos.x][iter_pos.y];
        // Boundary break
        if iter_pos.x < 0 || iter_pos.x >= level.dimensions.x || iter_pos.y < 0 || iter_pos.y >= level.dimensions.y {
            break;
        }

        if block_is_goal(block) {
            stack_push(stack, iter_pos);
            push_into_wall = true;
            break;
        }

        block_type := get_block_type(block);
        if block_type == .SPIKED {
            destroy_block = true;
            success_guaranteed.* = true;
            break;
        }

        if block_type == .WALL || block_type == .BLOCK_BARRIER || block_type == .INTERACTABLE {
            push_into_wall = true;
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
            success_guaranteed.* = true;
            break;
        } else {
            stack_push(stack, iter_pos);
        }
        prev_block_portal = false;
    }

    if push_into_wall {
        // Recursively try combining all blocks in the stack
        prev := v2i.{-1, -1};
        while stack_is_empty(stack) == false {
            pos := stack_pop(stack);
            defer prev = pos;
            if prev == .{-1, -1} {
                continue;
            }

            curr_block := level.grid[pos.x][pos.y];
            prev_block := level.grid[prev.x][prev.y];
            // See if two blocks can be combined, and if so, combine them and replace one with air
            curr_block_type := get_block_type(curr_block);
            prev_block_type := get_block_type(prev_block);

            if !(curr_block_type == .NUMBERED && prev_block_type == .NUMBERED && curr_block.id == prev_block.id) {
                continue;
            }

            new_block := prev_block;
            new_block.id += 1;
            // combines_block = true;

            if block_is_goal(curr_block) || block_is_goal(prev_block) {
                // Goal block cleared
                // activates_goal_block = true;
                if curr_block.flags & .VANISH_GOAL || prev_block.flags & .VANISH_GOAL {
                    new_block = BLOCK_NONE;
                    curr_is_linked_goal := curr_block.flags & .LINKED && curr_block.flags &.VANISH_GOAL;
                    prev_is_linked_goal := prev_block.flags & .LINKED && prev_block.flags &.VANISH_GOAL;
                    if curr_is_linked_goal || prev_is_linked_goal {
                        goal := ifx curr_is_linked_goal then curr_block else prev_block;
                        goal_pos := ifx curr_is_linked_goal then pos else prev;
                        for x: 0..level.dimensions.x-1 {
                            for y: 0..level.dimensions.y-1 {
                                if level.grid[x][y].interaction_id != goal.interaction_id || !(level.grid[x][y].flags & .LINKED) {
                                    continue;
                                }
                                if goal_pos == .{x, y} continue;

                                // Remove matching goal block
                                delta := add_move_delta(delta_data);
                                delta.coord = .{x, y};
                                delta.old_value = level.grid[x][y];
                                delta.new_value = BLOCK_NONE;
                                level.grid[x][y] = BLOCK_NONE;

                                break x;
                            }
                        }
                    }
                } else {
                    new_block.flags &= ~Block.Flag.GOAL;
                    new_block.flags &= ~Block.Flag.VANISH_GOAL;
                }
            }

            delta := add_move_delta(delta_data);
            delta.coord = prev;
            delta.old_value = prev_block;
            delta.new_value = new_block;

            delta = add_move_delta(delta_data);
            delta.coord = pos;
            delta.old_value = curr_block;
            delta.new_value = BLOCK_NONE;

            // For combining blocks
            delta_data.tween_changes[delta_data.tween_count] = .{prev_block, pos, prev};
            delta_data.tween_count += 1;
            delta_data.tween_changes[delta_data.tween_count] = .{prev_block, prev, prev};
            delta_data.tween_count += 1;

            level.grid[prev.x][prev.y] = new_block;
            level.grid[pos.x][pos.y] = BLOCK_NONE;
            success_guaranteed.* = true;
            break;
        }
    }

    if success_guaranteed.* {
        // This is for specifically when there's an air block or spiked block
        // This includes combinations that create an air block

        // Now we iterate through all the blocks we're pushing and actually offset them by the move in the grid
        // We also add delta data for undo
        while stack_is_empty(stack) == false {

            pos := stack_pop(stack);
            block_new_pos := pos + move;
            if get_block_type(level.grid[block_new_pos.x][block_new_pos.y]) == .PORTAL {
                block_new_pos = get_matching_portal(level.grid[block_new_pos.x][block_new_pos.y], block_new_pos);
                block_new_pos += move;
            }

            delta: *Move_Delta;

            if destroy_block {
                destroy_block = false;
            } else {
                delta = add_move_delta(delta_data);
                delta.coord = block_new_pos;
                delta.old_value = level.grid[block_new_pos.x][block_new_pos.y];
                delta.new_value = level.grid[pos.x][pos.y];
                level.grid[block_new_pos.x][block_new_pos.y] = level.grid[pos.x][pos.y];

                delta_data.tween_changes[delta_data.tween_count] = .{level.grid[pos.x][pos.y], pos, block_new_pos};
                delta_data.tween_count += 1;
            }

            delta = add_move_delta(delta_data);
            delta.coord = pos;
            delta.old_value = level.grid[pos.x][pos.y];
            delta.new_value = BLOCK_NONE;
            level.grid[pos.x][pos.y] = BLOCK_NONE;

            if level.grid[block_new_pos.x][block_new_pos.y].flags & .LINKED {                
                link : Link_Struct;
                link = .{block_new_pos, level.grid[block_new_pos.x][block_new_pos.y].interaction_id, false};
                array_add(links_moved, link);
            }
        }
    }

    return push_into_wall, destroy_block;
}

Link_Struct :: struct {
    pos: v2i;
    id: u16;
    destroy: bool;
}

operator == :: (link: Link_Struct, link2: Link_Struct) -> bool {
    return link.pos == link2.pos && link.id == link2.id;
}

goto_last_checkpoint :: () -> bool {
    using context.game_state;
    return false;
}

MOVEMENT_TWEEN_LENGTH :: 0.05;

#load "turn.jai";