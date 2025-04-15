
get_block_source :: (block: int) -> Rect {
    source : Rect;
    if block > 0 {
        if block == BLOCK_PLAYER_SPAWN {
            source = Rect.{64,0,16,16};
        } else if block == BLOCK_BOULDER {
            source = Rect.{32,0,16,16};
        } else if block == BLOCK_SIGNED_PHOTOGRAPH {
            source = Rect.{80,0,16,16};
        } else if is_block_wall(block) {
            if block == BLOCK_WALL {
                source = Rect.{48,0,16,16};
            } else {
                source = Rect.{xx ((block - BLOCK_WALL_COLOR) * 16),32,16,16};
            }
        } else {
            source = Rect.{xx ((block-1) * 16),16,16,16};
        }
    } else if block < 0 {
        source = Rect.{xx ((abs(block)-1) * 16),16,16,16};
    } else {
        source = Rect.{0,0,16,16};
    }
    return source;
}

is_block_wall :: (block: int) -> bool {
    return block == BLOCK_WALL || (block >= BLOCK_WALL_COLOR && block < BLOCK_WALL_COLOR + BLOCK_WALL_COLOR_COUNT);
}


BLOCK_WALL :: 1000;
BLOCK_BOULDER :: 1001;
BLOCK_PLAYER_SPAWN :: 1002;
BLOCK_SIGNED_PHOTOGRAPH :: 1003;

BLOCK_WALL_COLOR :: 2000;
BLOCK_WALL_COLOR_COUNT :: 8;