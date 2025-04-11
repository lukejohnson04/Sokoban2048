save_level :: (level: *Level) {
    write_entire_file("level", cast(*void) level, size_of(Level));
}

load_level :: (name: string, level: *Level) {
    data, success := read_entire_file(name);
    if !success {
        print("Failed to load level %\n", name);
    }
    assert(data.count >= size_of(Level));
    memcpy(level, data.data, size_of(Level));
}

load_level :: (name: string) -> Level {
    level: Level;
    load_level(name, *level);
    return level;
}