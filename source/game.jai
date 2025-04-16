#program_export
update_and_render :: (game_memory: *void, input: *Input_State, window: *SDL_Window, just_reloaded_dll: *bool, imgui_context: *ImGui.ImGuiContext) -> s32 {
    using game_state: *Game_State = xx game_memory;
    if memory_initialized == false {
        ImGui.SetCurrentContext(imgui_context);
        on_startup(game_state);

        // Attempt recovery of last close
        loaded_ini := load_ini_file(game_state);
        if loaded_ini == false {
            load_empty_level(*level);
        }
        game_state.memory_initialized = true;
    }

    if just_reloaded_dll.* {
        gl_load(*gl);
        ImGui.SetCurrentContext(imgui_context);
        just_reloaded_dll.* = false;
    }

    frame_number += 1;

    if input.is_pressed[SDL_SCANCODE_ESCAPE] {
        input.just_closed_window = true;
    }

    if input.just_closed_window {
        save_ini_file(game_state);
        // save_level(*levels[level_num]);
        return 0;
    }

    if editor.editing_level == false && just_got_photograph == false {
        move := v2i.{0, 0};
        if input.just_pressed[SDL_SCANCODE_LEFT] || input.just_pressed[SDL_SCANCODE_A] {
            move.x = -1;
        } else if input.just_pressed[SDL_SCANCODE_RIGHT] || input.just_pressed[SDL_SCANCODE_D] {
            move.x = 1;
        } else if input.just_pressed[SDL_SCANCODE_UP] || input.just_pressed[SDL_SCANCODE_W] {
            move.y = -1;
        } else if input.just_pressed[SDL_SCANCODE_DOWN] || input.just_pressed[SDL_SCANCODE_S] {
            move.y = 1;
        }

        if input.just_pressed[SDL_SCANCODE_LCTRL] {
            goto_last_checkpoint(game_state);
        }

        if input.just_pressed[SDL_SCANCODE_R] {
            move_undo(game_state);
        }

        if move != .{0, 0} {
            player_move(game_state, move);
            if just_got_photograph {
                Mix_PlayChannel(0, photograph_song, 0);
            }
        }
    }

    if just_got_photograph && Mix_Playing(0) == 0 {
        just_got_photograph = false;
    }


    // Render begin
    ImGui_ImplSdl_NewFrame(window);
    ImGui.NewFrame();

    ImGui.Begin("Window");
    draw_editor(game_state);
    ImGui.End();

    // Rendering

    glClearColor(0.35, 0.5, 0.9, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    use_shader(texture_shader);

    view := Matrix4_Identity;
    projection := Matrix4_Identity;
    model := Matrix4_Identity;

    // camera deadzone
    if editor.editing_level == false {
        DEADZONE_PERCENT :: 0.05;
        player_coord : Vector2;
        player_coord.x = xx (level.player_pos.x * 64);
        player_coord.y = xx (level.player_pos.y * 64);
        screen_center := Vector2.{WINDOW_WIDTH * 0.5, WINDOW_HEIGHT * 0.5};
        camera_dest := player_coord + Vector2.{32, 32} - screen_center;
        if abs(camera.pos.x - camera_dest.x) > WINDOW_WIDTH * DEADZONE_PERCENT {
            camera.pos.x = lerp(camera.pos.x, camera_dest.x, 0.008);
        }
        if abs(camera.pos.y - camera_dest.y) > WINDOW_HEIGHT * DEADZONE_PERCENT {
            camera.pos.y = lerp(camera.pos.y, camera_dest.y, 0.008);
        }

    } else if (SDL_GetWindowFlags(window) & SDL_WINDOW_INPUT_FOCUS) != 0 {
        DEBUG_CAMERA_SPEED :: 12;
        DEADZONE_PERCENT :: 0.01;
        mouse_pos := get_mouse_position();
        if mouse_pos.x >= WINDOW_WIDTH - WINDOW_WIDTH*DEADZONE_PERCENT {
            camera.pos.x += DEBUG_CAMERA_SPEED;
        } else if mouse_pos.x < WINDOW_WIDTH*DEADZONE_PERCENT {
            camera.pos.x -= DEBUG_CAMERA_SPEED;
        }
        if mouse_pos.y >= WINDOW_HEIGHT - WINDOW_HEIGHT*DEADZONE_PERCENT {
            camera.pos.y += DEBUG_CAMERA_SPEED;
        } else if mouse_pos.y < WINDOW_HEIGHT*DEADZONE_PERCENT {
            camera.pos.y -= DEBUG_CAMERA_SPEED;
        }
    }
    
    view = camera_view_matrix(camera);
    projection = orthographic_projection_matrix(0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, -1, 1);
    projection = transpose(projection);

    shader_uniform(texture_shader, "projection", *projection, false);
    shader_uniform(texture_shader, "view", *view, true);
    shader_uniform(texture_shader, "model", *model, false);
    shader_uniform(texture_shader, "texture1", 0);
    shader_uniform(texture_shader, "grayscale", 0);
    shader_uniform(texture_shader, "colormult", 1.0);

    bind_texture(sprites);

    if editor.editing_level {
        update_editor(game_state, input);
    }
    
    // Draw player spawn if in edit mode
    if editor.editing_level {
        source := get_block_source(BLOCK_PLAYER_SPAWN);
        dest := Rect.{xx (level.player_spawn_pos.x*64), xx (level.player_spawn_pos.y*64), 64, 64};
        draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);
    }

    // Camera bounds
    tile_begin, tile_end := get_camera_level_bounds(camera, *level);
    for x: tile_begin.x..tile_end.x {
        for y: tile_begin.y..tile_end.y {
            source, dest : Rect;
            block := level.grid[x][y];

            // Don't draw player in edit mode
            if editor.editing_level == false && level.player_pos == v2i.{xx x, xx y} {
                source = Rect.{16,0,16,16};
            } else if editor.editing_level && editor.tool == .PAINT && editor.mouse_tile == .{x, y} {
                source = get_block_source(editor.selected_block);
            } else {
                source = get_block_source(block);
            }

            dest = Rect.{xx (x*64), xx (y*64), 64, 64};
            if block < 0 {
                shader_uniform(texture_shader, "grayscale", 1);
                shader_uniform(texture_shader, "colormult", 0.8);
            }

            draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);
            if block < 0 {
                shader_uniform(texture_shader, "grayscale", 0);
                shader_uniform(texture_shader, "colormult", 1.0);
            }
        }
    }

    // Editor draw final pass
    glDisable(GL_DEPTH_TEST);
    use_shader(color_shader);
    shader_uniform(color_shader, "projection", *projection, false);
    shader_uniform(color_shader, "view", *view, true);
    shader_uniform(color_shader, "model", *model, false);

    // Select tool
    if editor.tool == .SELECT && editor.select_state != .NOT_STARTED
    {
        shader_uniform(color_shader, "color", ifx editor.select_state == .FINISHED then Vector4.{0, 1, 0, 1} else Vector4.{1, 0, 0, 1});
    
        TILE_SIZE :: 16 * 4;
        top_left := v2i.{min(editor.select_start.x, editor.select_end.x), min(editor.select_start.y, editor.select_end.y)};
        bot_right := v2i.{max(editor.select_start.x, editor.select_end.x), max(editor.select_start.y, editor.select_end.y)} + .{1, 1};

        rect : Rect;
        rect.x = xx (top_left.x * TILE_SIZE);
        rect.y = xx (top_left.y * TILE_SIZE);
        rect.w = xx ((bot_right.x-top_left.x) * TILE_SIZE);
        rect.h = xx ((bot_right.y-top_left.y) * TILE_SIZE);
        
        draw_rect_with_outline(rect, 4, color_vao, color_vbo);
    }

    // GUI Elements
    {
        use_shader(text_shader);
        gui_view := Matrix4_Identity;
        shader_uniform(text_shader, "projection", *projection, false);
        shader_uniform(text_shader, "view", *gui_view, true);
        shader_uniform(text_shader, "model", *model, false);
        shader_uniform(text_shader, "color", .{1, 1, 1, 1});

        total_goal_blocks : int;
        for x: 0..level.dimensions.x-1 {
            for y: 0..level.dimensions.y-1 {
                if level.grid[x][y] < 0 {
                    total_goal_blocks += 1;
                }
            }
        }

        score_string := sprint("%", total_goal_blocks);
        draw_text(score_string, .{32, 64}, characters, intermediate_vao, intermediate_vbo);
        glEnable(GL_DEPTH_TEST);
    }
    
    ImGui.Render();

    ImGui_ImplSdl_RenderDrawLists(ImGui.GetDrawData());

    SDL_GL_SwapWindow(window);
    render_end_time := seconds_since_init();

    reset_temporary_storage();
    return 1;
}


WINDOW_WIDTH :: 1280;
WINDOW_HEIGHT :: 720;
VSYNC :: true;

#load "render/render.jai";
#load "render/text.jai";
#load "render/shader.jai";
#load "camera.jai";
#load "intrinsics.jai";
#load "game_state.jai";

#import "Windows";
#import "Basic";
#import "String";
#import "SDL";
#import "SDL_ttf";
#import "SDL_mixer";
#import "GL";
#import "File";
#import "stb_image";
#import "freetype-2.12.1";

Random :: #import "Random";

#load "imgui.jai";
#load "math.jai";
#load "input.jai";
#load "move.jai";
#load "block.jai";
#load "level/level.jai";
