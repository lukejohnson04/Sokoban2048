
Level :: struct {
    MAX_WIDTH :: 256;
    MAX_HEIGHT :: 256;
    dimensions := v2i.{4, 4};
    grid: [MAX_WIDTH][MAX_HEIGHT] Block;
    floor: [MAX_WIDTH][MAX_HEIGHT] Block;

    player_pos := v2i.{0, 0};
    player_spawn_pos := v2i.{0, 0};

    name : [MAX_LEVEL_NAME_LENGTH]u8;
    id : u32 = 0;
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
    level.dimensions = .{8, 8};
    level.id = 0;
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
            for #v2 < x: 0..level.dimensions.x {
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
                for #v2 < y: 0..level.dimensions.y-1 {
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


MAX_LEVEL_NAME_LENGTH :: 16;

#load "level_serializer.jai";
#load "editor.jai";
#load "visibility_field.jai";