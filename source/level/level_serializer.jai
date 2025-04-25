
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


INI_FILE_LOCATION :: "data/game.ini";

Ini_File_Data :: struct {
    level: Level;
    editor: Editor_State;
    camera: Camera2D;
}

save_ini_file :: (using game_state: *Game_State) -> bool {
    last_level := level.name;
    path := INI_FILE_LOCATION;

    ini_data : Ini_File_Data;
    ini_data.level = level;
    ini_data.editor = editor;
    ini_data.camera = camera;

    success := write_entire_file(path, cast(*void) *ini_data, size_of(Ini_File_Data));

    if !success {
        print("Failed to save ini file!\n");
        return false;
    }
    return true;
}

load_ini_file :: (using game_state: *Game_State) -> bool {
    data, success := read_entire_file(INI_FILE_LOCATION);
    if !success {
        print("Failed to load ini file!\n");
        return false;
    }
    if data.count != size_of(Ini_File_Data) {
        print("Failed to load ini file!\n");
        return false;
    }

    ini_data : *Ini_File_Data = xx data.data;

    level = ini_data.level;
    editor = ini_data.editor;
    camera = ini_data.camera;

    move_stack = .{};
    return true;
}

#load "level_version_upgrade.jai";