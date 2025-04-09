
Game_State :: struct {
    texture_shader : Shader;

    intermediate_vao : GLuint;
    intermediate_vbo : GLuint;
    quad_vao : GLuint;
    quad_vbo : GLuint;

    sprites : Texture;

    player_pos := v2i.{0,0};

    level_num := 5;

    camera := Camera2D.{.{WINDOW_WIDTH/2, WINDOW_HEIGHT/2}, 1};

    memory_initialized := false;
}

BLOCK_WALL :: 1000;
BLOCK_BOULDER :: 1001;

Level :: struct {
    MAX_WIDTH :: 32;
    MAX_HEIGHT :: 32;
    dimensions := v2i.{4, 4};
    grid: [MAX_WIDTH][MAX_HEIGHT]int;

    goal_block_pos : v2i;
    goal_block := 3;
    player_start_pos := v2i.{0, 0};
}

levels_const : [10]Level = #run load_levels();
levels : [10]Level = #run load_levels();
load_levels :: () -> [10]Level {
    a : [10]Level;
    
    // Level 1
    num := 0;

    a[num].dimensions = .{5, 1};
    a[num].grid[2][0] = 1;
    a[num].grid[4][0] = -1;

    // Level 2
    num += 1;
    a[num].dimensions = .{5, 2};
    a[num].grid[2][1] = 1;
    a[num].grid[3][1] = 1;

    a[num].grid[4][1] = -2;

    // Level 3
    num += 1;
    a[num].dimensions = .{4, 4};

    a[num].grid[2][2] = 1;
    a[num].grid[3][2] = 1;
    a[num].grid[3][1] = 2;

    a[num].grid[3][3] = -3;


    // Level 4
    num += 1;
    a[num].dimensions = .{4, 4};
    a[num].grid[1][1] = 1;
    a[num].grid[2][1] = 2;
    a[num].grid[3][1] = 1;

    a[num].grid[3][3] = -3;

    // Level 5
    num += 1;
    a[num].dimensions = .{6, 3};
    a[num].grid[3][1] = -1;

    a[num].grid[5][2] = 1;


    // Level 6
    num += 1;
    a[num].dimensions = .{6, 6};
    a[num].grid[2][1] = 1;
    a[num].grid[3][1] = 2;
    a[num].grid[2][2] = 1;
    a[num].grid[3][2] = 2;

    for 0..5 {
        a[num].grid[4][it] = BLOCK_WALL;
        a[num].grid[5][it] = BLOCK_WALL;
    }

    a[num].grid[1][4] = BLOCK_WALL;
    a[num].grid[2][4] = BLOCK_WALL;

    a[num].grid[4][5] = 2;
    a[num].grid[5][5] = -4;


    num += 1;
    a[num].dimensions = .{8, 9};
    a[num].player_start_pos = .{2, 2};
    for 0..8 {
        a[num].grid[it][0] = 2;
        a[num].grid[0][it] = 2;
        a[num].grid[7][it] = 2;
        a[num].grid[it][8] = 3;
        if it < 6 {
            a[num].grid[it][6] = BLOCK_WALL;
        }
    }
    a[num].grid[6][6] = 2;
    a[num].grid[4][3] = 1;
    a[num].grid[5][3] = 1;
    a[num].grid[2][7] = 1;

    a[num].grid[1][7] = -1;


    num += 1;
    a[num].dimensions = .{6, 6};
    a[num].player_start_pos = .{0, 0};
    a[num].grid[5][2] = BLOCK_WALL;
    a[num].grid[4][4] = 1;
    a[num].grid[5][4] = 1;

    a[num].grid[5][5] = -3;




    // Open world begin
    num += 1;
    
    a[num].dimensions = .{32,32};
    a[num].player_start_pos = .{2, 2};
    a[num].grid[31][31] = -1;

    for 0..7 {
        a[num].grid[it][0] = BLOCK_WALL;
        a[num].grid[it][7] = BLOCK_WALL;
        a[num].grid[0][it] = BLOCK_WALL;
        a[num].grid[7][it] = BLOCK_WALL;
    }

    a[num].grid[5][3] = 1;
    a[num].grid[7][3] = -1;

    num += 1;
    a[num].dimensions = .{6, 6};
    a[num].grid[2][1] = 1;
    a[num].grid[3][1] = 2;
    a[num].grid[2][2] = 1;
    a[num].grid[3][2] = 2;

    for 0..5 {
        a[num].grid[4][it] = BLOCK_WALL;
        a[num].grid[5][it] = BLOCK_WALL;
    }

    a[num].grid[1][4] = BLOCK_WALL;
    a[num].grid[2][4] = BLOCK_WALL;

    a[num].grid[4][5] = 2;
    a[num].grid[5][5] = -4;

    return a;
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

    create_shader(*texture_shader, "data/shaders/texture.vert", "data/shaders/texture.frag");

    use_shader(texture_shader);
    shader_uniform(texture_shader, "texture1", 0);

    SDL_SetRelativeMouseMode(SDL_TRUE);

    player_pos = levels[level_num].player_start_pos;
}
