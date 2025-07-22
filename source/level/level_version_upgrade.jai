
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
    flags: Block.Flag;
    interaction_id: u16;
}

one_time_conversion :: (level_name: string) {
    print("%, %\n", size_of(Old_Level), size_of(Level));
    print("Starting conversion\n");
    old: *Old_Level = New(Old_Level);
    new: *Level = New(Level);
    load_old_level(old, level_name);
    print("Loaded old level\n");
    level_format_converter(new, old);
    print("Converted\n");
    save_level(new, level_name);
    print("Saved\n");
    free(old);
    free(new);
    print("One time level conversion completed successfully.\n");
}

// #run one_time_conversion("open");

level_format_converter :: (level: *Level, old_level: *Old_Level) {
    level.dimensions = old_level.dimensions;
    level.player_pos = old_level.player_pos;
    level.player_spawn_pos = old_level.player_spawn_pos;
    level.dialogue_data = old_level.dialogue_data;
    level.name = old_level.name;
    level.id = old_level.id;

    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            level.grid[x][y] = .{};
            level.floor[x][y] = .{};
            memcpy(*level.grid[x][y], *old_level.grid[x][y], size_of(Old_Block));
            memcpy(*level.floor[x][y], *old_level.floor[x][y], size_of(Old_Block));
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
