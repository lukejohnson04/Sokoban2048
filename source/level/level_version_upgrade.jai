
Old_Dialogue_Data :: struct {
    interaction_count: [256] [256] u16;
    talked_to_mayor: s32;
}

Old_Level :: struct {
    MAX_WIDTH :: 256;
    MAX_HEIGHT :: 256;
    dimensions := v2i.{4, 4};
    grid: [MAX_WIDTH][MAX_HEIGHT] Block;
    floor: [MAX_WIDTH][MAX_HEIGHT] Block;

    player_pos := v2i.{0, 0};
    player_spawn_pos := v2i.{0, 0};

    name : [MAX_LEVEL_NAME_LENGTH]u8;
    id : u32 = 0;

    dialogue_data: Old_Dialogue_Data;
}


one_time_conversion :: (level_name: string) {
    old: Old_Level;
    new: Level;
    load_old_level(*old, level_name);
    level_format_converter(*new, *old);
    save_level(*new, level_name);
    print("Finished conversion\n");
}

// #run one_time_conversion("open");

level_format_converter :: (level: *Level, old_level: *Old_Level) {
    level.* = .{};
    memcpy(level, old_level, size_of(Old_Level));
    level.dialogue_data = .{};

    // level.player_pos = old_level.player_pos;
    // level.player_spawn_pos = old_level.player_spawn_pos;
    // memcpy(level.name.data, old_level.name.data, MAX_LEVEL_NAME_LENGTH);
    // level.id = old_level.id;
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
