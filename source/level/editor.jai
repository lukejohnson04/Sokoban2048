Editor_State :: struct {
    selected_block := 0;
    selected_block_pos : Vector2;

    editing_level := false;

    mouse_tile : v2i;

    load_level_field : [MAX_LEVEL_NAME_LENGTH]u8;
    save_level_field : [MAX_LEVEL_NAME_LENGTH]u8;
}

draw_editor :: (using game_state: *Game_State) {
    draw_list := ImGui.GetWindowDrawList();
    window_pos := ImGui.GetCursorScreenPos();

    tile_scale :: 2;
    tile_size :: 16 * tile_scale;

    source := ImGui.ImVec2.{xx sprites_imgui.width, xx sprites_imgui.height};
    dest := ImGui.ImVec2.{xx (sprites_imgui.width * tile_scale), xx (sprites_imgui.height * tile_scale)};

    if level.id != 0 {
        ImGui.LabelText("##level_title", tprint("Level: %", cast(string) level.name));
    } else {
        ImGui.LabelText("##level_title", "No level loaded");
    }
    ImGui.InputText("##load", editor.load_level_field.data, MAX_LEVEL_NAME_LENGTH);
    ImGui.SameLine();
    if ImGui.Button("Load Level") {
        loaded := load_level(*level, xx editor.load_level_field);
        if loaded {
            for 0..editor.load_level_field.count-1 {
                editor.load_level_field[it] = 0;
            }
            editor.editing_level = true;
        }
    }
    
    if editor.editing_level == false {
        if ImGui.Button("Edit Level") {
            editor.editing_level = true;
            loaded := load_level(*level, xx level.name);
        }
        ImGui.SameLine();
        if level.id != 0 {
            if ImGui.Button("Restart Level") {
                loaded := load_level(*level, xx level.name);
            }
        }
    } else {
        ImGui.InputText("##save", editor.save_level_field.data, MAX_LEVEL_NAME_LENGTH);
        ImGui.SameLine();
        if ImGui.Button("Save Level") {
            save_level(*level, xx editor.save_level_field);
            for 0..editor.save_level_field.count-1 {
                editor.save_level_field[it] = 0;
            }
        }
        if ImGui.Button("Play Level") {
            if level.id == 0 {
                print("Save level first!\n");
            } else {
                save_level(*level, xx level.name);
                load_level(*level, xx level.name);
                editor.editing_level = false;
            }
        }

        img_pos := window_pos + .{0, 128};

        draw_list.AddImage(draw_list, cast,no_check(*void)(sprites.id), img_pos, img_pos + dest);

        // Selected tile
        focused := ImGui.IsWindowFocused();
        mouse_x, mouse_y := get_mouse_position_explicit();

        highlighted := false;
        highlighted_block : int;
        highlighted_xy : Vector2;

        if mouse_x >= xx img_pos.x && mouse_x < xx img_pos.x + sprites_imgui.width * tile_scale {
            if mouse_y >= xx img_pos.y && mouse_y < xx img_pos.y + sprites_imgui.height * tile_scale {
                highlighted_xy.x = floor((mouse_x - img_pos.x) / tile_size);
                highlighted_xy.y = floor((mouse_y - img_pos.y) / tile_size);

                highlighted_block = xx (highlighted_xy.x + highlighted_xy.y * 8);
                highlighted = true;

                if focused {
                    if ImGui.IsMouseDown(ImGui.MouseButton.Left) {
                        real := highlighted_block;
                        if highlighted_block == 2 {
                            real = BLOCK_BOULDER;
                        } else if highlighted_block == 3 {
                            real = BLOCK_WALL;
                        } else if highlighted_block == 4 {
                            real = BLOCK_PLAYER_SPAWN;
                        } else if highlighted_block >= 8 {
                            real = highlighted_block - 7;
                        }
                        editor.selected_block = real;
                        editor.selected_block_pos = highlighted_xy;
                    }
                }
            }
        }

        if highlighted && editor.selected_block_pos != highlighted_xy {
            p1 := ImGui.ImVec2.{highlighted_xy.x * tile_size, highlighted_xy.y * tile_size};
            p2 := p1 + .{tile_size, 0};
            p3 := p1 + .{tile_size, tile_size};
            p4 := p1 + .{0, tile_size};
            colf := Vector4.{1, 1, 0, 1};
            
            draw_list.AddQuad(draw_list, img_pos + p1, img_pos + p2, img_pos + p3, img_pos + p4, ImGui.GetColorU32(colf), 2);
        }

        if editor.selected_block {
            p1 := ImGui.ImVec2.{editor.selected_block_pos.x * tile_size, editor.selected_block_pos.y * tile_size};
            p2 := p1 + .{tile_size, 0};
            p3 := p1 + .{tile_size, tile_size};
            p4 := p1 + .{0, tile_size};
            colf := Vector4.{0, 1, 0, 1};
            
            draw_list.AddQuad(draw_list, img_pos + p1, img_pos + p2, img_pos + p3, img_pos + p4, ImGui.GetColorU32(colf), 2);
        }
    }
}


update_editor :: (using game_state: *Game_State, input: *Input_State) {
    mouse_world_pos := get_mouse_world_pos(camera);
    editor.mouse_tile = v2i.{xx (mouse_world_pos.x / 64), xx (mouse_world_pos.y / 64)};
    mouse_tile := editor.mouse_tile;

    if input.mouse_just_pressed || input.rmouse_just_pressed {
        if mouse_tile.x >= 0 && mouse_tile.y >= 0 && mouse_tile.x < level.dimensions.x && mouse_tile.y < level.dimensions.y {
            // Spawn blocks have special functionality and don't show up in game
            if editor.selected_block == BLOCK_PLAYER_SPAWN {
                level.player_spawn_pos = .{mouse_tile.x, mouse_tile.y};
            } else {
                level.grid[mouse_tile.x][mouse_tile.y] = editor.selected_block;
                if input.rmouse_just_pressed {
                    level.grid[mouse_tile.x][mouse_tile.y] *= -1;
                }
            }
        }
    }
}