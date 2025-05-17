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

    // Rendering
    glClearColor(0, 0, 0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, world_framebuffer.id);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    lerp_player_camera(window);    

    view := camera_view_matrix(camera);
    projection := orthographic_projection_matrix(0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, -1, 1);

    use_shader(color_shader);
    shader_uniform(color_shader, "projection", projection);
    shader_uniform(color_shader, "view", view);

    use_shader(text_shader);
    shader_uniform(text_shader, "projection", projection);
    shader_uniform(text_shader, "view", Matrix4_Identity);

    use_shader(mask_shader);
    shader_uniform(mask_shader, "projection", projection);
    shader_uniform(mask_shader, "view", Matrix4_Identity);

    use_shader(texture_shader);
    shader_uniform(texture_shader, "projection", projection);
    shader_uniform(texture_shader, "view", view);
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

    editor_draw();

    if lighting_enabled == false {
        use_shader(texture_shader);
        bind_texture(world_texture);
        shader_uniform(texture_shader, "view", Matrix4_Identity);
        draw_texture(Rect.{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}, .{0, WINDOW_HEIGHT, WINDOW_WIDTH, -WINDOW_HEIGHT}, world_texture);
    } else {
        // Lighting
        glDisable(GL_DEPTH_TEST);
        use_shader(color_shader);
        shader_uniform(color_shader, "color", Vector4.{1, 0, 0, 1});

        vertices: [..] Vertex(.UV_DISABLED);
        vertices.allocator = temp;
        array_add(*vertices, .{player_light.pos.x, player_light.pos.y, 0});
        if world_mesh.light_mesh.count > 0 {
            // Sort.quick_sort(world_mesh.light_mesh, angle_sort_clockwise);
            for 0..world_mesh.light_mesh.count-1 {
                corner := world_mesh.light_mesh[it];
                //shader_uniform(color_shader, "color", Vector4.{1, 0, 0, 1});
                //draw_line(player_light.pos, corner, intermediate_vao, intermediate_vbo);
                // Calculate the position of the corner within the texture
                array_add(*vertices, .{corner.x, corner.y, 0});
            }
            
            array_add(*vertices, vertices[1]);
            for *corner: vertices {
                corner.x -= player_light.pos.x;
                corner.y -= player_light.pos.y;
                corner.x += player_light.radius;
                corner.y += player_light.radius;
            }

            glBindFramebuffer(GL_FRAMEBUFFER, shadow_framebuffer.id);
            glClearColor(0, 0, 0, 0);
            glClear(GL_COLOR_BUFFER_BIT);
            glViewport(0, 0, xx shadow_framebuffer.w, xx shadow_framebuffer.h);

            fb_projection := orthographic_projection_matrix(0, xx shadow_framebuffer.w, xx shadow_framebuffer.h, 0, -1, 1);

            use_shader(color_shader);
            shader_uniform(color_shader, "projection", *fb_projection);
            shader_uniform(color_shader, "color", Vector4.{1, 1, 1, 1});
            shader_uniform(color_shader, "view", Matrix4_Identity);

            glBindVertexArray(intermediate_vao);
            glBindBuffer(GL_ARRAY_BUFFER, intermediate_vbo);
            point_count := world_mesh.light_mesh.count + 2;
            glBufferData(GL_ARRAY_BUFFER, size_of(Vertex(.UV_DISABLED)) * point_count, vertices.data, GL_STATIC_DRAW);
            // position
            glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * size_of(float32), null);
            glEnableVertexAttribArray(0);

            glBindBuffer(GL_ARRAY_BUFFER, 0);
            glDrawArrays(GL_TRIANGLE_FAN, 0, xx point_count);

            set_framebuffer(*light_framebuffer);
            clear_framebuffer(0, 0, 0, 0);
            use_shader(mask_shader);
            shader_uniform(mask_shader, "projection", fb_projection);
            shader_uniform(mask_shader, "view", Matrix4_Identity);
            sh_rect := Rect.{0, 0, xx light_texture.width, xx light_texture.height};
            sh_dest := Rect.{0, 0, xx light_texture.width, xx light_texture.height};
            sh_dest.y += sh_dest.h;
            sh_dest.h *= -1;

            draw_mask_textures(sh_rect, sh_dest, sh_rect, sh_dest, *shadow_texture, *spotlight);

            set_framebuffer(null);
            use_shader(texture_shader);
            shader_uniform(texture_shader, "view", Matrix4_Identity);
            bind_texture(light_texture);
            sh_rect = Rect.{0, 0, xx light_texture.width, xx light_texture.height};
            sh_dest = Rect.{0, 0, xx light_texture.width, xx light_texture.height};
            sh_dest.y += sh_dest.h;
            sh_dest.h *= -1;
            draw_texture(sh_rect, sh_dest, *light_texture);

            // use_shader(mask_shader);
            // shader_uniform(mask_shader, "projection", projection);
            // // rect := Rect.{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT};
            // // dest := rect;
            // // dest.y += dest.h;
            // // dest.h *= -1;
            // // draw_mask_textures(rect, )
            // mask_dest := Rect.{player_light.pos.x - player_light.radius, player_light.pos.y - player_light.radius, player_light.radius * 2, player_light.radius * 2};
            // mask_source := Rect.{0, 0, xx shadow_texture.width, xx shadow_texture.height};

            // draw_mask_textures(Rect.{0,0,WINDOW_WIDTH,WINDOW_HEIGHT}, dest, mask_source, mask_dest, *world_texture, *shadow_texture);
        }
    }

    // GUI Elements
    // Draw dialogue player
    if dialogue_state.open {
        use_shader(texture_shader);
        shader_uniform(texture_shader, "view", Matrix4_Identity);
        bind_texture(dialogue_player_texture);
        draw_texture(.{0, 0, 320, 180}, .{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}, *dialogue_player_texture, intermediate_vao, intermediate_vbo);

        use_shader(text_shader);
        shader_uniform(text_shader, "view", Matrix4_Identity);
        shader_uniform(text_shader, "color", .{1, 1, 1, 1});
        
        str: string;
        str.data = queue_peek(*dialogue_state.nodes).text_buffer.data;
        str.count = dialogue_state.index;
        draw_text(str, .{64, 100}, *font_m5x7, intermediate_vao, intermediate_vbo, WINDOW_WIDTH - 200);
    }

    if rewinding {
        use_shader(texture_shader);
        shader_uniform(texture_shader, "view", Matrix4_Identity);
        bind_texture(ui_sprites);
        radius : float32 = 32;
        draw_radial_texture(.{0, 0, 32, 32}, .{WINDOW_WIDTH - radius*2, radius*2}, radius, rewind_meter / REWIND_TIME, *ui_sprites, intermediate_vao, intermediate_vbo);
    }


    #if true {
        use_shader(text_shader);
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