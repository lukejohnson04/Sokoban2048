Level :: struct {
    MAX_WIDTH :: 32;
    MAX_HEIGHT :: 32;
    dimensions := v2i.{4, 4};
    grid: [MAX_WIDTH][MAX_HEIGHT]int;

    player_pos := v2i.{0, 0};
    player_spawn_pos := v2i.{0, 0};

    name : [MAX_LEVEL_NAME_LENGTH]u8;
    id : u32 = 0;
}

level_set_name :: (level: *Level, name: string) {
    assert(name.count <= MAX_LEVEL_NAME_LENGTH);
    memcpy(level.name.data, name.data, name.count);
    for name.count..MAX_LEVEL_NAME_LENGTH-1 {
        level.name[it] = 0;
    }
    level.id = Hash.get_hash(name);
}

load_empty_level :: (level: *Level) {
    level.* = .{};
    level.dimensions = .{Level.MAX_WIDTH, Level.MAX_HEIGHT};
    level.id = 0;
}


MAX_LEVEL_NAME_LENGTH :: 16;

#load "level_serializer.jai";
#load "editor.jai";