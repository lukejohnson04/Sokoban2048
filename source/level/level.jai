Old_Level :: struct {
    MAX_WIDTH :: 256;
    MAX_HEIGHT :: 256;
    dimensions := v2i.{4, 4};
    grid: [MAX_WIDTH][MAX_HEIGHT]int;

    player_pos := v2i.{0, 0};
    player_spawn_pos := v2i.{0, 0};

    name : [MAX_LEVEL_NAME_LENGTH]u8;
    id : u32 = 0;
}

Level :: struct {
    MAX_WIDTH :: 128;
    MAX_HEIGHT :: 128;
    dimensions := v2i.{4, 4};
    grid: [MAX_WIDTH][MAX_HEIGHT]int;

    player_pos := v2i.{0, 0};
    player_spawn_pos := v2i.{0, 0};

    name : [MAX_LEVEL_NAME_LENGTH]u8;
    id : u32 = 0;
}

one_time_conversion :: () {
    old: Old_Level;
    new: Level;
    load_old_level(*old, "open");
    level_format_converter(*new, *old);
    save_level(*new, "open");
    print("Finished conversion\n");
}

level_format_converter :: (level: *Level, old_level: *Old_Level) {
    level.* = .{};
    level.dimensions = old_level.dimensions;
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            level.grid[x][y] = old_level.grid[x][y];
        }
    }

    level.player_pos = old_level.player_pos;
    level.player_spawn_pos = old_level.player_spawn_pos;
    memcpy(level.name.data, old_level.name.data, MAX_LEVEL_NAME_LENGTH);
    level.id = old_level.id;
}

load_old_level :: (level: *Old_Level, name: string) -> bool {
    path := tprint("data/world/%", name);
    data, success := read_entire_file(tprint("data/world/%", name));
    if !success {
        print("Failed to load level at path: %\n", path);
        return false;
    }

    assert(data.count >= size_of(Old_Level));
    memcpy(level, data.data, size_of(Old_Level));

    level.player_pos = level.player_spawn_pos;

    return true;
}

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
    level.dimensions = .{Level.MAX_WIDTH, Level.MAX_HEIGHT};
    level.id = 0;
}


level_increase_dimensions :: (level: *Level, left: int, right: int, top: int, bottom: int) {
    if level.dimensions.x + left + right > level.MAX_WIDTH {
        print("Can't increase x dimensions: % is greater than the max width!\n", level.dimensions.x + left);
        return;
    }
    if level.dimensions.y + top + bottom > level.MAX_WIDTH {
        print("Can't increase y dimensions: % is greater than the max height!\n", level.dimensions.x + left);
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
            for #v2 < x: 0..old_dimension-1 {
                for y: 0..level.dimensions.y-1 {
                    if x >= left {
                        level.grid[x][y] = level.grid[x - left][y];
                    } else {
                        level.grid[x][y] = 0;
                    }
                }
            }
        } else {
            for x: 0..level.dimensions.x-1 {
                for y: 0..level.dimensions.y-1 {
                    level.grid[x][y] = level.grid[x - left][y];
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
            for x: 0..level.dimensions.y-1 {
                for #v2 < y: 0..old_dimension-1 {
                    if y >= top {
                        level.grid[x][y] = level.grid[x][y - top];
                    } else {
                        level.grid[x][y] = 0;
                    }
                }
            }
        } else {
            for x: 0..level.dimensions.x-1 {
                for y: 0..level.dimensions.y-1 {
                    level.grid[x][y] = level.grid[x][y - top];
                }
            }
        }
    } if bottom != 0 {
        level.dimensions.y += bottom;
    }
}



MAX_LEVEL_NAME_LENGTH :: 16;

#load "level_serializer.jai";
#load "editor.jai";