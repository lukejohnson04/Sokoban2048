BUILD_TYPE :: enum #specified {
    RELEASE :: 0;
    DEBUG :: 1;
    PROFILE :: 2;
}

BUILD :: BUILD_TYPE.RELEASE;

#add_context game_state: *Game_State;

#program_export
update_and_render :: (game_memory: *void, input: *Input_State, window: *SDL_Window, just_reloaded_dll: *bool, imgui_context: *ImGui.ImGuiContext) -> s32 {
    game_state := cast(*Game_State) game_memory;
    Remap_Context();
    context.game_state = game_state;
    using context.game_state;

    if memory_initialized == false {
        ImGui.SetCurrentContext(imgui_context);
        on_startup();
        memory_initialized = true;
    }

    if just_reloaded_dll.* {
        gl_load(*gl);
        ImGui.SetCurrentContext(imgui_context);
        if editor.editing_level == false {
            vfield_generate_flood_fill(*level, field);
        }
        generate_level_mesh();
        just_reloaded_dll.* = false;
    }

    frame_number += 1;

    if input.is_pressed[SDL_SCANCODE_ESCAPE] {
        input.just_closed_window = true;
    }

    if input.just_closed_window {
        #if BUILD == .DEBUG {
            save_ini_file();
        }
        #if BUILD == .RELEASE {
            save_game();
        }
        return 0;
    }

    if editor.editing_level == false && just_got_photograph == false && dialogue_state.open == false {
        starting_move_number := move_number;

        // This is a shocking amount of code for how simple this task is
        target_dir := v2i.{0, 0};
        move := v2i.{0, 0};
        if input.is_pressed[SDL_SCANCODE_LEFT] || input.is_pressed[SDL_SCANCODE_A] {
            target_dir.x = -1;
        } else if input.is_pressed[SDL_SCANCODE_RIGHT] || input.is_pressed[SDL_SCANCODE_D] {
            target_dir.x = 1;
        } if input.is_pressed[SDL_SCANCODE_UP] || input.is_pressed[SDL_SCANCODE_W] {
            target_dir.y = -1;
        } else if input.is_pressed[SDL_SCANCODE_DOWN] || input.is_pressed[SDL_SCANCODE_S] {
            target_dir.y = 1;
        }
        
        // In the case multiple are pressed, pick the one more recently pressed
        if target_dir != move_direction {
            if target_dir.x != 0 && target_dir.y != 0 {
                if target_dir.x != move_direction.x && target_dir.y == move_direction.y {
                    target_dir.y = 0;
                } else if target_dir.x == move_direction.x && target_dir.y != move_direction.y {
                    target_dir.x = 0;
                } else {
                    target_dir.y = 0;
                }
            }
            if move_direction == .{0, 0} {
                move = target_dir;
            }
            move_direction = target_dir;
            move_repeat_timer = 0;
        } else if move_direction != .{0, 0} {
            move_repeat_timer += FRAME_TIME;
            if move_repeat_timer > MOVE_REPEAT_TIME {
                move_repeat_timer -= MOVE_REPEAT_TIME;
                move = target_dir;
            }
        }

        if input.just_pressed[SDL_SCANCODE_LCTRL] {
            rewinding = true;
            rewind_meter = 0;
        }

        if rewinding {
            if input.is_pressed[SDL_SCANCODE_LCTRL] == false {
                rewinding = false;
            } else {
                rewind_meter += FRAME_TIME;
                if rewind_meter > REWIND_TIME {
                    rewind_meter = 0;
                    rewinding = false;
                    goto_last_checkpoint();
                }
            }
        }

        if input.just_pressed[SDL_SCANCODE_R] {
            move_undo();
        }

        if input.just_pressed[SDL_SCANCODE_GRAVE] {
            editor.enabled = !editor.enabled;
        }

        if move != .{0, 0} {
            success, combines_block, activates_goal_block := player_move(move);
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
            generate_level_mesh();
        }
    }
    
    if dialogue_state.open || dialogue_state.nodes.count > 0 {
        dialogue_update(*dialogue_state, input);
    }

    if just_got_photograph && Mix_Playing(0) == 0 {
        just_got_photograph = false;
    }

    if editor.enabled && editor.editing_level {
        update_editor(input);
    }


    // Render begin
    if editor.enabled {
        ImGui_ImplSdl_NewFrame(window);
        ImGui.NewFrame();

        ImGui.Begin("Window");
        draw_editor();
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

    if rewinding {
        use_shader(texture_shader);
        shader_uniform(texture_shader, "view", *Matrix4_Identity, true);
        bind_texture(ui_sprites);
        radius : float32 = 32;
        draw_radial_texture(.{0, 0, 32, 32}, .{WINDOW_WIDTH - radius*2, radius*2}, radius, rewind_meter / REWIND_TIME, *ui_sprites, intermediate_vao, intermediate_vbo);
    }

    plight_pos := Vector2.{xx level.player_pos.x, xx level.player_pos.y};
    plight_pos += .{0.5, 0.5};
    plight_pos *= 64;
    light := Light.{plight_pos, 3.5 * 64};
    corners := do_lighting(light);

    use_shader(texture_shader);
    bind_texture(spotlight);
    shader_uniform(texture_shader, "projection", *projection, false);
    shader_uniform(texture_shader, "view", *view, true);
    shader_uniform(texture_shader, "model", *model, false);

    light_world_pos := plight_pos;
    light_pic_size := light.radius * 2;
    light_dest := Rect.{light_world_pos.x - light_pic_size/2, light_world_pos.y - light_pic_size/2, light_pic_size, light_pic_size};
    draw_texture(.{0, 0, 256, 256}, light_dest, *spotlight, intermediate_vao, intermediate_vbo);
    
    glDisable(GL_DEPTH_TEST);
    use_shader(color_shader);
    shader_uniform(color_shader, "projection", *projection, false);
    shader_uniform(color_shader, "view", *view, true);
    shader_uniform(color_shader, "model", *model, false);
    shader_uniform(color_shader, "color", Vector4.{1, 0, 0, 1});
    draw_line(.{32, 32}, .{256, 256}, intermediate_vao, intermediate_vbo);

    vertices: [..] Vertex(.UV_DISABLED);
    vertices.allocator = temp;
    array_add(*vertices, .{plight_pos.x, plight_pos.y, 0});

    angle_func :: (a: Light_Mesh_Node, b: Light_Mesh_Node) -> float {
        ppos := Vector2.{xx context.game_state.level.player_pos.x, xx context.game_state.level.player_pos.y};
        ppos += .{0.5, 0.5};
        ppos *= 64;
        first := a - ppos;
        second := b - ppos;
        angle_a := atan2(first.y, first.x);
        angle_b := atan2(second.y, second.x);
        while angle_a < 0 {
            angle_a += TAU;
        } while angle_b < 0 {
            angle_b += TAU;
        }
        angle := angle_a - angle_b;
        return angle;
    }

    if input.just_pressed[SDL_SCANCODE_G] {
        debug_vert_count -= 1;
    }
    if input.just_pressed[SDL_SCANCODE_H] {
        debug_vert_count += 1;
    }

    if corners.count > 0 {
        Sort.quick_sort(corners, angle_func);
        // extended := corners[corners.count-1].extension;
        // for 0..corners.count-1 {
        //     // defer extended = corners[it].extension;
        //     next_ind := ifx it==corners.count-1 0 else it+1;
        //     a := corners[it];
        //     b := corners[next_ind];
        //     first := a - plight_pos;
        //     second := b - plight_pos;
        //     angle_a := atan2(first.y, first.x);
        //     angle_b := atan2(second.y, second.x);

        //     while angle_a < TAU {
        //         angle_a += TAU;
        //     } while angle_b < TAU {
        //         angle_b += TAU;
        //     }
        //     angle := angle_a - angle_b;
        //     while angle < TAU {
        //         angle += TAU;
        //     }

        //     // Same angle
        //     if angle == 0 {
        //         if extended != a.extension {
        //             corners[next_ind], corners[it] = corners[it], corners[next_ind];
        //             it += 1;
        //             continue;
        //         }
        //     }
        // }

        point_count := ifx debug_vert_count < 0 corners.count else debug_vert_count;
        for 0..point_count-1 {
            corner := corners[it];
            shader_uniform(color_shader, "color", Vector4.{1, 0, 0, 1});
            if it == point_count-1 && debug_vert_count >= 0 {
                shader_uniform(color_shader, "color", Vector4.{0, 0, 1, 1});
                print("Node: %\n", corners[point_count-1]);
            }
            // draw_line(plight_pos, corner, intermediate_vao, intermediate_vbo);
            array_add(*vertices, .{corner.x, corner.y, 0});
        }
        if vertices.count > 1 {
            array_add(*vertices, vertices[1]);
        }

        shader_uniform(color_shader, "color", Vector4.{0, 0, 1, 0.25});
        glBindVertexArray(intermediate_vao);
        glBindBuffer(GL_ARRAY_BUFFER, intermediate_vbo);
        glBufferData(GL_ARRAY_BUFFER, size_of(Vertex(.UV_DISABLED)) * (point_count + ifx debug_vert_count == -1 2 else 1), vertices.data, GL_STATIC_DRAW);

        // position
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * size_of(float32), null);
        glEnableVertexAttribArray(0);


        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glDrawArrays(GL_TRIANGLE_FAN, 0, xx (point_count + ifx debug_vert_count == -1 2 else 1));

        // Draw outer box
        // draw_line(light_dest.pos, .{light_dest.x + light_dest.w, light_dest.y}, intermediate_vao, intermediate_vbo);
        // draw_line(light_dest.pos, .{light_dest.x, light_dest.y + light_dest.h}, intermediate_vao, intermediate_vbo);
        // draw_line(light_dest.pos + .{light_dest.w, 0}, .{light_dest.x + light_dest.w, light_dest.y + light_dest.h}, intermediate_vao, intermediate_vbo);
        // draw_line(light_dest.pos + .{0, light_dest.h}, .{light_dest.x + light_dest.w, light_dest.y+light_dest.h}, intermediate_vao, intermediate_vbo);
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
                struct_str := tprint("%", tile);
                draw_text(struct_str, .{32, 64}, *font_m5x7, intermediate_vao, intermediate_vbo);
            }
        }

        #if false {
            shader_uniform(text_shader, "color", .{1, 1, 1, 1});
            shader_uniform(color_shader, "view", *view, true);
            tile_begin, tile_end := get_camera_level_bounds(camera, *level);
            for x: tile_begin.x..tile_end.x {
                for y: tile_begin.y..tile_end.y {
                    light := compute_light_value(field, x, y);
                    struct_str := tprint("%", light);
                    struct_str.count = min(struct_str.count, 3);
                    dest := v2i.{xx (x*64) + 8, xx (y*64) + 48};
                    draw_text(struct_str, dest, *font_m5x7, intermediate_vao, intermediate_vbo);
                }
            }
            shader_uniform(color_shader, "view", *Matrix4_Identity, true);
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
Sort :: #import "Sort";
#import "Remap_Context"(VERBOSE = false);

#load "imgui.jai";
#load "math.jai";
#load "input.jai";
#load "move.jai";
#load "block.jai";
#load "level/level.jai";
#load "audio/audio.jai";
#load "dialogue.jai";
#load "assets/assets.jai";
#load "lighting.jai";