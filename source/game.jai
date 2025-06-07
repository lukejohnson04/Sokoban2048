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

    if input.just_pressed[SDL_SCANCODE_GRAVE] {
        editor.enabled = !editor.enabled;
    }

    moved_this_turn := false;
    controls(input);

    if do_action(.UNDO) {
        moved_this_turn = true;
        undo_turn();
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
                success, combines_block, activates_goal_block := move_player(move);
                if success {
                    moved_this_turn = true;
                    // play_sound_effect(footsteps[move_number % footsteps.count]);
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
        vfield_generate_flood_fill(*level, field);
        generate_level_mesh();
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
    glDisable(GL_DEPTH_TEST);
    set_framebuffer(null);
    clear_framebuffer(0, 0, 0, 1);
    set_framebuffer(*floor_buffer);
    clear_framebuffer(0, 0, 0, 0);
    set_framebuffer(*world_buffer);
    clear_framebuffer(0, 0, 0, 0);

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
    shader_uniform(mask_shader, "dim_level", 0);
    shader_uniform(mask_shader, "blend_alpha", 0);
    shader_uniform(mask_shader, "blend_rgb", 0);

    use_shader(texture_shader);
    shader_uniform(texture_shader, "projection", projection);
    shader_uniform(texture_shader, "view", view);
    shader_uniform(texture_shader, "grayscale", 0);
    shader_uniform(texture_shader, "gold", 0);
    shader_uniform(texture_shader, "colormult", 1.0);
    shader_uniform(texture_shader, "color_pass", Vector4.{1, 1, 1, 1});


    resource_check_timer += FRAME_TIME;
    if resource_check_timer > 0.25 {
        check_resource_reload(*sprites);
        resource_check_timer = 0;
    }

    bind_texture(sprites);

    draw_extra_mesh_layers :: () #expand {
        shader_uniform(texture_shader, "colormult", 0.8);
        shader_uniform(texture_shader, "grayscale", 1);
        mesh_draw(*world_mesh.goal);
        shader_uniform(texture_shader, "grayscale", 0);
        shader_uniform(texture_shader, "gold", 1);
        mesh_draw(*world_mesh.gold);
        shader_uniform(texture_shader, "gold", 0);
        shader_uniform(texture_shader, "colormult", 1.0);
    }
    
    if editor.enabled == false || editor.show_both_layers {
        set_framebuffer(*floor_buffer);
        mesh_draw(*world_mesh.floor);
        set_framebuffer(*world_buffer);
        mesh_draw(*world_mesh.tiles);
        draw_extra_mesh_layers();
    } else {
        if editor.layer == 0 {
            mesh_draw(*world_mesh.tiles);
            draw_extra_mesh_layers();
        } else {
            set_framebuffer(*floor_buffer);
            mesh_draw(*world_mesh.floor);
            set_framebuffer(*world_buffer);
        }
    }

    if editor.editing_level == false {
        source := Rect.{16,0,16,16};
        dest := Rect.{xx (level.player_pos.x*64), xx (level.player_pos.y*64), 64, 64};
        bind_texture(sprites);
        draw_texture(source, dest, *sprites);
    }

    editor_draw();
    
    use_shader(color_shader);
    shader_uniform(color_shader, "color", Vector4.{1, 0, 0, 1});
    shader_uniform(color_shader, "view", view);
    draw_rect_with_outline(Rect.{0, 0, xx (level.dimensions.x * 64), xx (level.dimensions.y * 64)}, 4);

    if lighting_enabled == false || editor.editing_level {
        set_framebuffer(null);
        
        use_shader(texture_shader);
        shader_uniform(texture_shader, "view", Matrix4_Identity);
        bind_texture(floor_buffer.tex);
        draw_texture(Rect.{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}, .{0, WINDOW_HEIGHT, WINDOW_WIDTH, -WINDOW_HEIGHT}, floor_buffer.tex);
        bind_texture(world_buffer.tex);
        draw_texture(Rect.{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT}, .{0, WINDOW_HEIGHT, WINDOW_WIDTH, -WINDOW_HEIGHT}, world_buffer.tex);

    } else {
        /*
        
            Our goal is to take the full screen resolution output render of the entire world.
            Then, we want to draw a low brightness version of that render. When drawing this
            version, we want to use a mask layer as well. For all values that are white in the
            mask, we want to draw the world layer at full brightness. Otherwise, we want to use
            a dim brightness.

            To do this, we draw the entire world. We also pass the mask and the uv of the mask
            to the shader. For all the pixels within the mask portion, we multiply it with the uv.
            Otherwise, the default value is the dim light, which is a uniform.

            So in short, we have a uniform for the texture, a uniform for the mask, a uv for the
            texture, a uv for the mask, and finally a uniform for the dim light.

            To generate the light mask texture, we first start with the full texture of the shadow
            layer. Then, we go onto a new framebuffer texture, and render the spotlight with the
            shadow layer as a mask.
        */
        // Lighting
        glDisable(GL_DEPTH_TEST);
        set_framebuffer(*world_mesh.light_buffer);
        clear_framebuffer(1, 1, 1, 0);

        for index: 0..light_count-1 {
            light := *lights[index];

            set_framebuffer(*light.shadow_buffer);
            clear_framebuffer(0, 0, 0, 0);

            fb_projection := orthographic_projection_matrix(0, xx light.shadow_buffer.w, xx light.shadow_buffer.h, 0, -1, 1);

            use_shader(color_shader);
            shader_uniform(color_shader, "projection", *fb_projection);
            light_color := Vector4.{1, 1, 1, 1};
            shader_uniform(color_shader, "color", light_color);
            shader_uniform(color_shader, "view", Matrix4_Identity);

            glBindVertexArray(intermediate_vao);
            glBindBuffer(GL_ARRAY_BUFFER, intermediate_vbo);
            glBufferData(GL_ARRAY_BUFFER, size_of(Vertex(.UV_DISABLED)) * light.mesh.count, light.mesh.data, GL_STATIC_DRAW);
            // position
            glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * size_of(float32), null);
            glEnableVertexAttribArray(0);

            glBindBuffer(GL_ARRAY_BUFFER, 0);
            glDrawArrays(GL_TRIANGLE_FAN, 0, xx light.mesh.count);

            use_shader(mask_shader);
            shader_uniform(mask_shader, "projection", fb_projection);
            shader_uniform(mask_shader, "view", Matrix4_Identity);
            shader_uniform(mask_shader, "dim_level", 0);
            shader_uniform(mask_shader, "blend_alpha", 1);
            shader_uniform(mask_shader, "blend_rgb", 1);

            set_framebuffer(*light.light_buffer);
            clear_framebuffer(0, 0, 0, 0);
            sh_rect := Rect.{0, 0, xx light.light_buffer.tex.width, xx light.light_buffer.tex.height};
            sh_dest := Rect.{0, 0, xx light.light_buffer.tex.width, xx light.light_buffer.tex.height};
            draw_mask_textures(sh_rect, sh_dest, sh_rect, sh_dest, *light.shadow_buffer.tex, *spotlight);


            use_shader(texture_shader);
            shader_uniform(texture_shader, "view", view);
            shader_uniform(texture_shader, "color_pass", light.color);
            set_framebuffer(*world_mesh.light_buffer);
            light_src := buffer_rect(light.light_buffer);
            light_rect := get_light_rect(light);
            draw_texture(light_src, light_rect, light.light_buffer.tex);
            shader_uniform(texture_shader, "color_pass", Vector4.{1,1,1,1});
        }

        set_framebuffer(null);
        clear_framebuffer(0,0,0,1);
        final_buffer_src := buffer_rect(world_mesh.light_buffer);
        final_buffer_dest := final_buffer_src;
        screen_source := buffer_rect(floor_buffer);
        screen_dest := final_buffer_dest;
        flip_rect(*screen_dest);
        flip_rect(*final_buffer_dest);
        use_shader(mask_shader);
        dim_level := 0.5;
        shader_uniform(mask_shader, "projection", projection);
        shader_uniform(mask_shader, "dim_level", dim_level);
        shader_uniform(mask_shader, "blend_alpha", 0);
        shader_uniform(mask_shader, "view", Matrix4_Identity);
        shader_uniform(mask_shader, "blend_rgb", 0);

        draw_mask_textures(screen_source, screen_dest, final_buffer_src, final_buffer_dest, *floor_buffer.tex, *world_mesh.light_buffer.tex);

        use_shader(texture_shader);
        shader_uniform(texture_shader, "view", Matrix4_Identity);
        shader_uniform(texture_shader, "colormult", 1.0);
        bind_texture(world_buffer.tex);
        draw_texture(screen_source, screen_dest, world_buffer.tex);
        shader_uniform(texture_shader, "colormult", 1.0);
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
        str.data = dialogue_state.buffer.memory.data;
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
                if get_block_type(tile) == .NONE {
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
#load "controls.jai";

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