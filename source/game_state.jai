
Game_State :: struct {
    texture_shader : Shader;

    intermediate_vao : GLuint;
    intermediate_vbo : GLuint;
    quad_vao : GLuint;
    quad_vbo : GLuint;

    sprites : Texture;
    sprites_imgui : Texture;

    level : Level;
    camera := Camera2D.{.{WINDOW_WIDTH/2, WINDOW_HEIGHT/2}, 1};
    editor : Editor_State;

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
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vertex), cast(*void)(size_of(float32) * 3));
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glBindVertexArray(0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    sprites = load_texture("data/sprites.png");
    sprites_imgui = load_texture("data/sprites.png");

    create_shader(*texture_shader, "data/shaders/texture.vert", "data/shaders/texture.frag");

    use_shader(texture_shader);
    shader_uniform(texture_shader, "texture1", 0);
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

load_ini_file :: (using game_state: *Game_State) -> bool {
    data, success := read_entire_file(INI_FILE_LOCATION);
    if !success {
        print("Failed to load ini file!\n");
        return false;
    }
    return load_level(*game_state.level, data);
}

Hash :: #import "Hash";