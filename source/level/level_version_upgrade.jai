
Old_Level :: Level;

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
    level.* = old_level.*;
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            level.grid[x][y] = old_level.grid[x][y];
            level.floor[x][y] = old_level.floor[x][y];

            level.grid[x][y].id += xx ((cast(int)(level.grid[x][y].id) / 8) * 8);
            level.floor[x][y].id += xx ((cast(int)(level.floor[x][y].id) / 8) * 8);
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
