
Turn_Data :: struct {
    type: Turn_Type = .NONE;
    prev: *Turn_Data;
    next: *Turn_Data;

    union {
        move_delta: Move_Delta_Data;
        text: Text_Buffer;
        dialogue_delta: Dialogue_Data_Delta;
    }

    Turn_Type :: enum {
        NONE;
        MOVE;
        DIALOGUE;
        DIALOGUE_CHANGE;
    }
}

MAX_TURN_UNDO :: 5000;

Turn_Memory :: struct {
    turns: [MAX_TURN_UNDO] Turn_Data;
    curr: *Turn_Data;
}

clear_turn_memory :: (mem: *Turn_Memory) {
    mem.* = .{};
    mem.curr = *mem.turns[0];
}

apply_turn :: () {
    using context.game_state;
    if turn_memory.curr.next == null {
        return;
    }
    if turn_memory.curr.type == .MOVE {
        level.player_pos = turn_memory.curr.move_delta.new_player_pos;
        for 0..turn_memory.curr.move_delta.count-1 {
            delta := turn_memory.curr.move_delta.deltas[it];
            level.grid[delta.coord.x][delta.coord.y] = delta.new_value;
        }
    } else if turn_memory.curr.type == .DIALOGUE {
        // Dialogue
        if turn_memory.curr.text.flip_open {
            dialogue_state.open = !dialogue_state.open;
        }

        if turn_memory.curr.text.size > 0 {
            dialogue_state.buffer = *turn_memory.curr.text;
            dialogue_state.index = 0;
            dialogue_state.timer = 0;
        }
    } else if turn_memory.curr.type == .DIALOGUE_CHANGE {
        delta := turn_memory.curr.dialogue_delta;
        delta.variable.* = delta.new_value;
        turn_memory.curr += 1;
        apply_turn();
        return;
    }
    turn_memory.curr += 1;
}

undo_turn :: () {
    using context.game_state;
    if turn_memory.curr.prev == null {
        return;
    }
    turn_memory.curr -= 1;
    if turn_memory.curr.type == .MOVE {
        level.player_pos = turn_memory.curr.move_delta.old_player_pos;
        // Since each move delta represents a single tile change, the order they're implemented matters.
        // For example, we could change a block to air, and then later change that same block to another block.
        // We could calculate a simplified delta list when making a move, but we can also just reverse the
        // Order we undo them, which works just fine.
        for #v2 < 0..turn_memory.curr.move_delta.count-1 {
            delta := turn_memory.curr.move_delta.deltas[it];
            level.grid[delta.coord.x][delta.coord.y] = delta.old_value;
        }
    } else if turn_memory.curr.type == .DIALOGUE {

        // NOTE: This could be error prone to have it compare with .MOVE if we add other move types later
        // A solution would be to add a "flip open" flag in the text buffer or somewhere in the Turn_Data struct
        if turn_memory.curr.text.flip_open {
            dialogue_state.open = !dialogue_state.open;
        }

        if dialogue_state.open {
            // Find last buffer
            iter := turn_memory.curr;
            while iter != null {
                iter = iter.prev;
                if iter.type == .DIALOGUE {
                    dialogue_state.buffer = *iter.text;
                    break;
                }
            }
            dialogue_state.index = dialogue_state.buffer.size;
        }
    } else if turn_memory.curr.type == .DIALOGUE_CHANGE {
        delta := turn_memory.curr.dialogue_delta;
        delta.variable.* = delta.old_value;
        undo_turn();
    }
}

// Press z to apply current_turn.next
// Press r to undo current_turn.prev;

// Example turn stack
// Move
// Move
// Move
// Dialogue
// Dialogue
// Dialogue