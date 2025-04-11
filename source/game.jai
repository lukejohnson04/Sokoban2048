#program_export
update_and_render :: (game_memory: *void, input: *Input_State, window: *SDL_Window, just_reloaded_dll: *bool, imgui_context: *ImGui.ImGuiContext) -> s32 {
    using game_state: *Game_State = xx game_memory;
    if memory_initialized == false {
        ImGui.SetCurrentContext(imgui_context);
        on_startup(game_state);
        game_state.memory_initialized = true;
    }

    if just_reloaded_dll.* {
        gl_load(*gl);
        ImGui.SetCurrentContext(imgui_context);
        just_reloaded_dll.* = false;
    }

    frame_number += 1;

    if input.is_pressed[SDL_SCANCODE_ESCAPE] {
        input.window_closed = true;
        return 0;
    }

    // Input
    if input.just_pressed[SDL_SCANCODE_GRAVE] {
        editor.open ^= true;
    }

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
    ImGui.SetNextWindowBgAlpha(1);    
    ImGui_ImplSdl_NewFrame(window);
    ImGui.NewFrame();

    ImGui.Begin("Window");
    draw_list := ImGui.GetWindowDrawList();
    {
        window_pos := ImGui.GetCursorScreenPos();

        tile_scale :: 4;
        tile_size :: 16 * tile_scale;
        source := ImGui.ImVec2.{xx sprites_imgui.width, xx sprites_imgui.height};
        dest := ImGui.ImVec2.{xx (sprites_imgui.width * tile_scale), xx (sprites_imgui.height * tile_scale)};

        draw_list.AddImage(draw_list, cast,no_check(*void)(sprites.id), window_pos, window_pos + dest);

        // Selected tile
        focused := ImGui.IsItemActive();
        mouse_x, mouse_y := get_mouse_position();

        highlighted := false;
        highlighted_block : int;
        highlighted_xy : Vector2;

        if mouse_x >= xx window_pos.x && mouse_x < xx window_pos.x + sprites_imgui.width * tile_scale {
            if mouse_y >= xx window_pos.y && mouse_y < xx window_pos.y + sprites_imgui.height * tile_scale {
                highlighted_xy.x = floor((mouse_x - window_pos.x) / tile_size);
                highlighted_xy.y = floor((mouse_y - window_pos.y) / tile_size);

                highlighted_block = xx (highlighted_xy.x + highlighted_xy.y * 8);
                highlighted = true;
            }
        }
    
        if focused && highlighted {
            if ImGui.IsMouseDown(ImGui.MouseButton.Left) {
                real := highlighted_block;
                if highlighted_block == 2 {
                    real = BLOCK_BOULDER;
                } else if highlighted_block == 3 {
                    real = BLOCK_WALL;
                } else if highlighted_block >= 8 {
                    real = highlighted_block - 7;
                }
                editor.selected_block = real;
                editor.selected_block_pos = highlighted_xy;
            }
        }

        if highlighted && editor.selected_block_pos != highlighted_xy {
            p1 := ImGui.ImVec2.{highlighted_xy.x * tile_size, highlighted_xy.y * tile_size};
            p2 := p1 + .{tile_size, 0};
            p3 := p1 + .{tile_size, tile_size};
            p4 := p1 + .{0, tile_size};
            colf := Vector4.{1, 1, 0, 1};
            
            draw_list.AddQuad(draw_list, window_pos + p1, window_pos + p2, window_pos + p3, window_pos + p4, ImGui.GetColorU32(colf), 2);
        }

        if editor.selected_block {
            p1 := ImGui.ImVec2.{editor.selected_block_pos.x * tile_size, editor.selected_block_pos.y * tile_size};
            p2 := p1 + .{tile_size, 0};
            p3 := p1 + .{tile_size, tile_size};
            p4 := p1 + .{0, tile_size};
            colf := Vector4.{0, 1, 0, 1};
            
            draw_list.AddQuad(draw_list, window_pos + p1, window_pos + p2, window_pos + p3, window_pos + p4, ImGui.GetColorU32(colf), 2);
        }
    }
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

    bind_texture(sprites);

    mouse_world_pos := get_mouse_world_pos(camera);
    mouse_tile := v2i.{xx (mouse_world_pos.x / 64), xx (mouse_world_pos.y / 64)};
    if input.mouse_just_pressed {
        if mouse_tile.x >= 0 && mouse_tile.y >= 0 && mouse_tile.x < level.dimensions.x && mouse_tile.y < level.dimensions.y {
            level.grid[mouse_tile.x][mouse_tile.y] = editor.selected_block;
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
            }

            draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);
            if block < 0 {
                shader_uniform(texture_shader, "grayscale", 0);
            }
        }
    }


    ImGui.Render();

    ImGui_ImplSdl_RenderDrawLists(ImGui.GetDrawData());

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

#load "imgui.jai";
#load "math.jai";
#load "input.jai";
#load "move.jai";
#load "editor.jai";
#load "block.jai";