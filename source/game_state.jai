
Game_State :: struct {
    texture_shader : Shader;
    text_shader : Shader;
    color_shader : Shader;

    intermediate_vao : GLuint;
    intermediate_vbo : GLuint;
    quad_vao : GLuint;
    quad_vbo : GLuint;
    color_vao : GLuint;
    color_vbo : GLuint;

    sprites : Texture;
    sprites_imgui : Texture;

    photograph_song : *Mix_Chunk;

    font_arial: Font;

    level : Level;
    field : Visibility_Field;

    just_got_photograph := false;


    camera := Camera2D.{.{WINDOW_WIDTH/2, WINDOW_HEIGHT/2}, 1};
    editor : Editor_State;

    move_stack : Move_Stack;
    move_number : int;
    checkpoint_stack : Move_Checkpoint_Stack;

    frame_number := 0;

    memory_initialized := false;
}


on_startup :: (using game_state: *Game_State) {
    game_state.* = .{};
    gl_load(*gl);

    {
        time := current_time_monotonic();
        seed := to_microseconds(time);
        Random.random_seed(<< (cast(*u64) *seed));
    }

    glGenBuffers(1, *intermediate_vbo);
    glGenVertexArrays(1, *intermediate_vao);

    glGenBuffers(1, *quad_vbo);
    glGenVertexArrays(1, *quad_vao);
    glBindBuffer(GL_ARRAY_BUFFER, quad_vbo);
    glBufferData(GL_ARRAY_BUFFER, size_of(Vertex) * QUAD_VERTICES.count, QUAD_VERTICES.data, GL_STATIC_DRAW);
    glBindVertexArray(quad_vao);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex), null);
    glEnableVertexAttribArray(0);
    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glGenVertexArrays(1, *color_vao);
    glGenBuffers(1, *color_vbo);

    sprites = load_texture("data/sprites.png");
    sprites_imgui = load_texture("data/sprites.png");

    create_shader(*texture_shader, "data/shaders/texture.vert", "data/shaders/texture.frag");
    create_shader(*text_shader, "data/shaders/text.vert", "data/shaders/text.frag");
    create_shader(*color_shader, "data/shaders/color.vert", "data/shaders/color.frag");

    use_shader(texture_shader);
    shader_uniform(texture_shader, "texture1", 0);

    load_font("data/fonts/arial.ttf", *font_arial);

    photograph_song = Mix_LoadWAV("data/audio/photograph_song.ogg");

    // Attempt recovery of last close
    #if BUILD == .DEBUG {
        loaded_ini := load_ini_file(game_state);
        if loaded_ini == false {
            load_empty_level(*level);
        }    
    }
    #if BUILD == .RELEASE {
        success := load_save(game_state, false);
        if success == false {
            // Start a new game
            load_level(*level, "open", false);
        }
    }

    vfield_generate_flood_fill(game_state);
    camera.pos.x = xx (level.player_pos.x * 64);
    camera.pos.y = xx (level.player_pos.y * 64);
}


INI_FILE_LOCATION :: "data/game.ini";

save_ini_file :: (using game_state: *Game_State) -> bool {
    last_level := level.name;
    path := INI_FILE_LOCATION;
    success := write_entire_file(path, cast(*void) level.name.data, MAX_LEVEL_NAME_LENGTH);
    if !success {
        print("Failed to save ini file!\n");
        return false;
    }
    return true;
}

// Auto save
load_ini_file :: (using game_state: *Game_State) -> bool {
    data, success := read_entire_file(INI_FILE_LOCATION);
    if !success {
        return false;
    }
    result := load_level(*level, data, log_errors = false);
    if result {
        if result {
            move_stack = .{};
        }
    }
    return result;
}


Hash :: #import "Hash";

#load "save_load_game.jai";