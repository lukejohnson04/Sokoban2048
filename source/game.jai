BUILD_TYPE :: enum #specified {
    RELEASE :: 0;
    DEBUG :: 1;
    PROFILE :: 2;
}

BUILD :: BUILD_TYPE.DEBUG;

#add_context game_state: *Game_State;

#program_export
update_and_render :: (game_memory: *void, input: *Input_State, window: *SDL_Window, just_reloaded_dll: *bool, imgui_context: *ImGui.ImGuiContext) -> s32 {
    game_state := cast(*Game_State) game_memory;
    Remap_Context();
    context.game_state = game_state;
    using context.game_state;
    input_state = input;

    if memory_initialized == false {
        ImGui.SetCurrentContext(imgui_context);
        on_startup();
        memory_initialized = true;
    }

    if just_reloaded_dll.* {
        gl_load(*gl);
        ImGui.SetCurrentContext(imgui_context);
        
        level_mesh_needs_update = true;
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

    if input.just_pressed[SDL_SCANCODE_GRAVE] {
        editor.enabled = !editor.enabled;
    }

    moved_this_turn := false;
    controls(input);

    if do_action(.UNDO) {
        moved_this_turn = true;
        undo_turn();
    }

    if movement_tween {
        time := seconds_since_init();
        if time - time_of_last_move > MOVEMENT_TWEEN_LENGTH {
            movement_tween = false;
        }
    }

    if !moved_this_turn && editor.editing_level == false && just_got_photograph == false && dialogue_state.open == false {
        // This is a shocking amount of code for how simple this task is
        for Bindings.Action_Type.[.LEFT, .RIGHT, .UP, .DOWN] {
            if do_action(it) == false continue;
            move := v2i.{0, 0};
            if it == .LEFT {
                move.x = -1;
            } else if it == .RIGHT {
                move.x = 1;
            } else if it == .UP {
                move.y = -1;
            } else if it == .DOWN {
                move.y = 1;
            }

            if move != .{0, 0} {
                success := move_player(move);
                if success {
                    moved_this_turn = true;
                    if dialogue_state.open == false {
                        movement_tween = true;
                    }
                    time_of_last_move = seconds_since_init();

                    old_ppos := turn_memory.curr.prev.move_delta.old_player_pos;
                    reverse_dir_vec := Vector2.{xx -move.x, xx -move.y};

                    for 0..5 {
                        np := spawn_particle(*particle_system);
                        np.pos = Vector2.{xx (old_ppos.x * 64), xx (old_ppos.y* 64)};
                        np.pos += .{32, 72};
                        np.pos -= reverse_dir_vec * 30;
                        np.life_length = 0.35;
                        np.vel = reverse_dir_vec * 60 + random_unit_vector() * 20;
                        np.size_start = 1.0;
                        np.size_end = 0.0;
                    }
                }
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
                rewind_meter += xx delta;
                if rewind_meter > REWIND_TIME {
                    moved_this_turn = true;
                    rewind_meter = 0;
                    rewinding = false;
                    goto_last_checkpoint();
                }
            }
        }

        if do_action(.REDO) {
            moved_this_turn = true;
            apply_turn();
        }
    }
    
    if dialogue_state.open {
        dialogue_update(*dialogue_state, input);
    }

    if moved_this_turn {
        level_mesh_needs_update = true;
        // vfield_generate_flood_fill(*level, field);
        // generate_level_mesh();
    }

    if just_got_photograph && Mix_Playing(0) == 0 {
        just_got_photograph = false;
    }

    if editor.enabled && editor.editing_level {
        update_editor(input);
        if input.just_pressed[SDL_SCANCODE_LALT] {
            editor.move_camera_with_mouse = !editor.move_camera_with_mouse;
        }
    }


    if level_mesh_needs_update || editor.editing_level == false {
        if editor.editing_level == false {
            // Disabled flood fill for now because we will have to rework the visibilty system anyways to account for walls
            // vfield_generate_flood_fill(*level, field);
        }
        if editor.editing_level == false {
            generate_level_mesh(true);
        } else {
            generate_level_mesh();
        }
        level_mesh_needs_update = false;
    }

    if editor.editing_level == false {
        update_map(input);
    }

    if input.just_pressed[SDL_SCANCODE_G] {
        spawn_particle(*particle_system, Vector2.{xx (level.player_pos.x * 64), xx ((level.player_pos.y + 1)* 64) });
    }

    // Render begin
    ImGui_ImplSdl_NewFrame(window);
    ImGui.NewFrame();
    if editor.enabled {
        window_flags : ImGui.WindowFlags = 0;

        ImGui.Begin("Window", null, window_flags);
        draw_editor();
        ImGui.End();
    }

    // Rendering
    glEnable(GL_DEPTH_TEST);
    set_framebuffer(null);
    clear_framebuffer(1, 1, 1, 1);
    set_framebuffer(*floor_buffer);
    clear_framebuffer(0, 0, 0, 0);
    set_framebuffer(*world_buffer);
    clear_framebuffer(0, 0, 0, 0);

    lerp_player_camera(window);

    view := camera_view_matrix(camera);
    projection := orthographic_projection_matrix(0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, -1, 1);

    uniform(color_shader, "projection", projection);
    uniform(color_shader, "view", view);

    uniform(text_shader, "projection", projection);
    uniform(text_shader, "view", Matrix4_Identity);

    uniform(mask_shader, "projection", projection);
    uniform(mask_shader, "view", Matrix4_Identity);
    uniform(mask_shader, "dim_level", 0);
    uniform(mask_shader, "blend_alpha", 0);
    uniform(mask_shader, "blend_rgb", 0);

    uniform(texture_shader, "projection", projection);
    uniform(texture_shader, "view", view);
    uniform(texture_shader, "grayscale", 0);
    uniform(texture_shader, "gold", 0);
    uniform(texture_shader, "colormult", 1.0);
    uniform(texture_shader, "color_pass", Vector4.{1, 1, 1, 1});

    resource_tracker_reload_resources(*resource_tracker, delta);


    bind_texture(sprites);

    draw_extra_mesh_layers :: (mesh: *Level_Mesh) #expand {
        uniform(texture_shader, "colormult", 0.8);
        uniform(texture_shader, "grayscale", 1);
        mesh_draw(*mesh.goal);
        uniform(texture_shader, "grayscale", 0);
        uniform(texture_shader, "gold", 1);
        mesh_draw(*mesh.gold);
        uniform(texture_shader, "gold", 0);
        uniform(texture_shader, "color_pass", Vector4.{1, 0.2, 0.2, 1});
        mesh_draw(*mesh.timer);
        uniform(texture_shader, "color_pass", Vector4.{1, 1, 1, 1});
        uniform(texture_shader, "gold", 0);
        uniform(texture_shader, "colormult", 1.0);
    }
    
    mesh_to_draw := ifx movement_tween then *tween_mesh else *world_mesh;
    if editor.enabled == false || editor.show_both_layers {
        set_framebuffer(*floor_buffer);
        mesh_draw(*mesh_to_draw.floor);
        set_framebuffer(*world_buffer);
        mesh_draw(*mesh_to_draw.tiles);
        draw_extra_mesh_layers(mesh_to_draw);
    } else {
        if editor.layer == 0 {
            mesh_draw(*mesh_to_draw.tiles);
            draw_extra_mesh_layers(mesh_to_draw);
        } else {
            set_framebuffer(*floor_buffer);
            mesh_draw(*mesh_to_draw.floor);
            set_framebuffer(*world_buffer);
        }
    }

    // particles
    uniform(texture_shader, "view", view);
    particles_update_and_render(*particle_system);

    use_shader(texture_shader);

    if editor.editing_level == false {
        time := seconds_since_init();
        time_since_last_move := time - time_of_last_move;
        {
            // Draw player
            source := Rect.{192,96,16,16};
            dest: Rect;

            tween_value := min(time_since_last_move / MOVEMENT_TWEEN_LENGTH, 1.0);

            player_animation_timer += delta;
            if movement_tween {
                old_pos := turn_memory.curr.prev.move_delta.old_player_pos * 64;
                new_pos := turn_memory.curr.prev.move_delta.new_player_pos * 64;
                dest.x = xx lerp(cast(float) old_pos.x, cast(float) new_pos.x, tween_value);
                dest.y = xx lerp(cast(float) old_pos.y, cast(float) new_pos.y, tween_value);
                dest.w = 64;
                dest.h = 64;
                player_animation_timer = MOVEMENT_TWEEN_LENGTH;
            } else {
                dest = Rect.{xx (level.player_pos.x*64), xx (level.player_pos.y*64), 64, 64};
            }
            if player_animation_timer < 0.12 {
                source.x += 16 * ((turn_count % 2) + 1);
            }
            if player_flip {
                source.x += 16;
                source.w *= -1;
            }
            dest.y += CHARACTER_DRAW_OFFSET;
            bind_texture(sprites);
            draw_texture(source, dest, *sprites);

            // Draw tweened blocks
            if movement_tween {
                if turn_memory.curr.prev {
                    if turn_memory.curr.prev.type == .MOVE {
                        delta_data := turn_memory.curr.prev.move_delta;
                        if delta_data.tween_count > 0 {
                            for 0..delta_data.tween_count-1 {
                                tween_change := delta_data.tween_changes[it];
                                old_pos := tween_change.from * 64;
                                new_pos := tween_change.to * 64;
                                source = get_block_source(tween_change.value);

                                dest = Rect.{0, 0, 64, 64};
                                dest.x = xx lerp(cast(float) old_pos.x, cast(float) new_pos.x, tween_value);
                                dest.y = xx lerp(cast(float) old_pos.y, cast(float) new_pos.y, tween_value);
                                if get_block_type(tween_change.value) == .NUMBERED {
                                    source.h = 26;
                                    dest.h += 10 * 4;
                                }
                                // if get_block_type(tween_change.value) == .NUMBERED {
                                //     source.h += 9;
                                //     dest.h += 9 * 4;
                                // }
                                draw_texture(source, dest, *sprites);
                            }
                        }
                    }
                }
            }
        }
        // Draw medusa firings
        MEDUSA_FIRE_ANIM_TIME :: 0.15;
        if medusa_firings.count > 0 && time_since_last_move < MEDUSA_FIRE_ANIM_TIME {
            for 0..medusa_firings.count-1 {
                firing := medusa_firings.data[it];
                source := Rect.{96, 144, 16, 16};
                dest := Rect.{xx (firing.origin.x * 64), xx (firing.origin.y * 64), 64, 64};
                draw_texture(source, dest, *sprites);

                if firing.length > 0 {
                    // Draw laser
                    source = .{112, 144, 16, 16};
                    for 0..firing.length {
                        dest.x += 64;
                        draw_texture(source, dest, *sprites);
                    }
                }
            }
        }
    }

    editor_draw();
    
    use_shader(color_shader);
    uniform(color_shader, "color", Vector4.{1, 0, 0, 1});
    uniform(color_shader, "view", view);

    level_screen_width := level.dimensions.x / SCREEN_TILE_WIDTH;
    level_screen_height := level.dimensions.y / SCREEN_TILE_HEIGHT;

    bound_begin, bound_end := get_camera_level_bounds(camera, *level);
    for x: 0..level_screen_width-1 {
        dimension_x : float32 = (SCREEN_TILE_WIDTH * 64);
        for y: 0..level_screen_height-1 {
            dimension_y : float32 = (SCREEN_TILE_HEIGHT * 64);
            if SCREEN_TILE_WIDTH * (x+1) < xx bound_begin.x {
                continue;
            }
            if SCREEN_TILE_HEIGHT * (y+1) < xx bound_begin.y {
                continue;
            }
            if SCREEN_TILE_WIDTH * x > xx bound_end.x {
                continue;
            }
            if SCREEN_TILE_HEIGHT * y > xx bound_end.y{
                continue;
            }
            draw_rect_with_outline(CoordRect(Rect.{dimension_x * x, dimension_y * y, xx dimension_x, xx dimension_y}), 4);
        }
    }

    if lighting_enabled == false || editor.editing_level {
        set_framebuffer(null);
        glDisable(GL_DEPTH_TEST);
        
        uniform(texture_shader, "view", Matrix4_Identity);
        bind_texture(floor_buffer.tex);
        draw_texture(Rect.{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}, .{0, WINDOW_HEIGHT, WINDOW_WIDTH, -WINDOW_HEIGHT}, floor_buffer.tex);
        bind_texture(world_buffer.tex);
        draw_texture(Rect.{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}, .{0, WINDOW_HEIGHT, WINDOW_WIDTH, -WINDOW_HEIGHT}, world_buffer.tex);

    } else {
        draw_lighting();
    }

    // GUI Elements
    // Draw dialogue player
    if dialogue_state.open {
        uniform(texture_shader, "view", Matrix4_Identity);
        bind_texture(dialogue_player_texture);
        draw_texture(.{0, 0, 320, 180}, .{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}, *dialogue_player_texture, intermediate_vao, intermediate_vbo);

        
        str: string;
        str.data = dialogue_state.buffer.memory.data;
        str.count = dialogue_state.index;

        text_dest := Vector2.{64, 120};
        PORTRAIT_SIZE :: 200.0;
        PROTRAIT_MARGIN :: 40.0;
        text_wrap := WINDOW_WIDTH - 200.0;
        if dialogue_state.buffer.speaker != 0 {
            portrait_dest := Vector2.{64, 100};
            text_wrap -= PORTRAIT_SIZE + PROTRAIT_MARGIN;
            if dialogue_state.buffer.draw_portrait_right {
                portrait_dest.x += text_wrap + PROTRAIT_MARGIN;
            } else {
                text_dest.x += PORTRAIT_SIZE + PROTRAIT_MARGIN;
            }
            // Draw portrait
            portrait_source := get_block_source(dialogue_state.buffer.speaker);
            portrait_source.h = 11;
            draw_texture(portrait_source, .{portrait_dest.x, portrait_dest.y, PORTRAIT_SIZE, (portrait_source.h / 16.0) * PORTRAIT_SIZE}, *sprites, flip_x = dialogue_state.buffer.draw_portrait_right);
        }

        uniform(text_shader, "view", Matrix4_Identity);
        uniform(text_shader, "color", .{1, 1, 1, 1});
        draw_text(str, text_dest, *font_m5x7, intermediate_vao, intermediate_vbo, xx text_wrap);
    }

    // Map
    if editor.editing_level == false {
        using map;
        if display_map && display_minimap == false {
            map_dest := Rect.{100, 100, 512, 512};

            set_framebuffer(*map_display_buffer);
            clear_framebuffer(0, 0, 1, 1);
            disp_proj := orthographic_projection_matrix(0, map_dest.w, map_dest.h, 0, -1, 1);
            map_view := camera_view_matrix(map_camera, xx map_dest.w, xx map_dest.h);
            
            uniform(texture_shader, "view", map_view);
            uniform(texture_shader, "projection", disp_proj);
            bind_texture(map_buffer.tex);
            draw_texture(.{0, 0, xx map_buffer.w, xx map_buffer.h}, .{0, xx map_buffer.h, xx map_buffer.w, xx -map_buffer.h}, map_buffer.tex);

            set_framebuffer(null);
            uniform(texture_shader, "view", Matrix4_Identity);
            uniform(texture_shader, "projection", projection);
            bind_texture(map_display_buffer.tex);
            fin_dest := Rect.{100, 100 + map_dest.h, xx map_dest.w, xx -map_dest.h};
            draw_texture(.{0, 0, xx map_dest.w, xx map_dest.h}, fin_dest, map_display_buffer.tex);

        } else if display_map && display_minimap {
            px, py := get_player_room();
            map_dest := Rect.{xx (WINDOW_WIDTH - 50 - 256), 50, 256, 256};

            set_framebuffer(*map_display_buffer);
            clear_framebuffer(0, 0, 1, 1);
            disp_proj := orthographic_projection_matrix(0, map_dest.w, map_dest.h, 0, -1, 1);
            map_view := camera_view_matrix(minimap_camera, xx map_dest.w, xx map_dest.h);

            uniform(texture_shader, "view", map_view);
            uniform(texture_shader, "projection", disp_proj);
            bind_texture(map_buffer.tex);
            draw_texture(.{0, 0, xx map_buffer.w, xx map_buffer.h}, .{0, xx map_buffer.h, xx map_buffer.w, xx -map_buffer.h}, map_buffer.tex);

            set_framebuffer(null);
            uniform(texture_shader, "view", Matrix4_Identity);
            uniform(texture_shader, "projection", projection);
            bind_texture(map_display_buffer.tex);
            fin_dest := Rect.{map_dest.x, map_dest.y + map_dest.h, xx map_dest.w, xx -map_dest.h};
            draw_texture(.{0, 0, xx map_display_buffer.w, xx map_display_buffer.h}, fin_dest, map_display_buffer.tex);
        }
    }

    // Debug text
    #if true {

        if editor.editing_level {
            uniform(text_shader, "view", Matrix4_Identity);
            uniform(text_shader, "color", .{1, 0, 0, 1});
            if is_in_bounds(editor.mouse_tile, *level) {
                tile := level.grid[editor.mouse_tile.x][editor.mouse_tile.y];
                if tile == BLOCK_NONE || (editor.show_both_layers == false && editor.layer == 1) {
                    tile = level.floor[editor.mouse_tile.x][editor.mouse_tile.y];
                }
                struct_str := tprint("%, %", tile, get_block_type(tile));
                draw_text(struct_str, .{32, 64}, *font_m5x7, intermediate_vao, intermediate_vbo);
            }
        }
    }

    ImGui.Render();
    ImGui_ImplSdl_RenderDrawLists(ImGui.GetDrawData());
    SDL_GL_SwapWindow(window);

    curr_frame_time := seconds_since_init();
    delta = xx (curr_frame_time - prev_frame_time);
    prev_frame_time = curr_frame_time;
    global_timer += xx delta;


    reset_temporary_storage();
    return 1;
}


WINDOW_WIDTH :: 1280;
WINDOW_HEIGHT :: 960;
WINDOW_SIZE :: v2i.{WINDOW_WIDTH, WINDOW_HEIGHT};

GAME_WIDTH :: 320;
GAME_HEIGHT :: 240;
GAME_SIZE :: v2i.{GAME_WIDTH, GAME_HEIGHT};

SCREEN_TILE_WIDTH :: GAME_WIDTH / 16;
SCREEN_TILE_HEIGHT :: GAME_HEIGHT / 16;
SCREEN_TILE_SIZE :: v2i.{SCREEN_TILE_WIDTH, SCREEN_TILE_HEIGHT};
VSYNC :: true;
FPS_MAX : float64 : 60.0;

#load "render/render.jai";
#load "render/text.jai";
#load "render/shader.jai";
#load "camera.jai";
#load "intrinsics.jai";
#load "game_state.jai";
#load "controls.jai";
#load "particles.jai";

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
#load "light.jai";
#load "map.jai";