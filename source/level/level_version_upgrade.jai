
Old_Level :: struct {
    MAX_WIDTH :: 128;
    MAX_HEIGHT :: 128;
    dimensions := v2i.{4, 4};
    grid: [MAX_WIDTH][MAX_HEIGHT]int;

    player_pos := v2i.{0, 0};
    player_spawn_pos := v2i.{0, 0};

    name : [MAX_LEVEL_NAME_LENGTH]u8;
    id : u32 = 0;
}

one_time_conversion :: (level_name: string) {
    old: Old_Level;
    new: Level;
    load_old_level(*old, level_name);
    level_format_converter(*new, *old);
    save_level(*new, level_name);
    print("Finished conversion\n");
}

// #run one_time_conversion();

level_format_converter :: (level: *Level, old_level: *Old_Level) {
    level.* = .{};
    level.dimensions = old_level.dimensions;
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            block: Block;
            if is_block_wall(old_level.grid[x][y]) {
                block.type = .WALL;
                if old_level.grid[x][y] != BLOCK_WALL {
                    // colored wall
                    block.number = xx (old_level.grid[x][y] - BLOCK_WALL_COLOR + 1);
                }
            } else if old_level.grid[x][y] == {
                case 0;                         block = .{};
                case BLOCK_BOULDER;             block.type = .BOULDER;
                case BLOCK_PLAYER_SPAWN;        block.type = .PLAYER_SPAWN;
                case BLOCK_SIGNED_PHOTOGRAPH;   block.type = .SIGNED_PHOTOGRAPH;
                case; {
                    // Numbered block
                    block.type = .NUMBERED;
                    block.number = xx abs(old_level.grid[x][y]);
                    if old_level.grid[x][y] < 0 {
                        block.flags |= Block.Flag.GOAL;
                    }
                }
            }
            level.grid[x][y] = block;
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
