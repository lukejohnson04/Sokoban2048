
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
    layer: int;

    tool : Editor_Tool = .BRUSH;
    mouse_tile : v2i;
    block_flip_x: bool;
    block_flip_y: bool;
    fill_all_layers: bool;
    show_both_layers: bool = true;

    select_state := Editor_Select_State.NOT_STARTED;
    select_start : v2i;
    select_end : v2i;

    move_state := Editor_Move_State.NOT_STARTED;
    move_start : v2i;
    move_end : v2i;

    load_level_field : [MAX_LEVEL_NAME_LENGTH]u8;
    save_level_field : [MAX_LEVEL_NAME_LENGTH]u8;
    dimension_field : [MAX_LEVEL_NAME_LENGTH]u8;

    interaction_id : s32;

    Editor_Tool :: enum {
        BRUSH;
        SELECT;
        MOVE;
        FILL;
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

draw_editor :: () {
    using context.game_state;
    game_state := context.game_state;

    draw_list := ImGui.GetWindowDrawList();
    window_pos := ImGui.GetCursorScreenPos();

    TILE_SCALE :: 2;
    TILE_SIZE :: 16 * TILE_SCALE;

    source := ImGui.ImVec2.{xx sprites_imgui.width, xx sprites_imgui.height};
    dest := ImGui.ImVec2.{xx (sprites_imgui.width * TILE_SCALE), xx (sprites_imgui.height * TILE_SCALE)};

    loaded := false;

    on_new_level_pressed :: () {
        using context.game_state;
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
        loaded = load_level(*level, xx editor.load_level_field, *game_state.field);
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
            loaded = load_level(*level, xx level.name, *game_state.field);
            if loaded {
                game_state.move_stack = .{};
            }
        }
        ImGui.SameLine();
        if level.id != 0 {
            if ImGui.Button("Restart Level") {
                loaded = load_level(*level, xx level.name, *game_state.field);
                if loaded {
                    game_state.move_stack = .{};
                }
            }
        }
        ImGui.SameLine();
        if ImGui.Button("New level") {
            on_new_level_pressed();
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
                loaded = load_level(*level, xx level.name, *game_state.field);
                camera.zoom = 1;
                if loaded {
                    game_state.move_stack = .{};
                }
                editor.editing_level = false;
            }
        }
        ImGui.SameLine();
        if ImGui.Button("New level") {
            on_new_level_pressed();
        }

        items := string.["Layer1", "Floor"];
        if ImGui.BeginCombo("##combo", items[editor.layer].data) {
            for 0..items.count-1 {
                is_selected : bool = editor.layer == it;
                if ImGui.Selectable(items[it].data, is_selected) {
                    editor.layer = it;
                }

                if is_selected {
                    ImGui.SetItemDefaultFocus();
                }
            }
            ImGui.EndCombo();
        }
        ImGui.SameLine();
        ImGui.Checkbox("Show all layers", *editor.show_both_layers);


        if ImGui.Button("Brush") {
            editor.tool = .BRUSH;
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
        if ImGui.Button("Fill") {
            editor.tool = .FILL;
        }

        ImGui.SameLine();
        ImGui.Checkbox("Fill All Layers", *editor.fill_all_layers);
        ImGui.SameLine();
        ImGui.Checkbox("Flip x", *editor.block_flip_x);
        ImGui.SameLine();
        ImGui.Checkbox("Flip y", *editor.block_flip_y);

        img_pos := window_pos + .{0, 215};

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


        ImGui.PushItemWidth(150);
        ImGui.InputInt("Interaction Id", *editor.interaction_id);
        if editor.tool == .SELECT && editor.select_start == editor.select_end {
            if is_in_bounds(editor.select_start, *level) {
                ImGui.SameLine();
                if ImGui.Button("Set interaction id") {
                    tile := level.grid[editor.select_start.x][editor.select_start.y];
                    if tile.type != .NONE {
                        if editor.interaction_id > 65535 || editor.interaction_id < 0 {
                            print("Interaction id is out of range of u16!\n");
                        } else {
                            level.grid[editor.select_start.x][editor.select_start.y].interaction_id = xx editor.interaction_id;
                        }
                    }
                }
            }
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
                        } else if highlighted_block == 6 {
                            block.type = .BLOCK_BARRIER;
                        } else if highlighted_block == 7 {
                            block.type = .INTERACTABLE;
                            block.interaction_id = 10_000;
                        } else if highlighted_block >= 8 && highlighted_block < 16 {
                            block.type = .NUMBERED;
                            block.number = xx (highlighted_block - 7);
                        } else if highlighted_block >= 16 && highlighted_block < 24 {
                            block.type = .WALL;
                            block.number = xx (highlighted_block - 15);
                        } else if highlighted_block >= 24 && highlighted_block < 48 {
                            block.type = .NONE;
                            block.number = xx (highlighted_block - 23);
                        } else if highlighted_block >= 48 && highlighted_block < 56 {
                            block.type = .INTERACTABLE;
                            block.number = xx (highlighted_block - 40);
                        } else if highlighted_block >= 56 && highlighted_block < 64 {
                            block.type = .INTERACTABLE;
                            block.number = xx (highlighted_block - 56);
                        }
                        editor.selected_block = block;
                        editor.selected_block_pos = highlighted_xy;
                    }
                }
            }
        }

        // Make sure flip is always synchronized with checkbox
        if editor.selected_block.type != .NONE {
            if editor.block_flip_x != cast(bool) (editor.selected_block.flags & .FLIPPED_X) {
                editor.selected_block.flags ^= .FLIPPED_X;
            }
            if editor.block_flip_y != cast(bool) (editor.selected_block.flags & .FLIPPED_Y) {
                editor.selected_block.flags ^= .FLIPPED_Y;
            }
        }

        // Draw yellow rect around hovered tile
        if highlighted && editor.selected_block_pos != highlighted_xy {
            p1 := ImGui.ImVec2.{highlighted_xy.x * TILE_SIZE, highlighted_xy.y * TILE_SIZE};
            p2 := p1 + .{TILE_SIZE, 0};
            p3 := p1 + .{TILE_SIZE, TILE_SIZE};
            p4 := p1 + .{0, TILE_SIZE};
            colf := Vector4.{1, 1, 0, 1};
            
            draw_list.AddQuad(draw_list, img_pos + p1, img_pos + p2, img_pos + p3, img_pos + p4, ImGui.GetColorU32(colf), 2);
        }

        // Draw green rect around selected tile
        if editor.selected_block.type != .NONE {
            p1 := ImGui.ImVec2.{editor.selected_block_pos.x * TILE_SIZE, editor.selected_block_pos.y * TILE_SIZE};
            p2 := p1 + .{TILE_SIZE, 0};
            p3 := p1 + .{TILE_SIZE, TILE_SIZE};
            p4 := p1 + .{0, TILE_SIZE};
            colf := Vector4.{0, 1, 0, 1};
            
            draw_list.AddQuad(draw_list, img_pos + p1, img_pos + p2, img_pos + p3, img_pos + p4, ImGui.GetColorU32(colf), 2);
        }
    }
    if loaded {
        vfield_generate_flood_fill(*level, game_state.field);
        generate_level_mesh();
    }
}


update_editor :: (input: *Input_State) {
    using context.game_state;
    mouse_world_pos := get_mouse_world_pos(camera);
    editor.mouse_tile = v2i.{xx (mouse_world_pos.x / 64), xx (mouse_world_pos.y / 64)};
    mouse_tile := editor.mouse_tile;

    if input.mouse_wheel {
        zoom_factor := ifx input.mouse_wheel > 0 then 2.0 else 0.5;
        camera_zoom(*camera, get_mouse_position(), zoom_factor);
    }

    blocks : *type_of(Level.grid);
    if editor.layer == 0 {
        blocks = *level.grid;
    } else if editor.layer == 1 {
        blocks = *level.floor;
    } else {
        return;
    }

    changed_map := false;

    if editor.tool == {
        case .BRUSH; {
            if input.mouse_pressed || input.rmouse_pressed || input.mwheel_pressed {
                if is_in_bounds(mouse_tile, *level) {
                    // Spawn blocks have special functionality and don't show up in game
                    if editor.selected_block.type == .PLAYER_SPAWN {
                        level.player_spawn_pos = .{mouse_tile.x, mouse_tile.y};
                    } else {
                        if blocks == *level.floor {
                            if editor.selected_block.type != .NONE {
                                return;
                            }
                        }
                        blocks.*[mouse_tile.x][mouse_tile.y] = editor.selected_block;
                        if input.rmouse_pressed {
                            blocks.*[mouse_tile.x][mouse_tile.y].flags |= Block.Flag.GOAL;
                        } else if input.mwheel_pressed {
                            blocks.*[mouse_tile.x][mouse_tile.y].flags |= Block.Flag.VANISH_GOAL;
                        }
                    }
                    changed_map = true;
                }
            }
        }
        case .FILL; {
            editor_paint_fill :: (level: *Level, editor: *Editor_State, start_pos: v2i, start_block: Block) {
                field := cast(*Visibility_Field)New(Visibility_Field);
                for x: 0..level.dimensions.x-1 {
                    for y: 0..level.dimensions.y-1 {
                        field.*[x][y] = .{.{x, y}, false, false, 0};
                    }
                }

                blocks: *type_of(Level.grid);
                if editor.layer == 0 {
                    blocks = *level.grid;
                } else if editor.layer == 1 {
                    blocks = *level.floor;
                }

                queue := cast(*Queue(v2i,1000))New(Queue(v2i, 1000));
                queue_add(queue, start_pos);
                comparison_block := blocks.*[start_pos.x][start_pos.y];

                dirs := v2i.[.{1,0}, .{0,1}, .{-1,0}, .{0,-1}];

                while queue_is_empty(queue) == false {
                    coord := queue_remove(queue);
                    if field.*[coord.x][coord.y].visited continue;
                    field.*[coord.x][coord.y].visible = true;
                    field.*[coord.x][coord.y].visited = true;
                    for dir: dirs {
                        pos := coord + dir;
                        
                        if !is_in_bounds(pos, level) continue;
                        if field.*[pos.x][pos.y].visited continue;
                        block := blocks.*[pos.x][pos.y];

                        if block != comparison_block {
                            continue;
                        }
                        if editor.fill_all_layers {
                            other_block: Block;
                            if blocks == *level.floor {
                                other_block = level.grid[pos.x][pos.y];
                            } else {
                                other_block = level.floor[pos.x][pos.y];
                            }
                            if other_block != comparison_block && other_block.type != .NONE {
                                continue;
                            }
                        }
                        
                        queue_add(queue, pos);
                    }
                }
                for x: 0..level.dimensions.x-1 {
                    for y: 0..level.dimensions.y-1 {
                        if field.*[x][y].visible {
                            blocks.*[x][y] = start_block;
                        }
                    }
                }
                free(field);
                free(queue);
            }
            
            if input.mouse_pressed || input.rmouse_pressed || input.mwheel_pressed {
                if is_in_bounds(mouse_tile, *level) {
                    editor_paint_fill(*level, *editor, mouse_tile, editor.selected_block);
                    changed_map = true;
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
            move_tiles :: (blocks: *type_of(Level.grid), offset: v2i) {
                using context.game_state;
                start, end : v2i;
                start.x = min(editor.select_end.x, editor.select_start.x);
                start.y = min(editor.select_end.y, editor.select_start.y);
                end.x   = max(editor.select_end.x, editor.select_start.x);
                end.y   = max(editor.select_end.y, editor.select_start.y);
                
                selection_size := end - start + .{1, 1};
                memory := cast(*Block) temporary_alloc(selection_size.x * selection_size.y * size_of(Block));

                for x: 0..selection_size.x-1 {
                    for y: 0..selection_size.y-1 {
                        memory[x + y * selection_size.x] = blocks.*[start.x + x][start.y + y];
                        blocks.*[start.x + x][start.y + y] = .{};
                    }
                }

                for x: 0..selection_size.x-1 {
                    for y: 0..selection_size.y-1 {
                        copied_block := memory[x + y * selection_size.x];
                        block_ptr := *blocks.*[start.x + x + offset.x][start.y + y + offset.y];
                        if copied_block != .{} {
                            block_ptr.* = copied_block;
                        }
                    }
                }
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
                        changed_map = true;
                        editor.move_state = .NOT_STARTED;
                        // Move all the tiles
                        move_tiles(*level.grid, editor.move_end - editor.move_start);
                        move_tiles(*level.floor, editor.move_end - editor.move_start);
                        editor.select_start += editor.move_end - editor.move_start;
                        editor.select_end += editor.move_end - editor.move_start;
                    }
                }
            }
        }
    }

    if changed_map {
        generate_level_mesh();
    }
}

editor_draw :: () {
    using context.game_state;
    
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
}
