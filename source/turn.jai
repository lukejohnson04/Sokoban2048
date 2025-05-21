
Turn_Data :: struct {
    type: Turn_Type;
    prev: *Turn_Data;
    next: *Turn_Data;

    union {
        move_delta: Move_Delta_Data;
        // text: Text_Buffer;
    }

    Text_Buffer :: struct {
        text_buffer: [MAX_TEXT_LENGTH] u8;
        text_buffer_size := 0;
    }

    Turn_Type :: enum {
        MOVE;
        // DIALOGUE;
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
        print("Can't go forward any further!\n");
        return;
    }
    if turn_memory.curr.type == .MOVE {
        level.player_pos = turn_memory.curr.move_delta.new_player_pos;
        for 0..turn_memory.curr.move_delta.count-1 {
            delta := turn_memory.curr.move_delta.deltas[it];
            level.grid[delta.coord.x][delta.coord.y] = delta.new_value;
        }
    }
    turn_memory.curr += 1;
}

undo_turn :: () {
    using context.game_state;
    if turn_memory.curr.prev == null {
        print("Can't go back any further!\n");
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