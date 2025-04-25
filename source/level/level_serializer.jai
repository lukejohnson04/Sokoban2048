
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

load_level :: (level: *Level, name: string, field: *Visibility_Field, log_errors := true) -> bool {
    path := tprint("data/world/%", name);
    data, success := read_entire_file(tprint("data/world/%", name));
    if !success {
        if log_errors {
            print("Failed to load level at path: %\n", path);
        }
        return false;
    }

    assert(data.count >= size_of(Level));
    memcpy(level, data.data, size_of(Level));

    level.player_pos = level.player_spawn_pos;

    if field != null {
        vfield_generate_flood_fill(level, field.*);
    }

    return true;
}

#load "level_version_upgrade.jai";