Move_Delta :: struct {
    coord: v2i;
    old_value: Block;
    new_value: Block;
}

MAX_MOVE_DELTAS :: 16;
Move_Delta_Data :: struct {
    count: s32;
    deltas: [MAX_MOVE_DELTAS] Move_Delta;
    old_player_pos: v2i;
    new_player_pos: v2i;
}

MAX_UNDO :: 2000;
Move_Stack :: Stack_Circular(Move_Delta_Data, MAX_UNDO);


// Each entry represents how many moves since the last checkpoint;
MAX_CHECKPOINT_COUNT :: 30;
Move_Checkpoint_Stack :: Stack_Circular(int, MAX_CHECKPOINT_COUNT);


add_move_delta :: (data: *Move_Delta_Data) -> *Move_Delta {
    assert(data.count < MAX_MOVE_DELTAS);
    data.count += 1;
    return *data.deltas[data.count - 1];
}

player_move :: (move: v2i) -> bool, bool, bool {
    using context.game_state;
    using level;
    new_pos := player_pos + move;

    activates_goal_block := false;
    combines_block := false;
    success := false;

    delta_data : Move_Delta_Data;
    delta_data.old_player_pos = player_pos;

    if new_pos.x < 0 || new_pos.x >= level.dimensions.x || new_pos.y < 0 || new_pos.y >= level.dimensions.y {
        return false, false, false;
    } else if level.grid[new_pos.x][new_pos.y].type == .INTERACTABLE {
        generate_interaction_queue(*dialogue_state, level.grid[new_pos.x][new_pos.y]);
        return true, false, false;
    } else if level.grid[new_pos.x][new_pos.y].type == .NONE || level.grid[new_pos.x][new_pos.y].type == .BLOCK_BARRIER {
        success = true;
        player_pos = new_pos;
    } else if level.grid[new_pos.x][new_pos.y].type == .SIGNED_PHOTOGRAPH {
        success = true;

        player_pos = new_pos;

        delta := add_move_delta(*delta_data);
        delta.coord = new_pos;
        delta.old_value = .{type = .SIGNED_PHOTOGRAPH};
        delta.new_value = .{};

        level.grid[new_pos.x][new_pos.y] = .{};
        just_got_photograph = true;

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
            if block_is_goal(block) {
                stack_push(*stack, iter_pos);
                success = false;
                break;
            }

            if block.type == .WALL || block.type == .BLOCK_BARRIER || block.type == .INTERACTABLE {
                success = false;
                break;
            }

            // Encounter air block
            if block.type == .NONE {
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
                if curr_block.type == prev_block.type && curr_block.number == prev_block.number && curr_block.type != .BOULDER && curr_block.type != .BLOCK_BARRIER {
                    new_block := prev_block;
                    new_block.number += 1;
                    combines_block = true;

                    if block_is_goal(curr_block) || block_is_goal(prev_block) {
                        // Goal block cleared
                        activates_goal_block = true;

                        if curr_block.flags & .VANISH_GOAL || prev_block.flags & .VANISH_GOAL {
                            new_block = .{};
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
                    delta.new_value = .{};

                    level.grid[prev.x][prev.y] = new_block;
                    level.grid[pos.x][pos.y] = .{};
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
                delta.new_value = .{};

                level.grid[block_new_pos.x][block_new_pos.y] = level.grid[pos.x][pos.y];
                level.grid[pos.x][pos.y] = .{};
            }
        }
    }

    if success {
        if activates_goal_block {
            // Save a checkpoint for the move immediately before solving a block
            stack_push(*checkpoint_stack, move_number);
            stack_push(*checkpoint_stack, move_number+1);
        }
        delta_data.new_player_pos = new_pos;
        stack_push(*move_stack, delta_data);
        move_number += 1;
    }

    return success, combines_block, activates_goal_block;
}

move_undo :: () {
    using context.game_state;
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
    
    move_number -= 1;

    // Remove checkpoints if we just undid one
    while stack_is_empty(*checkpoint_stack) == false &&
            stack_peek(*checkpoint_stack) > move_number {
        stack_pop(*checkpoint_stack);
    }
}

goto_last_checkpoint :: () -> bool {
    using context.game_state;

    if stack_is_empty(*checkpoint_stack) {
        print("Checkpoint stack empty\n");
        return false;
    }

    last_checkpoint := stack_peek(*checkpoint_stack);
    // Permanently delete a checkpoint if we go back 1 extra checkpoint;
    if move_number == last_checkpoint {
        stack_pop(*checkpoint_stack);
        return goto_last_checkpoint();
    }

    moves_since_last := move_number - last_checkpoint;
    if moves_since_last > move_stack.count {
        while (stack_is_empty(*checkpoint_stack) == false) {
            stack_pop(*checkpoint_stack);
        }
        print("Checkpoint is too far back\n");
        return false;
    }

    for 0..moves_since_last-1 {
        move_undo();
    }
    move_number = last_checkpoint;

    return true;
}


Action :: struct {
    keys: [2] SDL_Scancode;
    timer: float;
    pressed: bool;
}

Bindings :: struct {
    actions: [4] Action;

    using Action_Type :: enum s32 #specified {
        LEFT :: 0;
        RIGHT :: 1;
        UP :: 2;
        DOWN :: 3;
    }

    actions[LEFT].keys[0] =   SDL_SCANCODE_LEFT;
    actions[LEFT].keys[1] =   SDL_SCANCODE_A;
    actions[RIGHT].keys[0] =  SDL_SCANCODE_RIGHT;
    actions[RIGHT].keys[1] =  SDL_SCANCODE_D;
    actions[UP].keys[0] =     SDL_SCANCODE_UP;
    actions[UP].keys[1] =     SDL_SCANCODE_W;
    actions[DOWN].keys[0] =   SDL_SCANCODE_DOWN;
    actions[DOWN].keys[1] =   SDL_SCANCODE_S;
}

controls :: (input: *Input_State) {
    using context.game_state.bindings;
    for *action: actions {
        just_pressed := false;
        for key: action.keys {
            if input.just_pressed[key] {
                action.pressed = true;
                just_pressed = true;
                action.timer = 0;
            } if input.just_released[key] {
                action.pressed = false;
                just_pressed = false;
                action.timer = 0;
            }
        }

        if action.pressed {
            if just_pressed || action.timer > MOVE_REPEAT_TIME {

            }
            action.timer += FRAME_TIME;
        }
    }
}