
Medusa_Fire_Data :: struct {
    origin: v2i;
    length: int;
}

Medusa_Fire_Array :: struct {
    data: [8] Medusa_Fire_Data;
    count: int;
}

medusa_firing_add :: (array: *Medusa_Fire_Array) -> *Medusa_Fire_Data {
    ptr := *array.data[array.count];
    array.count += 1;
    return ptr;
}

update_medusa_cannons :: () {
    using context.game_state;
    medusa_firings.count = 0;
    
    screen := get_current_screen_coord(*level);

    lower_x := screen.x * SCREEN_TILE_WIDTH;
    lower_y := screen.y * SCREEN_TILE_HEIGHT;
    upper_x := lower_x + SCREEN_TILE_WIDTH;
    upper_y := lower_y + SCREEN_TILE_HEIGHT;

    for x: lower_x..upper_x-1 {
        for y: lower_y..upper_y-1 {
            tile := *level.grid[x][y];
            if get_block_type(tile) == .MEDUSA_CANNON {
                tile.id += 1;
                if tile.id == MEDUSA_ID_END {
                    tile.id = MEDUSA_ID_BEGIN;
                    // Fire medusa cannon
                    fire_medusa_cannon(.{x, y});
                }
            }
        }
    }
    
}

fire_medusa_cannon :: (cannon_pos: v2i) {
    using context.game_state;
    pos := cannon_pos;
    screen := get_current_screen_coord(*level);
    lower_x := screen.x * SCREEN_TILE_WIDTH;
    lower_y := screen.y * SCREEN_TILE_HEIGHT;
    upper_x := lower_x + SCREEN_TILE_WIDTH;
    upper_y := lower_y + SCREEN_TILE_HEIGHT;

    using pos;
    while x < upper_x {
        x += 1;
        type := get_block_type(level.grid[x][y]);
        if type == .BOULDER {
            level.grid[x][y].id = 144;
            break;
        }
        if type == .WALL {
            break;
        }
    }

    data := medusa_firing_add(*medusa_firings);
    data.origin = cannon_pos;
    data.length = x - cannon_pos.x - 2;
}