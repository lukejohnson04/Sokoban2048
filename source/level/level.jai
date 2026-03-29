
Level :: struct {
    MAX_WIDTH :: 512;
    MAX_HEIGHT :: 512;
    dimensions := v2i.{4, 4};
    grid: [MAX_WIDTH][MAX_HEIGHT] Block;
    floor: [MAX_WIDTH][MAX_HEIGHT] Block;

    player_pos := v2i.{0, 0};
    player_spawn_pos := v2i.{0, 0};
    
    name : [MAX_LEVEL_NAME_LENGTH]u8;
    id : u32 = 0;

    dialogue_data: Dialogue_Data;
    
    level_preview_names: [1024][MAX_LEVEL_PREVIEW_NAME_LENGTH] u8;

    current_level: u16;
    grid_buffer: [MAX_WIDTH][MAX_HEIGHT] Block;

    level_visibility_field: [1024] bool;

    unlock_levels_on_load := false;
}


WORLD_ROOM_WIDTH :: (Level.MAX_WIDTH / SCREEN_TILE_WIDTH) + 1;
WORLD_ROOM_HEIGHT :: (Level.MAX_HEIGHT / SCREEN_TILE_HEIGHT) + 1;

level_set_name :: (level: *Level, name: string) {
    assert(name.count <= MAX_LEVEL_NAME_LENGTH);
    memcpy(level.name.data, name.data, name.count);
    for name.count..MAX_LEVEL_NAME_LENGTH-1 {
        level.name[it] = 0;
    }
    level.id = Hash.get_hash(name);
}

load_empty_level :: (level: *Level) {
    level.* = .{};
    level.dimensions = .{8, 8};
    level.id = 0;
}

enter_level :: (level: *Level, level_id: u16) {
    assert(level_id != 0);
    assert(level_id < 1024);
    level.current_level = level_id;

    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            block := level.grid[x][y];
            if get_block_type(block) != .LEVEL_SPAWN continue;

            if block.interaction_id == level_id {
                level.player_pos = {x, y};
                break x;
            }
        }
    }

    level.grid_buffer = level.grid;
}

is_in_world :: (level_id: u16, world_id: u16) -> bool {
    return level_id > world_id && level_id < world_id + 100;
}

get_world :: (level_id: u16) -> u16 {
    return level_id - (level_id % 100);
}

is_world :: (level_id: u16) -> bool {
    return level_id % 100 == 0;
}

finish_level :: (level: *Level) {
    assert(is_currently_in_level(level));
    assert(level.current_level < 1024);

    // If we just finshed a world, check if it's beaten
    // and if so unlock next world
    if is_world(level.current_level) {
        beaten_world := true;
        for x: 0..level.dimensions.x-1 {
            for y: 0..level.dimensions.y-1 {
                block := level.grid[x][y];
                if get_block_type(block) != .LEVEL_BLOCK continue;

                if is_in_world(block.interaction_id, level.current_level) {
                    if block.id == UNBEATEN_LEVEL_ID || block.id == LOCKED_LEVEL_ID {
                        print("Locked!\n");
                        beaten_world = false;
                        break x;
                    }
                }
            }
        }

        for x: 0..level.dimensions.x-1 {
            for y: 0..level.dimensions.y-1 {
                block := level.grid[x][y];
                if get_block_type(block) != .LEVEL_BLOCK continue;
                if block.interaction_id == level.current_level {
                    level.player_pos = {x, y};
                }

                if beaten_world {
                    if block.interaction_id == level.current_level {
                        block.id = BEATEN_LEVEL_ID;
                    }
                    if block.interaction_id == level.current_level + 100 {
                        if block.id == LOCKED_LEVEL_ID {
                            block.id = UNBEATEN_LEVEL_ID;
                        }
                    }
                }
            }
        }
        return;
    } else {
        level.grid = level.grid_buffer;
    }

    // Beat level
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            block := level.grid[x][y];
            if get_block_type(block) != .LEVEL_BLOCK continue;

            if block.interaction_id == level.current_level {
                level.player_pos = {x, y};
                if block.id == UNBEATEN_LEVEL_ID {
                    level.grid[x][y].id = BEATEN_LEVEL_ID;
                }
            }
            if block.interaction_id == level.current_level + 1 {
                if block.id == LOCKED_LEVEL_ID {
                    level.grid[x][y].id = UNBEATEN_LEVEL_ID;
                }
            }
        }
    }

    level.current_level = (level.current_level) - (level.current_level % 100);
}

level_increase_dimensions :: (level: *Level, left: int, right: int, top: int, bottom: int) {
    if level.dimensions.x + left + right > level.MAX_WIDTH {
        print("Can't increase x dimensions: % is greater than the max width!\n", level.dimensions.x + left + right);
        return;
    }
    if level.dimensions.y + top + bottom > level.MAX_HEIGHT {
        print("Can't increase y dimensions: % is greater than the max height!\n", level.dimensions.y + top + bottom);
        return;
    }

    level.player_pos.x += left;
    level.player_pos.y += top;
    level.player_spawn_pos.x += left;
    level.player_spawn_pos.y += top;
    if left != 0 {
        old_dimension := level.dimensions.x;
        level.dimensions.x += left;
        if left > 0 {
            for < x: 0..level.dimensions.x {
                for y: 0..level.dimensions.y-1 {
                    if x >= left {
                        level.grid[x][y] = level.grid[x - left][y];
                        level.floor[x][y] = level.floor[x - left][y];
                    } else {
                        level.grid[x][y] = .{};
                        level.floor[x][y] = .{};
                    }
                }
            }
        } else {
            for x: 0..level.dimensions.x-1 {
                for y: 0..level.dimensions.y-1 {
                    level.grid[x][y] = level.grid[x - left][y];
                    level.floor[x][y] = level.floor[x - left][y];
                }
            }
        }
    } if right != 0 {
        level.dimensions.x += right;
    }
    if top != 0 {
        old_dimension := level.dimensions.y;
        level.dimensions.y += top;
        if top > 0 {
            for x: 0..level.dimensions.x-1 {
                for < y: 0..level.dimensions.y-1 {
                    if y >= top {
                        level.grid[x][y] = level.grid[x][y - top];
                        level.floor[x][y] = level.floor[x][y - top];
                    } else {
                        level.grid[x][y] = .{};
                        level.floor[x][y] = .{};
                    }
                }
            }
        } else {
            for x: 0..level.dimensions.x-1 {
                for y: 0..level.dimensions.y-1 {
                    level.grid[x][y] = level.grid[x][y - top];
                    level.floor[x][y] = level.floor[x][y - top];
                }
            }
        }
    } if bottom != 0 {
        level.dimensions.y += bottom;
    }
}

is_in_bounds :: (pos: v2i, level: *Level) -> bool {
    return pos.x >= 0 && pos.y >= 0 && pos.x < level.dimensions.x && pos.y < level.dimensions.y;
}

is_currently_in_level :: (level: *Level) -> bool {
    return level.current_level != 0;
}

level_on_play :: () {
    using context.game_state;

    clear_turn_memory(*turn_memory);
    turn_count = 0;
    camera.zoom = 1;

    stats = .{};
    level_hook.active = false;
    game_sprites.count = 0;
    game_tweens.count = 0;
    generate_portal_pairs();

    if level.unlock_levels_on_load {
        unlock_all_levels(*level);
    }
    
    render_map();
}

is_valid_level :: (level_id: u16) -> bool {
    return level_id != 0 && level_id < 1024;
}

unlock_all_levels :: (level: *Level) {
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            block := level.grid[x][y];
            if get_block_type(block) != .LEVEL_BLOCK continue;
            if block.interaction_id == 0 continue;

            level.grid[x][y].id = UNBEATEN_LEVEL_ID;
        }
    }
}


MAX_LEVEL_NAME_LENGTH :: 16;

#load "level_serializer.jai";
#load "editor.jai";
#load "visibility_field.jai";
#load "generate_level_mesh.jai";