BUILD_TYPE :: enum #specified {
    RELEASE :: 0;
    DEBUG :: 1;
    PROFILE :: 2;
}

BUILD :: BUILD_TYPE.DEBUG;


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
        input.just_closed_window = true;
    }

    if input.just_closed_window {
        #if BUILD == .DEBUG {
            save_ini_file(game_state);
        }
        #if BUILD == .RELEASE {
            save_game(game_state);
        }
        return 0;
    }

    if editor.editing_level == false && just_got_photograph == false && dialogue_state.open == false {
        starting_move_number := move_number;

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

        if input.just_pressed[SDL_SCANCODE_GRAVE] {
            editor.enabled = !editor.enabled;
        }

        if move != .{0, 0} {
            success, combines_block, activates_goal_block := player_move(game_state, move);
            if success {
                play_sound_effect(footsteps[move_number % footsteps.count]);
                if combines_block {
                    if activates_goal_block {
                        play_sound_effect(note_echo);
                    } else {
                        play_sound_effect(note_normal);
                    }
                }
                if just_got_photograph {
                    Mix_PlayChannel(0, photograph_song, 0);
                }
            }
        }

        if move_number != starting_move_number {
            vfield_generate_flood_fill(*level, field);
            generate_level_mesh(game_state);
        }
    }
    
    if dialogue_state.open || dialogue_state.nodes.count > 0 {
        dialogue_update(*dialogue_state, input);
    }

    if just_got_photograph && Mix_Playing(0) == 0 {
        just_got_photograph = false;
    }

    if editor.enabled && editor.editing_level {
        update_editor(game_state, input);
    }


    // Render begin
    if editor.enabled {
        ImGui_ImplSdl_NewFrame(window);
        ImGui.NewFrame();

        ImGui.Begin("Window");
        draw_editor(game_state);
        ImGui.End();
    }

    // Reload
    // check_resource_reload()

    // Rendering
    glClearColor(0, 0, 0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    use_shader(texture_shader);

    view := Matrix4_Identity;
    projection := Matrix4_Identity;
    model := Matrix4_Identity;

    // camera deadzone
    if editor.enabled == false || editor.editing_level == false {
        DEADZONE_PERCENT :: 0.05;
        player_coord : Vector2;
        player_coord.x = xx (level.player_pos.x * 64);
        player_coord.y = xx (level.player_pos.y * 64);
        camera_dest := player_coord + Vector2.{32, 32};
        if abs(camera.pos.x - camera_dest.x) > WINDOW_WIDTH * DEADZONE_PERCENT {
            camera.pos.x = lerp(camera.pos.x, camera_dest.x, 0.008);
        }
        if abs(camera.pos.y - camera_dest.y) > WINDOW_HEIGHT * DEADZONE_PERCENT {
            camera.pos.y = lerp(camera.pos.y, camera_dest.y, 0.008);
        }

    } else if (SDL_GetWindowFlags(window) & SDL_WINDOW_INPUT_FOCUS) != 0 {
        DEBUG_CAMERA_SPEED := 12 * (1.0 / camera.zoom);
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
    shader_uniform(texture_shader, "gold", 0);
    shader_uniform(texture_shader, "colormult", 1.0);

    resource_check_timer += FRAME_TIME;
    if resource_check_timer > 0.25 {
        check_resource_reload(*sprites);
        resource_check_timer = 0;
    }

    bind_texture(sprites);

    light_levels: [Level.MAX_WIDTH][Level.MAX_HEIGHT] float;
    for x: 0..level.dimensions.x {
        for y: 0..level.dimensions.y {
            level: float;
            level = xx field[x][y].steps;
            level = max(0.0, (level - 1));
            level = min(level, 12);
            light_levels[x][y] = pow(0.95, level);
        }
    }

    mesh_draw(*world_mesh.tiles);
    
    shader_uniform(texture_shader, "colormult", 0.8);
    shader_uniform(texture_shader, "grayscale", 1);
    mesh_draw(*world_mesh.goal);
    shader_uniform(texture_shader, "grayscale", 0);
    shader_uniform(texture_shader, "gold", 1);
    mesh_draw(*world_mesh.gold);
    shader_uniform(texture_shader, "gold", 0);
    shader_uniform(texture_shader, "colormult", 1.0);

    if editor.editing_level == false {
        source := Rect.{16,0,16,16};
        dest := Rect.{xx (level.player_pos.x*64), xx (level.player_pos.y*64), 64, 64};
        draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);
    }
    

    if editor.editing_level && (editor.tool == .BRUSH || editor.tool == .FILL) && is_in_bounds(editor.mouse_tile, *level) {
        block := editor.selected_block;
        source := get_block_source(block);
        dest := Rect.{xx (editor.mouse_tile.x * 64), xx (editor.mouse_tile.y * 64), 64, 64};
        draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);
    }

    
    // Camera bounds
    if false {
        tile_begin, tile_end := get_camera_level_bounds(camera, *level);
        for x: tile_begin.x..tile_end.x {
            for y: tile_begin.y..tile_end.y {
                source, dest : Rect;
                block := level.grid[x][y];
                dest = Rect.{xx (x*64), xx (y*64), 64, 64};

                // Draw blocks that aren't visible
                if editor.editing_level == false && field[x][y].visible == false {
                    continue;
                }

                // Don't draw player in edit mode
                if editor.editing_level == false && level.player_pos == v2i.{xx x, xx y} {
                    source = Rect.{16,0,16,16};
                } else {
                    if editor.editing_level && (editor.tool == .BRUSH || editor.tool == .FILL) && editor.mouse_tile == .{x, y} {
                        block = editor.selected_block;
                    } else {
                        if block.type == .NONE && block.number == 0 {
                            block = level.floor[x][y];
                        }
                    }
                    source = get_block_source(block);
                }

                colormult : float = 1;
                if block_is_goal(block) {
                    if block.flags & .GOAL {
                        shader_uniform(texture_shader, "grayscale", 1);
                    } else {
                        shader_uniform(texture_shader, "gold", 1);
                    }
                    colormult = 0.8;
                }

                shader_uniform(texture_shader, "colormult", colormult);


                if block.flags & .FLIPPED_X {
                    dest.x += dest.w;
                    dest.w *= -1;
                }
                if block.flags & .FLIPPED_Y {
                    dest.y += dest.h;
                    dest.h *= -1;
                }

                draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);
                if block_is_goal(block) {
                    if block.flags & .GOAL {
                        shader_uniform(texture_shader, "grayscale", 0);
                    } else {
                        shader_uniform(texture_shader, "gold", 0);
                    }
                    shader_uniform(texture_shader, "colormult", 1.0);
                }
            }
        }
    }

    if editor.editing_level == false {
        source := Rect.{16,0,16,16};
        dest := Rect.{xx (level.player_pos.x*64), xx (level.player_pos.y*64), 64, 64};
        draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);
    }


    if editor.enabled && editor.editing_level {
        spawn : Block;
        spawn.type = .PLAYER_SPAWN;
        source := get_block_source(spawn);
        dest := Rect.{xx (level.player_spawn_pos.x*64), xx (level.player_spawn_pos.y*64), 64, 64};
        draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);
    }

    // Editor draw final pass
    glDisable(GL_DEPTH_TEST);
    use_shader(color_shader);
    shader_uniform(color_shader, "projection", *projection, false);
    shader_uniform(color_shader, "view", *view, true);
    shader_uniform(color_shader, "model", *model, false);

    // Select tool
    if editor.enabled && editor.editing_level && (editor.tool == .SELECT || editor.tool == .MOVE) && editor.select_state != .NOT_STARTED
    {
        color : Vector4;
        if editor.tool == .SELECT {
            if editor.select_state == .FINISHED {
                color = Vector4.{0, 1, 0, 1};
            } else {
                color = Vector4.{1, 0, 0, 1};
            }
        } else if editor.tool == .MOVE {
            if editor.move_state == .NOT_STARTED {
                color = Vector4.{0, 1, 0, 1};
            } else {
                color = Vector4.{1, 0, 0, 1};
            }
        }
        shader_uniform(color_shader, "color", color);
    
        TILE_SIZE :: 16 * 4;
        start, end : v2i;
        start.x = min(editor.select_end.x, editor.select_start.x);
        start.y = min(editor.select_end.y, editor.select_start.y);
        end.x   = max(editor.select_end.x, editor.select_start.x);
        end.y   = max(editor.select_end.y, editor.select_start.y);
        
        if editor.tool == .MOVE && editor.move_state == .STARTED {
            offset := editor.move_end - editor.move_start;
            start += offset;
            end += offset;
        }

        selection_size := end - start + .{1, 1};

        rect : Rect;
        rect.x = xx (start.x * TILE_SIZE);
        rect.y = xx (start.y * TILE_SIZE);
        rect.w = xx (selection_size.x * TILE_SIZE);
        rect.h = xx (selection_size.y * TILE_SIZE);
        
        draw_rect_with_outline(rect, 4, color_vao, color_vbo);
    }

    // GUI Elements
    // Draw dialogue player
    if dialogue_state.open {
        use_shader(texture_shader);
        shader_uniform(texture_shader, "view", *Matrix4_Identity, true);
        bind_texture(dialogue_player_texture);
        draw_texture(.{0, 0, 320, 180}, .{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}, *dialogue_player_texture, intermediate_vao, intermediate_vbo);
        use_shader(text_shader);
        shader_uniform(text_shader, "projection", *projection, false);
        shader_uniform(text_shader, "view", *Matrix4_Identity, true);
        shader_uniform(text_shader, "model", *model, false);
        shader_uniform(text_shader, "color", .{1, 1, 1, 1});
        
        str: string;
        str.data = queue_peek(*dialogue_state.nodes).text_buffer.data;
        str.count = dialogue_state.index;
        draw_text(str, .{64, 100}, *font_m5x7, intermediate_vao, intermediate_vbo, WINDOW_WIDTH - 200);
    }

    #if true {
        use_shader(text_shader);
        shader_uniform(text_shader, "projection", *projection, false);
        shader_uniform(text_shader, "view", *Matrix4_Identity, true);
        shader_uniform(text_shader, "model", *model, false);
        shader_uniform(text_shader, "color", .{1, 0, 0, 1});

        if editor.editing_level {
            if is_in_bounds(editor.mouse_tile, *level) {
                tile := level.grid[editor.mouse_tile.x][editor.mouse_tile.y];
                if tile.type == .NONE {
                    tile = level.floor[editor.mouse_tile.x][editor.mouse_tile.y];
                }
                struct_str := sprint("%", tile);
                draw_text(struct_str, .{32, 64}, *font_m5x7, intermediate_vao, intermediate_vbo);
            }
        }

        // total_goal_blocks : int;
        // total_secrets : int;
        // for x: 0..level.dimensions.x-1 {
        //     for y: 0..level.dimensions.y-1 {
        //         if block_is_goal(level.grid[x][y]) {
        //             total_goal_blocks += 1;
        //         } else if level.grid[x][y].type == .SIGNED_PHOTOGRAPH {
        //             total_secrets += 1;
        //         }
        //     }
        // }

        // score_string := sprint("%", total_secrets);
        // draw_text(score_string, .{32, 64}, *font_arial, intermediate_vao, intermediate_vbo);
        // draw_text(score_string, .{32, 128}, *font_arial, intermediate_vao, intermediate_vbo);
    }
    
    if editor.enabled {
        ImGui.Render();
        ImGui_ImplSdl_RenderDrawLists(ImGui.GetDrawData());
    }

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

File_Utilities :: #import "File_Utilities";
Random :: #import "Random";

#load "imgui.jai";
#load "math.jai";
#load "input.jai";
#load "move.jai";
#load "block.jai";
#load "level/level.jai";
#load "audio/audio.jai";
#load "dialogue.jai";
#load "assets/assets.jai";