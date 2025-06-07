
get_block_source :: (block: Block) -> Rect {
    source : Rect;
    source = Rect.{xx ((block.id % 8) * 16), xx ((block.id / 8) * 16), 16, 16};

    return source;
}


block_is_goal :: (block: Block) -> bool {
    return (block.flags & (.GOAL | .VANISH_GOAL)) != 0;
}

block_blocks_light :: (block: Block) -> bool {
    type := get_block_type(block);
    return type == .WALL || type == .BOULDER || type == .INTERACTABLE || type == .NUMBERED;
}

block_number :: (block: Block) -> u8 {
    return block.id - FIRST_NUMBERED_BLOCK_ID;
}

block_is_light_source :: (block: Block) -> bool {
    return block.id == 22;
}

get_block_type :: (block: Block) -> Block_Type {
    if block.id == {
        case 0; return .NONE;
        case 2; return .BOULDER;
        case 3; return .WALL;
        case 4; return .PLAYER_SPAWN;
        case 5; return .SIGNED_PHOTOGRAPH;
        case 6; return .BLOCK_BARRIER;
        case 7; return .INTERACTABLE; // Save point specifically
    }
    if block.id >= 8 && block.id < 16 {
        return .NUMBERED;
    }
    if block.id >= 16 && block.id < 25 {   
        return .WALL;
    }
    if block.id >= 24 && block.id < 48 {
        return .NONE;
    }
    if block.id >= 48 && block.id < 56 {
        return .INTERACTABLE;
    }
    if block.id >= 56 && block.id < 64 {
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
    id: u8;
    flags: Flag;
    interaction_id: u16;

    Flag :: enum u8 #specified {
        GOAL :: 1;
        VANISH_GOAL :: 2;
        FLIPPED_X :: 4;
        FLIPPED_Y :: 8;
    }
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
}

// New_Block :: struct {
//     id: u8;
//     flags: Block.Flag;
//     interaction_id: u16;
// }


// We'll want to implement the backend first before we hook it up to the editor.
// We can do this by removing the Block_Type field and replacing it with a Tile_Id field.
// Then, we hardcode the necessary lookups in some method.

FIRST_NUMBERED_BLOCK_ID : u8 : 8;

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