
Old_Level :: struct {
    MAX_WIDTH :: 512;
    MAX_HEIGHT :: 512;
    dimensions := v2i.{4, 4};
    grid: [MAX_WIDTH][MAX_HEIGHT] Block;
    floor: [MAX_WIDTH][MAX_HEIGHT] Block;

    player_pos := v2i.{0, 0};
    player_spawn_pos := v2i.{0, 0};
    
    name : [MAX_LEVEL_NAME_LENGTH]u8;
    id : u32 = 0;

    dialogue_data: Dialogue_Data;
}


Old_Block :: struct {
    id: u16;
    flags: Flag;
    interaction_id: u16;
    
    union {
        struct {
            turns_on_active: u8;
            turns_on_inactive: u8;
            timer_turns_left: u8;
            timer_is_solid: bool;
        }
    }

    Flag :: enum u8 #specified {
        GOAL :: 1;
        VANISH_GOAL :: 2;
        FLIPPED_X :: 4;
        FLIPPED_Y :: 8;
        TIMER :: 16;
        LINKED :: 32;
        ROTATE_90 :: 64;
        ROTATE_180 :: 128;
    }
}

one_time_conversion :: (level_name: string) {
    print("%, %\n", size_of(Old_Level), size_of(Level));
    print("Starting conversion\n");
    old: *Old_Level = New(Old_Level);
    new: *Level = New(Level);
    load_old_level(old, level_name);
    print("Loaded old level\n");
    level_format_converter(new, old);
    print("Converted\n");
    save_level(new, level_name);
    print("Saved\n");
    free(old);
    free(new);
    print("One time level conversion completed successfully.\n");
}

// #run one_time_conversion("yowza");
// #run one_time_conversion("open");

level_format_converter :: (level: *Level, old_level: *Old_Level) {
    level.* = {};
    memcpy(level, old_level, size_of(Old_Level));

    // level.dimensions = old_level.dimensions;
    // level.player_pos = old_level.player_pos;
    // level.player_spawn_pos = old_level.player_spawn_pos;
    // level.dialogue_data = old_level.dialogue_data;
    // level.name = old_level.name;
    // level.id = old_level.id;

    // for x: 0..level.dimensions.x-1 {
    //     for y: 0..level.dimensions.y-1 {
    //         level.grid[x][y] = .{};
    //         level.floor[x][y] = .{};
    //         copy_block :: (block: *Block, old_block: *Old_Block) {
    //             block.id = xx old_block.id;
    //             block.flags = xx old_block.flags;
    //             block.spawn_time = 0.0;

    //             block.interaction_id = old_block.interaction_id;

    //             block.turns_on_active = old_block.turns_on_active;
    //             block.turns_on_inactive = old_block.turns_on_inactive;
    //             block.timer_turns_left = old_block.timer_turns_left;
    //             block.timer_is_solid = old_block.timer_is_solid;
    //         }

    //         copy_block(*level.grid[x][y], *old_level.grid[x][y]);
    //         copy_block(*level.floor[x][y], *old_level.floor[x][y]);
    //     }
    // }
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
