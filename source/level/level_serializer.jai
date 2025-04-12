
save_level :: (level: *Level, name: string) -> bool {
    level_set_name(level, name);
    assert(level.id != 0);
    path := tprint("data/world/%", name);
    success := write_entire_file(path, cast(*void) level, size_of(Level));
    if success {
        return true;
    } else {
        print("Failed to save level\n");
        return false;
    }
}

load_level :: (level: *Level, name: string) -> bool {
    path := tprint("data/world/%", name);
    data, success := read_entire_file(tprint("data/world/%", name));
    if !success {
        print("Failed to load level at path: %\n", path);
        return false;
    }
    assert(data.count >= size_of(Level));
    memcpy(level, data.data, size_of(Level));

    level.player_pos = level.player_spawn_pos;

    return true;
}