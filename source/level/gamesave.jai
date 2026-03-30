
save_game :: () {

}

load_game ::() {

}



save_game :: (level: *Level) -> bool {
    name: string;
    name.data = level.name.data;
    
    path := tprint("data/saves/gamesave");
    success := write_entire_file(path, cast(*void) level, size_of(Level));
    if success {
        return true;
    } else {
        print("Failed to save progress!\n");
        return false;
    }
}

load_game :: (level: *Level) -> bool {
    path := tprint("data/saves/gamesave");
    data, success := read_entire_file(path);
    if !success {
        if log_errors {
            print("Failed to load level at path: %\n", path);
        }
        return false;
    }

    assert(data.count >= size_of(Level));
    memcpy(level, data.data, size_of(Level));

    level.player_pos = level.player_spawn_pos;
    vfield_generate_flood_fill(level, field.*);
    generate_level_mesh();

    return true;
}
