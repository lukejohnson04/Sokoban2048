win32_game_code :: struct {
    dll: HMODULE;
    LastWriteTime: FILETIME;
    UpdateAndRender: (*void, *Input_State, *SDL_Window, *bool) -> s32;
    is_valid := false;
};

Win32GetLastWriteTime :: (filename: *u8) -> FILETIME{
    LastWriteTime := FILETIME.{};

    FindData : WIN32_FIND_DATAW;
    FindHandle : HANDLE = FindFirstFileA(filename, *FindData);
    if (FindHandle != INVALID_HANDLE_VALUE) {
        LastWriteTime = FindData.ftLastWriteTime;
    }
    FindClose(FindHandle);
    return LastWriteTime;
}

LoadGameCode :: (game_code: *win32_game_code) {
    sourceDLL := ".build/game.dll";
    tempDLL := ".build/TempGameCode.dll";

    game_code.LastWriteTime = Win32GetLastWriteTime(sourceDLL.data);

    CopyFileA(sourceDLL.data, tempDLL.data, xx false);
    game_code.dll = LoadLibraryA(tempDLL.data);

    if (game_code.dll) {
        val := GetProcAddress(game_code.dll, "update_and_render");
        game_code.UpdateAndRender = val.((*void, *Input_State, *SDL_Window, *bool) -> s32);
        game_code.is_valid = val != null;
    } else {
        print("Couldn't load temporary DLL!\n");
    }

    if (game_code.is_valid == false) {
        game_code.UpdateAndRender = null;
        print("Failed to load game code!\n");
    }
}


UnloadGameCode :: (game_code: *win32_game_code) {
    if (game_code.dll) {
        FreeLibrary(game_code.dll);
    } else {
        print("Game code isn't valid so it can't be unloaded!\n");
    }

    game_code.dll = null;
    game_code.is_valid = false;
    game_code.UpdateAndRender = null;
    game_code.LastWriteTime = .{};
}
