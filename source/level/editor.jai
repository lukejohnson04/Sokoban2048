
Editor_State :: struct {
    selected_block : Block;
    selected_block_pos : Vector2;

    enabled : bool;
    #if BUILD == .DEBUG {
        enabled = true;
    } else {
        enabled = false;
    }

    editing_level := false;

    tool : Editor_Tool = .PAINT;
    mouse_tile : v2i;

    select_state := Editor_Select_State.NOT_STARTED;
    select_start : v2i;
    select_end : v2i;

    move_state := Editor_Move_State.NOT_STARTED;
    move_start : v2i;
    move_end : v2i;

    load_level_field : [MAX_LEVEL_NAME_LENGTH]u8;
    save_level_field : [MAX_LEVEL_NAME_LENGTH]u8;
    dimension_field : [MAX_LEVEL_NAME_LENGTH]u8;

    Editor_Tool :: enum {
        PAINT;
        SELECT;
        PASTE;
        MOVE;
    }

    Editor_Select_State :: enum {
        NOT_STARTED;
        STARTED;
        FINISHED;
        DRAGGING;
    }

    Editor_Move_State :: enum {
        NOT_STARTED;
        STARTED;
    }
}

draw_editor :: (using game_state: *Game_State) {
    draw_list := ImGui.GetWindowDrawList();
    window_pos := ImGui.GetCursorScreenPos();

    TILE_SCALE :: 2;
    TILE_SIZE :: 16 * TILE_SCALE;

    source := ImGui.ImVec2.{xx sprites_imgui.width, xx sprites_imgui.height};
    dest := ImGui.ImVec2.{xx (sprites_imgui.width * TILE_SCALE), xx (sprites_imgui.height * TILE_SCALE)};

    on_new_level_pressed :: (using game_state: *Game_State) {
        if editor.editing_level {
            if level.id != 0 {
                save_level(*level, xx level.name);
            }
        }
        load_empty_level(*level);
        editor.editing_level = true;
    }

    if level.id != 0 {
        ImGui.LabelText("##level_title", tprint("Level: %", cast(string) level.name));
    } else {
        ImGui.LabelText("##level_title", "No level loaded");
    }
    ImGui.InputText("##load", editor.load_level_field.data, MAX_LEVEL_NAME_LENGTH);
    ImGui.SameLine();
    if ImGui.Button("Load Level") {
        loaded := load_level(*level, xx editor.load_level_field);
        game_state.move_stack = .{};
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
            if loaded {
                game_state.move_stack = .{};
            }
        }
        ImGui.SameLine();
        if level.id != 0 {
            if ImGui.Button("Restart Level") {
                loaded := load_level(*level, xx level.name);
                if loaded {
                    game_state.move_stack = .{};
                }
            }
        }
        ImGui.SameLine();
        if ImGui.Button("New level") {
            on_new_level_pressed(game_state);
        }
    } else {
        ImGui.InputText("##save", editor.save_level_field.data, MAX_LEVEL_NAME_LENGTH);
        ImGui.SameLine();
        if ImGui.Button("Save Level") {
            if editor.save_level_field[0] == 0 {
                save_level(*level, xx level.name);
            } else {
                save_level(*level, xx editor.save_level_field);
            }
            
            for 0..editor.save_level_field.count-1 {
                editor.save_level_field[it] = 0;
            }
        }
        if ImGui.Button("Play Level") {
            if level.id == 0 {
                print("Save level first!\n");
            } else {
                save_level(*level, xx level.name);
                loaded := load_level(*level, xx level.name);
                if loaded {
                    game_state.move_stack = .{};
                }
                editor.editing_level = false;
            }
        }
        ImGui.SameLine();
        if ImGui.Button("New level") {
            on_new_level_pressed(game_state);
        }

        if ImGui.Button("Paint") {
            editor.tool = .PAINT;
        }
        ImGui.SameLine();
        if ImGui.Button("Select") {
            editor.tool = .SELECT;
            editor.select_state = .NOT_STARTED;
        }
        ImGui.SameLine();
        if ImGui.Button("Move") {
            if editor.tool == .SELECT && editor.select_state == .FINISHED {
                editor.tool = .MOVE;
                editor.move_state = .NOT_STARTED;
            }
        }
        ImGui.SameLine();
        if ImGui.Button("Paste") {
            editor.tool = .PASTE;
        }

        img_pos := window_pos + .{0, 160};

        draw_list.AddImage(draw_list, cast,no_check(*void)(sprites.id), img_pos, img_pos + dest);

        if ImGui.Button("Add left") {
            level_increase_dimensions(*level, 1, 0, 0, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("Add right") {
            level_increase_dimensions(*level, 0, 1, 0, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("Add top") {
            level_increase_dimensions(*level, 0, 0, 1, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("Add bot") {
            level_increase_dimensions(*level, 0, 0, 0, 1);
        }

        if ImGui.Button("Rem left") {
            level_increase_dimensions(*level, -1, 0, 0, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("Rem right") {
            level_increase_dimensions(*level, 0, -1, 0, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("Rem top") {
            level_increase_dimensions(*level, 0, 0, -1, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("Rem bot") {
            level_increase_dimensions(*level, 0, 0, 0, -1);
        }



        // Selected tile
        focused := ImGui.IsWindowFocused();
        mouse_x, mouse_y := get_mouse_position_explicit();

        highlighted := false;
        highlighted_block : int;
        highlighted_xy : Vector2;

        if mouse_x >= xx img_pos.x && mouse_x < xx img_pos.x + sprites_imgui.width * TILE_SCALE {
            if mouse_y >= xx img_pos.y && mouse_y < xx img_pos.y + sprites_imgui.height * TILE_SCALE {
                highlighted_xy.x = floor((mouse_x - img_pos.x) / TILE_SIZE);
                highlighted_xy.y = floor((mouse_y - img_pos.y) / TILE_SIZE);

                highlighted_block = xx (highlighted_xy.x + highlighted_xy.y * 8);
                highlighted = true;

                if focused {
                    if ImGui.IsMouseDown(ImGui.MouseButton.Left) {
                        block: Block;
                        if highlighted_block == 2 {
                            block.type = .BOULDER;
                        } else if highlighted_block == 3 {
                            block.type = .WALL;
                        } else if highlighted_block == 4 {
                            block.type = .PLAYER_SPAWN;
                        } else if highlighted_block == 5 {
                            block.type = .SIGNED_PHOTOGRAPH;
                        } else if highlighted_block >= 8 && highlighted_block < 16 {
                            block.type = .NUMBERED;
                            block.number = xx (highlighted_block - 7);
                        } else if highlighted_block >= 16 && highlighted_block < 24 {
                            block.type = .WALL;
                            block.number = xx (highlighted_block - 15);
                        } else if highlighted_block >= 24 && highlighted_block < 32 {
                            block.type == .NONE;
                            block.number = xx (highlighted_block - 23);
                        }
                        editor.selected_block = block;
                        editor.selected_block_pos = highlighted_xy;
                    }
                }
            }
        }

        if highlighted && editor.selected_block_pos != highlighted_xy {
            p1 := ImGui.ImVec2.{highlighted_xy.x * TILE_SIZE, highlighted_xy.y * TILE_SIZE};
            p2 := p1 + .{TILE_SIZE, 0};
            p3 := p1 + .{TILE_SIZE, TILE_SIZE};
            p4 := p1 + .{0, TILE_SIZE};
            colf := Vector4.{1, 1, 0, 1};
            
            draw_list.AddQuad(draw_list, img_pos + p1, img_pos + p2, img_pos + p3, img_pos + p4, ImGui.GetColorU32(colf), 2);
        }

        if editor.selected_block.type != .NONE {
            p1 := ImGui.ImVec2.{editor.selected_block_pos.x * TILE_SIZE, editor.selected_block_pos.y * TILE_SIZE};
            p2 := p1 + .{TILE_SIZE, 0};
            p3 := p1 + .{TILE_SIZE, TILE_SIZE};
            p4 := p1 + .{0, TILE_SIZE};
            colf := Vector4.{0, 1, 0, 1};
            
            draw_list.AddQuad(draw_list, img_pos + p1, img_pos + p2, img_pos + p3, img_pos + p4, ImGui.GetColorU32(colf), 2);
        }
    }
}


update_editor :: (using game_state: *Game_State, input: *Input_State) {
    mouse_world_pos := get_mouse_world_pos(camera);
    editor.mouse_tile = v2i.{xx (mouse_world_pos.x / 64), xx (mouse_world_pos.y / 64)};
    mouse_tile := editor.mouse_tile;

    if input.mouse_wheel {
        if input.mouse_wheel > 0 {
            camera.zoom *= 2.0;
        } else {
            camera.zoom *= 0.5;
        }
    }

    if editor.tool == {
        case .PAINT; {
            if input.mouse_pressed || input.rmouse_pressed || input.mwheel_pressed {
                if is_in_bounds(mouse_tile, *level) {
                    // Spawn blocks have special functionality and don't show up in game
                    if editor.selected_block.type == .PLAYER_SPAWN {
                        level.player_spawn_pos = .{mouse_tile.x, mouse_tile.y};
                    } else {
                        level.grid[mouse_tile.x][mouse_tile.y] = editor.selected_block;
                        if input.rmouse_pressed {
                            level.grid[mouse_tile.x][mouse_tile.y].flags |= Block.Flag.GOAL;
                        } else if input.mwheel_pressed {
                            level.grid[mouse_tile.x][mouse_tile.y].flags |= Block.Flag.VANISH_GOAL;
                        }
                    }
                }
            }
        }
        case .SELECT; {
            if is_in_bounds(mouse_tile, *level) {
                if editor.select_state == .NOT_STARTED {
                    editor.select_end = mouse_tile;
                    if input.mouse_just_pressed {
                        editor.select_start = mouse_tile;
                        editor.select_state = .STARTED;
                    }
                } else if editor.select_state == .STARTED {
                    editor.select_end = mouse_tile;
                    if input.mouse_just_released {
                        editor.select_state = .FINISHED;
                    }
                } else if editor.select_state == .FINISHED {
                    if input.mouse_just_pressed {
                        editor.select_start = mouse_tile;
                        editor.select_end = mouse_tile;
                        editor.select_state = .STARTED;
                    }
                }
            }
        }
        case .MOVE; {
            move_tiles :: (using game_state: *Game_State, offset: v2i) {
                start, end : v2i;
                start.x = min(editor.select_end.x, editor.select_start.x);
                start.y = min(editor.select_end.y, editor.select_start.y);
                end.x   = max(editor.select_end.x, editor.select_start.x);
                end.y   = max(editor.select_end.y, editor.select_start.y);
                
                selection_size := end - start + .{1, 1};
                memory := cast(*Block) temporary_alloc(selection_size.x * selection_size.y * size_of(Block));

                for x: 0..selection_size.x-1 {
                    for y: 0..selection_size.y-1 {
                        memory[x + y * selection_size.x] = level.grid[start.x + x][start.y + y];
                        level.grid[start.x + x][start.y + y] = .{};
                    }
                }

                for x: 0..selection_size.x-1 {
                    for y: 0..selection_size.y-1 {
                        copied_block := memory[x + y * selection_size.x];
                        block_ptr := *level.grid[start.x + x + offset.x][start.y + y + offset.y];
                        if copied_block.type != .NONE {
                            block_ptr.* = copied_block;
                        }
                    }
                }

                // Move the selection
                editor.select_start += offset;
                editor.select_end += offset;
            }

            if is_in_bounds(mouse_tile, *level) {
                if editor.move_state == .NOT_STARTED {
                    if input.mouse_just_pressed {
                        editor.move_state = .STARTED;
                        editor.move_start = mouse_tile;
                        editor.move_end = mouse_tile;
                    }
                } else if editor.move_state == .STARTED {
                    if mouse_tile != editor.move_end {
                        editor.move_end = mouse_tile;
                    }
                    if input.mouse_just_released {
                        editor.move_state = .NOT_STARTED;
                        // Move all the tiles
                        move_tiles(game_state, editor.move_end - editor.move_start);
                    }
                }
            }
        }
    }
}
