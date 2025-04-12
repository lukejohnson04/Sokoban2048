
get_block_source :: (block: int) -> Rect {
    source : Rect;
    if block > 0 {
        if block == BLOCK_PLAYER_SPAWN {
            source = Rect.{64,0,16,16};
        } else if block == BLOCK_BOULDER {
            source = Rect.{32,0,16,16};
        } else if block == BLOCK_WALL{
            source = Rect.{48,0,16,16};
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


BLOCK_WALL :: 1000;
BLOCK_BOULDER :: 1001;
BLOCK_PLAYER_SPAWN :: 1002;