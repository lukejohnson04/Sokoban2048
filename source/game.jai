
#program_export
update_and_render :: (game_memory: *void, input: *Input_State, window: *SDL_Window, just_reloaded_dll: *bool) -> s32 {
    using game_state: *Game_State = xx game_memory;
    if memory_initialized == false {
        on_startup(game_state);
        game_state.memory_initialized = true;
    }

    if just_reloaded_dll.* {
        gl_load(*gl);
        just_reloaded_dll.* = false;
    }

    if input.is_pressed[SDL_SCANCODE_ESCAPE] {
        input.window_closed = true;
        return 0;
    }

    // Input
    move := v2i.{0, 0};
    if input.just_pressed[SDL_SCANCODE_LEFT] {
        move.x = -1;
    } else if input.just_pressed[SDL_SCANCODE_RIGHT] {
        move.x = 1;
    } else if input.just_pressed[SDL_SCANCODE_UP] {
        move.y = -1;
    } else if input.just_pressed[SDL_SCANCODE_DOWN] {
        move.y = 1;
    }
    if input.just_pressed[SDL_SCANCODE_R] {
        // Reset level
        memcpy(*levels[level_num], *levels_const[level_num], size_of(Level));
        player_pos = levels[level_num].player_start_pos;
    }

    level := *levels[level_num];
    beat_level := false;
    if move != .{0, 0} {
        success := player_move(game_state, move);
        if success {
            // Check for win
            // if level.grid[level.goal_block_pos.x][level.goal_block_pos.y] == level.goal_block {
                // beat_level = true;
            // }
            beat_level = true;
            for x: 0..level.dimensions.x-1 {
                for y: 0..level.dimensions.y-1 {
                    if level.grid[x][y] < 0 {
                        beat_level = false;
                        break x;
                    }
                }
            }
        }
    }



    // Render begin
    glClearColor(0.35, 0.5, 0.9, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    use_shader(texture_shader);

    view := Matrix4_Identity;
    projection := Matrix4_Identity;
    model := Matrix4_Identity;

    // camera deadzone
    {
        DEADZONE_PERCENT :: 0.05;
        player_coord : Vector2;
        player_coord.x = xx (player_pos.x * 64);
        player_coord.y = xx (player_pos.y * 64);
        screen_center := Vector2.{WINDOW_WIDTH * 0.5, WINDOW_HEIGHT * 0.5};
        camera_dest := player_coord + Vector2.{32, 32} - screen_center;
        if abs(camera.pos.x - camera_dest.x) > WINDOW_WIDTH * DEADZONE_PERCENT {
            camera.pos.x = lerp(camera.pos.x, camera_dest.x, 0.008);
        }
        if abs(camera.pos.y - camera_dest.y) > WINDOW_HEIGHT * DEADZONE_PERCENT {
            camera.pos.y = lerp(camera.pos.y, camera_dest.y, 0.008);
        }
        view = camera_view_matrix(camera);
    }
    
    projection = orthographic_projection_matrix(0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, -1, 1);
    projection = transpose(projection);

    shader_uniform(texture_shader, "projection", *projection, false);
    shader_uniform(texture_shader, "view", *view, true);
    shader_uniform(texture_shader, "model", *model, false);
    shader_uniform(texture_shader, "texture1", 0);
    shader_uniform(texture_shader, "grayscale", 0);

    bind_texture(sprites);
    
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            source : Rect;
            grayscale := false;
            if player_pos == v2i.{xx x, xx y} {
                source = Rect.{16,0,16,16};
            } else if level.grid[x][y] > 0 {
                if level.grid[x][y] == BLOCK_BOULDER {
                    source = Rect.{32,0,16,16};
                } else if level.grid[x][y] == BLOCK_WALL{
                    source = Rect.{48,0,16,16};
                } else {
                    source = Rect.{xx ((level.grid[x][y]-1) * 16),16,16,16};
                }
            } else if level.grid[x][y] < 0 {
                source = Rect.{xx ((abs(level.grid[x][y])-1) * 16),16,16,16};
                shader_uniform(texture_shader, "grayscale", 1);
                grayscale = true;
            } else {
                source = Rect.{0,0,16,16};
            }
            dest := Rect.{xx (x*64), xx (y*64), 64, 64};
            draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);
            if grayscale {
                shader_uniform(texture_shader, "grayscale", 0);
            }
        }
    }


    SDL_GL_SwapWindow(window);
    render_end_time := seconds_since_init();

    if beat_level {
        SDL_Delay(500);
        level_num += 1;
        player_pos = levels[level_num].player_start_pos;
    }

    reset_temporary_storage();
    return 1;
}


WINDOW_WIDTH :: 1280;
WINDOW_HEIGHT :: 720;
VSYNC :: true;

#load "render/render.jai";
#load "render/shader.jai";
#load "camera.jai";
#load "intrinsics.jai";
#load "game_state.jai";

#import "Windows";
#import "Basic";
#import "String";
#import "SDL";
#import "SDL_ttf";
#import "GL";
#import "File";
#import "stb_image";

Random :: #import "Random";

#load "math.jai";
#load "input.jai";
#load "move.jai";