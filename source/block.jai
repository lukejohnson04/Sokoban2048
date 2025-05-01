
get_block_source :: (block: Block) -> Rect {
    source : Rect;
    if block.type == .NONE {
        source = Rect.{0, 0, 16, 16};
        if block.number > 0 {
            row : int = (block.number - 1) / 8;
            source = Rect.{xx (((block.number - 1) % 8) * 16), xx (48 + (row * 16)), 16, 16};
        }
    } else if block.type == .BLOCK_BARRIER {
        source = Rect.{96,0,16,16};
    } else if block.type == .PLAYER_SPAWN {
        source = Rect.{64,0,16,16};
    } else if block.type == .BOULDER {
        source = Rect.{32,0,16,16};
    } else if block.type == .SIGNED_PHOTOGRAPH {
        source = Rect.{80,0,16,16};
    } else if block.type == .INTERACTABLE {
        source = Rect.{xx (block.number * 16),112,16,16};
        if block.interaction_id == 10_000 {
            source = Rect.{112,0,16,16};
        }
    } else if block.type == .WALL {
        if block.number == 0 {
            source = Rect.{48,0,16,16};
        } else {
            source = Rect.{xx ((block.number - 1) * 16), 32, 16, 16};
        }
    } else if block.type == .NUMBERED {
        source = Rect.{xx ((block.number-1) * 16),16,16,16};
    } else {
        source = Rect.{0,0,16,16};
    }
    return source;
}


block_is_goal :: (block: Block) -> bool {
    return (block.flags & (.GOAL | .VANISH_GOAL)) != 0;
}

Block :: struct {
    type: Block_Type;
    number: u8;
    flags: Flag;
    interaction_id: u16;

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

    Flag :: enum u8 #specified {
        GOAL :: 0x1;
        VANISH_GOAL :: 0x2;
        FLIPPED_X :: 0x4;
        FLIPPED_Y :: 0x8;
    }
}
