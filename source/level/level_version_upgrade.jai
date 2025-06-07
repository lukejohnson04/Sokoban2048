
Old_Level :: struct {
    MAX_WIDTH :: 512;
    MAX_HEIGHT :: 512;
    dimensions := v2i.{4, 4};
    grid: [MAX_WIDTH][MAX_HEIGHT] Old_Block;
    floor: [MAX_WIDTH][MAX_HEIGHT] Old_Block;

    player_pos := v2i.{0, 0};
    player_spawn_pos := v2i.{0, 0};

    name : [MAX_LEVEL_NAME_LENGTH]u8;
    id : u32 = 0;
    
    dialogue_data: Dialogue_Data;
}

Old_Block :: struct {
    id: u8;
    number: u8;
    flags: Block.Flag;
    interaction_id: u16;
}


one_time_conversion :: (level_name: string) {
    old: *Old_Level = New(Old_Level);
    new: *Level = New(Level);
    load_old_level(old, level_name);
    level_format_converter(new, old);
    save_level(new, level_name);
    free(old);
    free(new);
    print("One time level conversion completed successfully.\n");
}

// #run one_time_conversion("open");

level_format_converter :: (level: *Level, old_level: *Old_Level) {
    level.* = .{};
    level.dimensions = old_level.dimensions;
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            old_block := old_level.grid[x][y];
            old_floor := old_level.floor[x][y];

            level.grid[x][y].id = old_block.id;
            level.grid[x][y].flags = old_block.flags;
            level.grid[x][y].interaction_id = old_block.interaction_id;

            level.floor[x][y].id = old_floor.id;
            level.floor[x][y].flags = old_floor.flags;
            level.floor[x][y].interaction_id = old_floor.interaction_id;
        }
    }
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
