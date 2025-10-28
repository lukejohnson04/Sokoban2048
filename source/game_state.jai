/*

Asset system
Asset types:
 - Textures
 - Shaders

We can do audio later but I"m not 100% definite we'll stick with SDL mixer

*/


Game_State :: struct {
    texture_shader : Resource(Shader);
    text_shader : Resource(Shader);
    color_shader : Resource(Shader);
    mask_shader : Resource(Shader);

    intermediate_vao : GLuint;
    intermediate_vbo : GLuint;
    quad_vao : GLuint;
    quad_vbo : GLuint;
    color_vao : GLuint;
    color_vbo : GLuint;

    world_mesh : Level_Mesh;
    tween_mesh : Level_Mesh;

    resource_tracker: Resource_Tracker;

    sprites : Resource(Texture);
    sprite_particles : Resource(Texture);
    sprites_imgui : Resource(Texture);
    ui_sprites : Resource(Texture);
    spotlight : Resource(Texture);
    clockwise_arrow_texture : Resource(Texture);
    counter_clockwise_arrow_texture : Resource(Texture);
    dialogue_player_texture : Resource(Texture);

    particle_system : Particle_System;

    world_buffer : Framebuffer;
    floor_buffer : Framebuffer;

    photograph_song : *Mix_Chunk;
    
    note_normal : *Mix_Chunk;
    note_echo : *Mix_Chunk;
    footsteps : [7]*Mix_Chunk;

    font_arial: Resource(Font);
    font_m5x7: Resource(Font);

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

    time_of_last_move: float64;
    movement_tween: bool;

    lighting_enabled := true;

    lights: [64] Light;
    light_count: int;

    portal_list: [..] v2i;



    frame_number := 0;

    delta: float32;
    prev_frame_time: float64;

    bindings: Bindings;

    stats: Game_Stats;

    map: Map_State;

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

    level_mesh_init(*world_mesh);
    level_mesh_init(*tween_mesh);
    

    glGenVertexArrays(1, *color_vao);
    glGenBuffers(1, *color_vbo);

    load_texture_from_disk(*sprites, "data/art/sprites.png");
    load_texture_from_disk(*sprite_particles, "data/art/particles.png");
    load_texture_from_disk(*sprites_imgui, "data/art/sprites.png");
    load_texture_from_disk(*dialogue_player_texture, "data/art/dialoguebox.png");
    load_texture_from_disk(*ui_sprites, "data/art/ui.png");
    load_texture_from_disk(*spotlight, "data/art/spotlight.png");
    load_texture_from_disk(*clockwise_arrow_texture, "data/art/clockwisearrow.png");
    load_texture_from_disk(*counter_clockwise_arrow_texture, "data/art/counterclockwisearrow.png");

    load_shader_from_disk(*texture_shader, "data/shaders/texture.vert", "data/shaders/texture.frag");
    load_shader_from_disk(*text_shader, "data/shaders/text.vert", "data/shaders/text.frag");
    load_shader_from_disk(*color_shader, "data/shaders/color.vert", "data/shaders/color.frag");
    load_shader_from_disk(*mask_shader, "data/shaders/mask.vert", "data/shaders/mask.frag");

    world_buffer = create_framebuffer(WINDOW_WIDTH, WINDOW_HEIGHT);
    floor_buffer = create_framebuffer(WINDOW_WIDTH, WINDOW_HEIGHT);
    map_init(*map);

    use_shader(texture_shader);
    uniform(texture_shader, "texture1", 0);

    use_shader(mask_shader);
    uniform(mask_shader, "texture1", 0);
    uniform(mask_shader, "mask_texture", 1);

    load_font_from_disk(*font_arial, "data/fonts/arial.ttf", "", "", 48);
    if !load_font_from_disk(*font_m5x7, "data/fonts/m5x7.ttf", "data/fonts/m5x7.ttf", "", 60) print("huh\n");

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
}

REWIND_TIME :: 1.25;
MOVE_REPEAT_TIME :: 0.4;

Hash :: #import "Hash";

#load "save_load_game.jai";
