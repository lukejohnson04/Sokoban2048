#program_export
update_and_render :: (game_memory: *void, input: *Input_State, window: *SDL_Window, just_reloaded_dll: *bool, imgui_context: *ImGui.ImGuiContext) -> s32 {
    using game_state: *Game_State = xx game_memory;
    if memory_initialized == false {
        ImGui.SetCurrentContext(imgui_context);
        on_startup(game_state);
        load_level("level", *levels[level_num]);
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
        save_level(*levels[level_num]);
        return 0;
    }

    level := *levels[level_num];

    if editor.editing_level == false {
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

        if move != .{0, 0} {
            player_move(game_state, move);
        }
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
    shader_uniform(texture_shader, "colormult", 1.0);

    bind_texture(sprites);

    mouse_world_pos := get_mouse_world_pos(camera);
    mouse_tile := v2i.{xx (mouse_world_pos.x / 64), xx (mouse_world_pos.y / 64)};
    if input.mouse_just_pressed || input.rmouse_just_pressed {
        if mouse_tile.x >= 0 && mouse_tile.y >= 0 && mouse_tile.x < level.dimensions.x && mouse_tile.y < level.dimensions.y {
            level.grid[mouse_tile.x][mouse_tile.y] = editor.selected_block;
            if input.rmouse_just_pressed {
                level.grid[mouse_tile.x][mouse_tile.y] *= -1;
            }
        }
    }
    
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            source, dest : Rect;
            block := level.grid[x][y];
            if player_pos == v2i.{xx x, xx y} {
                source = Rect.{16,0,16,16};
            } else if mouse_tile == .{x, y} {
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

#load "imgui.jai";
#load "math.jai";
#load "input.jai";
#load "move.jai";
#load "editor.jai";
#load "block.jai";
#load "level_serializer.jai";