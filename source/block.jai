
// Immediate mode animation??
// run_animation :: () -> Animation {
//     anim: Animation;
//     anim.frames = [0.1, 0.2, 0.35]
//     anim.rects = {..., ..., ...}
//     anim.id = RUN_ANIM
//     return anim
// }
// do_animation (#run run_animation())
//
// do_animation :: (block: Block, anim: Animation) {
//      if block.anim != anim.id {
//          block.timer = 0
//          block.anim = anim;
//      }
//      // Normal iterate through frametimes and pick frame to set
// }


get_block_source :: (id: u16) -> Rect {
    block: Block;
    block.id = id;
    return get_block_source(block);
}

get_block_source :: (block: Block) -> Rect {
    source : Rect;
    stride := cast(int)(context.game_state.sprites.width / 16.0);
    source = Rect.{xx ((block.id % stride) * 16), xx ((block.id / stride) * 16), 16, 16};
    if get_block_type(block) == .NUMBERED {
        source.h = 16;
    }

    if block.id == 138 || block.id == 139 || block.id == 140 {
        using context.game_state;
        frame_time := 0.5;

        offset := block.id - 138;
        frame_num := ((cast(s32)((global_timer / frame_time)) % 3) + offset) % 3;
        source.x -= offset * 16;
        source.x += frame_num * 16;
        
    } if block.id == 128 || block.id == 240 {
        using context.game_state;

        if dialogue_state.open && dialogue_line_finished() == false {
            frame_1_len :: 0.25;
            frame_2_len :: 0.2;
            frame_3_len :: 0.15;
            frame_time :: frame_1_len + frame_2_len + frame_3_len;
            cycles := cast(s32)((global_timer / frame_time));
            time_delta := global_timer - (cycles * frame_time);
            source.x = 48;
            if time_delta > frame_1_len {
                if time_delta > frame_1_len + frame_2_len {
                    source.x += 32;
                } else {
                    source.x += 16;
                } 
            }
        } else {
            // Blink animation
            frame_1_len :: 3.0;
            frame_2_len :: 0.125;
            frame_3_len :: 0.125;
            frame_time :: frame_1_len + frame_2_len + frame_3_len;

            cycles := cast(s32)((global_timer / frame_time));
            time_delta := global_timer - (cycles * frame_time);
            if time_delta > frame_1_len {
                if time_delta > frame_1_len + frame_2_len {
                    source.x += 32;
                } else {
                    source.x += 16;
                } 
            }
        }
    }

    return source;
}


block_is_goal :: (block: Block) -> bool {
    return (block.flags & (.GOAL | .VANISH_GOAL)) != 0;
}

block_blocks_light :: (block: Block) -> bool {
    type := get_block_type(block);
    return type == .WALL || type == .BOULDER || type == .INTERACTABLE || type == .NUMBERED;
}

block_number :: (block: Block) -> u16 {
    return block.id - FIRST_NUMBERED_BLOCK_ID;
}

block_is_light_source :: (block: Block) -> bool {
    return block.id == 38;
}

get_matching_portal :: (tile: Block, pos: v2i) -> v2i {
    using context.game_state;
    if tile.interaction_id == 0 {
        return .{-1, -1};
    }

    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            if pos.x == x && pos.y == y continue;
            iter := level.grid[x][y];
            if get_block_type(iter) != .PORTAL continue;
            if iter.interaction_id == tile.interaction_id {
                return .{x, y};
            }
        }
    }
    return .{-1, -1};
}

get_block_type :: (block: Block) -> Block_Type {
    if block.flags & .TIMER {
        if timer_is_active(block) == false {
            return .NONE;
        }
    }

    if block.id >= MEDUSA_ID_BEGIN && block.id <= MEDUSA_ID_END {
        return .MEDUSA_CANNON;
    }

    if block.id == {
        case 0; return .NONE;
        case 2; return .BOULDER;
        case 3; return .WALL;
        case 4; return .PLAYER_SPAWN;
        case 5; return .SIGNED_PHOTOGRAPH;
        case 6; return .BLOCK_BARRIER;
        case 7; return .INTERACTABLE; // Save point specifically
        case 9; return .SPIKED;
        case 10; return .PORTAL;
        
        case 24; return .LEVEL_GOAL;
        case 26; return .LEVEL_SPAWN;

        case 272; return .LEVEL_BLOCK;
        case 273; return .LEVEL_BLOCK;
        case 274; return .LEVEL_BLOCK;

        case 128; return .INTERACTABLE;
        case 179; return .INTERACTABLE;
        case 196; return .INTERACTABLE;
        case 197; return .INTERACTABLE;
        case 240; return .INTERACTABLE;

        case 144; return .WALL;
        case 145; return .BOULDER;
    }

    if (block.id >= 24 && block.id < 32) || (block.id >= 40 && block.id < 48) {
        return .WALL;
    }
    if block.id >= 16 && block.id < 24 {
        return .NUMBERED;
    }
    if (block.id >= 32 && block.id < 40) || (block.id >= 48 && block.id < 50) {
        return .WALL;
    }
    if (block.id >= 12 && block.id <= 15) || (block.id >= 28 && block.id <= 31) ||
        (block.id >= 44 && block.id <= 47) || (block.id >= 60 && block.id <= 63) {
            return .WALL;
        }

    if block.id >= 48 && block.id < 96 {
        return .NONE;
    }
    if block.id >= 96 && block.id < 104 {
        return .INTERACTABLE;
    }
    if block.id >= 112 && block.id < 120 {
        return .INTERACTABLE;
    }

    return .NONE;
}

// Note to self:
/*

The last thing I did was write the get_block_type method. The first thing I should do to continue fixing up the tile system
is make sure that it works exactly as it did before, except with the id instead of a type field.

*/


Block :: struct {
    id: u16;
    flags: Flag;
    interaction_id: u16;
    spawn_time: float;
    
    union {
        struct {
            turns_on_active: u8;
            turns_on_inactive: u8;
            timer_turns_left: u8;
            timer_is_solid: bool;
        }
    }

    Flag :: enum u8 #specified {
        GOAL :: 1;
        VANISH_GOAL :: 2;
        FLIPPED_X :: 4;
        FLIPPED_Y :: 8;
        TIMER :: 16;
        LINKED :: 32;
        ROTATE_90 :: 64;
        ROTATE_180 :: 128;
    }
}

LOCKED_LEVEL_ID :: 272;
UNBEATEN_LEVEL_ID :: 273;
BEATEN_LEVEL_ID :: 274;

get_block_rotation :: (block: Block) -> s32 {
    return xx (block.flags & (.ROTATE_90 | .ROTATE_180));
}

// Linked blocks work as follows:
// If a block has the linked flag, it will link up with all blocks that have the same interaction id
// If a linked block is pushed, it's linked block will also be pushed (if possible). If it's not possible
// for the other block to be pushed, for example if it hits a wall, then only the initial block will move.

BLOCK_NONE := Block.{};

timer_turns_left :: (block: Block) -> u8 {
    timer_length := cast(s64)(block.turns_on_active) + xx block.turns_on_inactive;
    inc := cast(u8)(context.game_state.turn_count % timer_length);
    // Block is inactive, timer counting down to active
    if inc >= block.turns_on_active {
        return xx (timer_length - inc);
    // Block is active, timer counting down to inactive
    } else {
        return xx (block.turns_on_active - inc);
    }
}

timer_is_active :: (block: Block) -> bool {
    timer_length := cast(s64)(block.turns_on_active) + xx block.turns_on_inactive;
    turns_to_next := cast(u8)(context.game_state.turn_count % timer_length);
    if turns_to_next < block.turns_on_active {
        return true;
    }
    return false;
}


Block_Type :: enum u8 #specified {
    NONE :: 0;
    NUMBERED :: 1;
    WALL :: 2;
    BOULDER :: 3;
    SIGNED_PHOTOGRAPH :: 4;
    PLAYER_SPAWN :: 5;
    BLOCK_BARRIER :: 6;
    INTERACTABLE :: 7;
    SPIKED :: 8;
    PORTAL :: 9;
    MEDUSA_CANNON :: 10;
    LEVEL_BLOCK :: 11;
    LEVEL_SPAWN :: 12;
    LEVEL_GOAL :: 13;
}



// New_Block :: struct {
//     id: u8;
//     flags: Block.Flag;
//     interaction_id: u16;
// }


// We'll want to implement the backend first before we hook it up to the editor.
// We can do this by removing the Block_Type field and replacing it with a Tile_Id field.
// Then, we hardcode the necessary lookups in some method.

FIRST_NUMBERED_BLOCK_ID : u16 : 8;
MEDUSA_ID_BEGIN :: 146;
MEDUSA_ID_END :: 150;

/*
 Block struct overview

 Flags:
    Solid
    Pushable
    Numbered
    Blocks visibility
    Interactable

 Local flags:
    Goal block
    Vanishing goal block
    flip x
    flip y
 Local data: Interaction id


Note: Floors can be stored as literally just texture id (atlas coords)
Number currently just represents the texture id, although it's used for combining numbered blocks as well.
It would be good to have like enum names for every tile maybe?

Here's the thing: We want every tile that is visibly the same to work the exact same across the game. We don't want
there to ever be like a numbered block that somehow can't combine, or a boulder that can't be pushed because some
flag is disabled.
*/

operator == :: (a: Block, b: Block) -> bool {
    return a.id == b.id &&
            a.flags == b.flags &&
            a.interaction_id == b.interaction_id;
}