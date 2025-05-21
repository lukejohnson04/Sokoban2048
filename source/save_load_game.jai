
MAX_GAME_SAVE_NAME_LENGTH :: 16;
GAME_SAVE_PATH :: "saves/gamesave";
GAME_SAVE_DIRECTORY :: "saves";


save_game :: () -> bool {
    make_directory_if_it_does_not_exist(GAME_SAVE_DIRECTORY);

    path := GAME_SAVE_PATH;
    success := write_entire_file(path, cast(*void) *context.game_state.level, size_of(Level));
    return success;
}

load_save :: (log_errors := true) -> bool {
    path := GAME_SAVE_PATH;
    
    if File_Utilities.is_directory(GAME_SAVE_DIRECTORY) == false {
        if log_errors {
            print("Save folder does not exist!\n");
        }
        return false;
    }
    if File_Utilities.file_exists(path) == false {
        if log_errors {
            print("ERROR: Save at path % is missing!\n", path);
        }
        return false;
    }

    data, success := read_entire_file(path);
    if !success {
        if log_errors {
            print("Failed to load level at path: %\n", path);
        }
        return false;
    }

    assert(data.count <= size_of(Level));
    memcpy(*context.game_state.level, data.data, size_of(Level));

    return true;
}
