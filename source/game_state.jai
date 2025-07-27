/*

Asset system
Asset types:
 - Textures
 - Shaders

We can do audio later but I"m not 100% definite we'll stick with SDL mixer

*/


Game_State :: struct {
    texture_shader : Shader;
    text_shader : Shader;
    color_shader : Shader;
    mask_shader : Shader;

    intermediate_vao : GLuint;
    intermediate_vbo : GLuint;
    quad_vao : GLuint;
    quad_vbo : GLuint;
    color_vao : GLuint;
    color_vbo : GLuint;
    world_mesh : Level_Mesh;

    sprites : Resource(Texture);
    sprites_imgui : Resource(Texture);
    ui_sprites : Resource(Texture);
    spotlight : Resource(Texture);
    clockwise_arrow_texture : Resource(Texture);
    counter_clockwise_arrow_texture : Resource(Texture);
    dialogue_player_texture : Resource(Texture);

    world_buffer : Framebuffer;
    floor_buffer : Framebuffer;

    photograph_song : *Mix_Chunk;
    
    note_normal : *Mix_Chunk;
    note_echo : *Mix_Chunk;
    footsteps : [7]*Mix_Chunk;

    font_arial: Font;
    font_m5x7: Font;

    level : Level;
    field : Visibility_Field;

    just_got_photograph := false;


    camera := Camera2D.{.{WINDOW_WIDTH/2, WINDOW_HEIGHT/2}, 1};
    editor : Editor_State;
    dialogue_state : Dialogue_Player_State;

    rewinding : bool;
    rewind_meter : float32;

    turn_memory: Turn_Memory;
    turn_count := 0;


    resource_check_timer : float32;

    lighting_enabled := true;

    lights: [64] Light;
    light_count: int;

    frame_number := 0;

    bindings: Bindings;

    level_mesh_needs_update := false;

    memory_initialized := false;
}


on_startup :: () {
    context.game_state.* = .{};
    using context.game_state;

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

    mesh_init(*world_mesh.tiles);
    mesh_init(*world_mesh.gold);
    mesh_init(*world_mesh.goal);
    

    glGenVertexArrays(1, *color_vao);
    glGenBuffers(1, *color_vbo);

    load_resource(*sprites, "data/art/sprites.png");
    load_resource(*sprites_imgui, "data/art/sprites.png");
    load_resource(*dialogue_player_texture, "data/art/dialoguebox.png");
    load_resource(*ui_sprites, "data/art/ui.png");
    load_resource(*spotlight, "data/art/spotlight.png");
    load_resource(*clockwise_arrow_texture, "data/art/clockwisearrow.png");
    load_resource(*counter_clockwise_arrow_texture, "data/art/counterclockwisearrow.png");

    create_shader(*texture_shader, "data/shaders/texture.vert", "data/shaders/texture.frag");
    create_shader(*text_shader, "data/shaders/text.vert", "data/shaders/text.frag");
    create_shader(*color_shader, "data/shaders/color.vert", "data/shaders/color.frag");
    create_shader(*mask_shader, "data/shaders/mask.vert", "data/shaders/mask.frag");


    world_buffer = create_framebuffer(WINDOW_WIDTH, WINDOW_HEIGHT);
    floor_buffer = create_framebuffer(WINDOW_WIDTH, WINDOW_HEIGHT);

    use_shader(texture_shader);
    shader_uniform(texture_shader, "texture1", 0);

    use_shader(mask_shader);
    shader_uniform(mask_shader, "texture1", 0);
    shader_uniform(mask_shader, "mask_texture", 1);

    load_font(*font_arial, "arial", false, false, 48);
    load_font(*font_m5x7, "m5x7", true, false, 60);

    photograph_song = Mix_LoadWAV("data/audio/photograph_song.ogg");
    note_normal = Mix_LoadWAV("data/audio/note_normal.ogg");
    note_echo = Mix_LoadWAV("data/audio/note_echo.ogg");

    turn_memory.curr = *turn_memory.turns[0];

    // Attempt recovery of last close
    #if BUILD == .DEBUG {
        loaded_ini := load_ini_file();
        if loaded_ini == false {
            load_empty_level(*level);
        }    
    }
    #if BUILD == .RELEASE {
        success := load_save(false);
        if success == false {
            // Start a new game
            load_level(*level, "open", *field, false);
        }
        camera.pos.x = xx (level.player_pos.x * 64);
        camera.pos.y = xx (level.player_pos.y * 64);
    }
    
    level_mesh_needs_update = true;
    // vfield_generate_flood_fill(*level, field);
    // generate_level_mesh();
}

REWIND_TIME :: 1.25;
MOVE_REPEAT_TIME :: 0.4;

Hash :: #import "Hash";

#load "save_load_game.jai";
