
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
    move_camera_with_mouse: bool;
    show_portal_connections: bool;

    select_state := Editor_Select_State.NOT_STARTED;
    select_start : v2i;
    select_end : v2i;

    move_state := Editor_Move_State.NOT_STARTED;
    move_start : v2i;
    move_end : v2i;

    link_state := Editor_Link_State.NOT_STARTED;
    link_start : v2i;

    // ImGui state
    load_level_field : [MAX_LEVEL_NAME_LENGTH]u8;
    save_level_field : [MAX_LEVEL_NAME_LENGTH]u8;
    dimension_field : [MAX_LEVEL_NAME_LENGTH]u8;

    interaction_id : s32;
    turns_on_inactive : s32;
    turns_on_active : s32;

    // Copy buffer (for copying blocks)
    // Max copy size is 256 x 256 blocks
    copy_buffer : [EDITOR_MAX_COPY_SIZE][EDITOR_MAX_COPY_SIZE] Block;
    copy_size : v2i;

    // For rotating or other random junk
    temp_buffer : [EDITOR_MAX_COPY_SIZE][EDITOR_MAX_COPY_SIZE] Block;

    Editor_Tool :: enum {
        BRUSH;
        SELECT;
        MOVE;
        FILL;
        STAMP;
        LINK;
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

    Editor_Link_State :: enum {
        NOT_STARTED;
        STARTED;
    }
}

EDITOR_MAX_COPY_SIZE :: 256;

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

    if ImGui.CollapsingHeader("File") {
        if level.id != 0 {
            ImGui.LabelText("##level_title", tprint("Level: %", cast(string) level.name));
        } else {
            ImGui.LabelText("##level_title", "No level loaded");
        }
        ImGui.InputText("##load", editor.load_level_field.data, MAX_LEVEL_NAME_LENGTH);
        ImGui.SameLine();
        if ImGui.Button("Load Level") {
            loaded = load_level(*level, xx editor.load_level_field, *game_state.field);
            clear_turn_memory(*turn_memory);
            if loaded {
                for 0..editor.load_level_field.count-1 {
                    editor.load_level_field[it] = 0;
                }
                editor.editing_level = true;
            }
        }
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
        ImGui.SameLine();
        if ImGui.Button("New level") {
            on_new_level_pressed();
        }
    }

    
    if editor.editing_level == false {
        if ImGui.Button("Edit Level") {
            editor.editing_level = true;
            loaded = load_level(*level, xx level.name, *game_state.field);
            if loaded { 
                clear_turn_memory(*turn_memory);
            }
        }
        ImGui.SameLine();
        if level.id != 0 {
            if ImGui.Button("Restart Level") {
                loaded = load_level(*level, xx level.name, *game_state.field);
                turn_count = 0;
                if loaded {
                    clear_turn_memory(*turn_memory);
                }
            }
        }
        return;
    }
    if ImGui.Button("Play Level") {
        if level.id == 0 {
            print("Save level first!\n");
        } else {
            save_level(*level, xx level.name);
            loaded = load_level(*level, xx level.name, *game_state.field);
            turn_count = 0;
            camera.zoom = 1;
            if loaded {
                clear_turn_memory(*turn_memory);
            }
            editor.editing_level = false;
        }
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

    // Tools
    ImGui.SeparatorText("Tools");
    {
        using ImGui.Col;
        ImGui.PushStyleColor(ImGuiCol_Button, HSV(0.0, 0.6, 0.6));
        ImGui.PushStyleColor(ImGuiCol_ButtonHovered, HSV(0, 0.7, 0.7));
        ImGui.PushStyleColor(ImGuiCol_ButtonActive, HSV(0, 0.8, 0.8));
        if ImGui.Button("Brush") {
            editor.tool = .BRUSH;
        }
        ImGui.PopStyleColor(3);
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
        if ImGui.Button("Stamp") {
            if editor.copy_size != .{0, 0} {
                editor.tool = .STAMP;
            }
        } 

        ImGui.PushStyleColor(ImGuiCol_Button, HSV(0.0, 0.6, 0.6));
        ImGui.PushStyleColor(ImGuiCol_ButtonHovered, HSV(0, 0.7, 0.7));
        ImGui.PushStyleColor(ImGuiCol_ButtonActive, HSV(0, 0.8, 0.8));
        ImGui.SameLine();
        if ImGui.Button("Link Portal") {
            editor.tool = .LINK;
        }
        ImGui.PopStyleColor(3);


        if editor.tool == .SELECT || editor.tool == .MOVE {
            if ImGui.Button("Flip horizontally") {
                flip_tiles(*level.grid, true, false);
            }
            if ImGui.Button("Flip vertically") {
                flip_tiles(*level.grid, false, true);
            }

            // Rotate
            if ImGui.ImageButton(cast(*void)(counter_clockwise_arrow_texture.id), .{16, 16}) {
                rotate_tiles(*level.grid, false);
            }
            ImGui.SameLine();
            if ImGui.ImageButton(cast(*void)(clockwise_arrow_texture.id), .{16, 16}) {
                rotate_tiles(*level.grid, true);
            }
            
            if ImGui.Button("Copy") {
                copy_tiles(*level.grid, *editor.copy_buffer);
            }
        }
    }

    ImGui.SameLine();
    ImGui.Checkbox("Fill All Layers", *editor.fill_all_layers);
    ImGui.SameLine();
    ImGui.Checkbox("Flip x", *editor.block_flip_x);
    ImGui.SameLine();
    ImGui.Checkbox("Flip y", *editor.block_flip_y);

    ImGui.SeparatorText("Map settings");
    {
        if ImGui.Button("+L") {
            level_increase_dimensions(*level, 1, 0, 0, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("+R") {
            level_increase_dimensions(*level, 0, 1, 0, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("+T") {
            level_increase_dimensions(*level, 0, 0, 1, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("+B") {
            level_increase_dimensions(*level, 0, 0, 0, 1);
        }
        ImGui.SameLine();
        if ImGui.Button("Max") {
            level_increase_dimensions(*level, 0, Level.MAX_WIDTH - level.dimensions.x, 0, Level.MAX_HEIGHT - level.dimensions.y);
        }


        if ImGui.Button("-L") {
            level_increase_dimensions(*level, -1, 0, 0, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("-R") {
            level_increase_dimensions(*level, 0, -1, 0, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("-T") {
            level_increase_dimensions(*level, 0, 0, -1, 0);
        }
        ImGui.SameLine();
        if ImGui.Button("-B") {
            level_increase_dimensions(*level, 0, 0, 0, -1);
        }
    }
    

    // Tile picker
    ImGui.SeparatorText("Tile picker");
    {
        using ImGui.StyleVar;
        img_pos := ImGui.GetCursorScreenPos();
        ImGui.Image(cast(*void)(sprites.id), .{xx sprites.width * 2.0, xx sprites.height * 2.0}, .{0, 0}, .{1, 1});

        // draw_list.AddImage(draw_list, cast,no_check(*void)(sprites.id), img_pos, img_pos + dest);
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

                highlighted_block = xx (highlighted_xy.x + highlighted_xy.y * 16);
                highlighted = true;

                if ImGui.IsMouseDown(ImGui.MouseButton.Left) {
                    block: Block;
                    block.id = xx highlighted_block;
                    editor.selected_block = block;
                    editor.selected_block_pos = highlighted_xy;
                }
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
        p1 := ImGui.ImVec2.{editor.selected_block_pos.x * TILE_SIZE, editor.selected_block_pos.y * TILE_SIZE};
        p2 := p1 + .{TILE_SIZE, 0};
        p3 := p1 + .{TILE_SIZE, TILE_SIZE};
        p4 := p1 + .{0, TILE_SIZE};
        colf := Vector4.{1, 0, 0, 1};
        
        draw_list.AddQuad(draw_list, img_pos + p1, img_pos + p2, img_pos + p3, img_pos + p4, ImGui.GetColorU32(colf), 2);
    }
    // Make sure flip is always synchronized with checkbox
    if get_block_type(editor.selected_block) != .NONE {
        if editor.block_flip_x != cast(bool) (editor.selected_block.flags & .FLIPPED_X) {
            editor.selected_block.flags ^= .FLIPPED_X;
        }
        if editor.block_flip_y != cast(bool) (editor.selected_block.flags & .FLIPPED_Y) {
            editor.selected_block.flags ^= .FLIPPED_Y;
        }
    }

    ImGui.PushItemWidth(150);
    ImGui.InputInt("Interaction Id", *editor.interaction_id);
    if editor.tool == .SELECT && editor.select_start == editor.select_end {
        if is_in_bounds(editor.select_start, *level) {
            ImGui.SameLine();
            if ImGui.Button("Set") {
                tile := level.grid[editor.select_start.x][editor.select_start.y];
                if get_block_type(tile) != .NONE {
                    if editor.interaction_id > 65535 || editor.interaction_id < 0 {
                        print("Interaction id is out of range of u16!\n");
                    } else {
                        level.grid[editor.select_start.x][editor.select_start.y].interaction_id = xx editor.interaction_id;
                    }
                }
            }
        }

    }
    ImGui.PushItemWidth(150);
    ImGui.InputInt("Turns on inanctive", *editor.turns_on_inactive);
    if editor.tool == .SELECT && editor.select_start == editor.select_end {
        if is_in_bounds(editor.select_start, *level) {
            ImGui.SameLine();
            if ImGui.Button("Set") {
                level.grid[editor.select_start.x][editor.select_start.y].turns_on_inactive = xx editor.turns_on_inactive;
            }
        }
    }
    ImGui.PushItemWidth(150);
    ImGui.InputInt("Turns on active", *editor.turns_on_active);
    if editor.tool == .SELECT && editor.select_start == editor.select_end {
        if is_in_bounds(editor.select_start, *level) {
            ImGui.SameLine();
            if ImGui.Button("Set") {
                level.grid[editor.select_start.x][editor.select_start.y].turns_on_active = xx editor.turns_on_active;
            }
        }
    }
    editor.selected_block.turns_on_active = xx editor.turns_on_active;
    editor.selected_block.turns_on_inactive = xx editor.turns_on_inactive;

    ImGui.SeparatorText("Controls");
    {
        ImGui.Checkbox("Mouse Cam", *editor.move_camera_with_mouse);
        ImGui.Checkbox("Show portal connections", *editor.show_portal_connections);
    }

    if loaded {
        level_mesh_needs_update = true;
        // vfield_generate_flood_fill(*level, game_state.field);
        // generate_level_mesh();
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

    if editor.tool == {
        case .BRUSH; {
            if input.mouse_pressed || input.rmouse_pressed || input.mwheel_pressed {
                if is_in_bounds(mouse_tile, *level) {
                    // Spawn blocks have special functionality and don't show up in game
                    if get_block_type(editor.selected_block) == .PLAYER_SPAWN {
                        level.player_spawn_pos = .{mouse_tile.x, mouse_tile.y};
                    } else {
                        if blocks == *level.floor {
                            if get_block_type(editor.selected_block) != .NONE {
                                return;
                            }
                        }
                        new_block := editor.selected_block;
                        if input.rmouse_pressed {
                            new_block.flags |= Block.Flag.GOAL;
                        } else if input.mwheel_pressed || input.is_pressed[SDL_SCANCODE_LALT] {
                            new_block.flags |= Block.Flag.VANISH_GOAL;
                        } if input.is_pressed[SDL_SCANCODE_LCTRL] {
                            new_block.flags |= Block.Flag.TIMER;
                            new_block.timer_turns_left = 0;
                            new_block.turns_on_active = cast(u8)editor.turns_on_active;
                            new_block.turns_on_inactive = cast(u8)editor.turns_on_inactive;
                            new_block.timer_is_solid = true;
                        }
                        if blocks.*[mouse_tile.x][mouse_tile.y] != new_block {
                            blocks.*[mouse_tile.x][mouse_tile.y] = new_block;
                            level_mesh_needs_update = true;
                        }
                    }
                }
            }
        }
        case .FILL; {            
            if input.mouse_pressed || input.rmouse_pressed || input.mwheel_pressed {
                if is_in_bounds(mouse_tile, *level) {
                    paint_fill(*level, *editor, mouse_tile, editor.selected_block);                    
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
                        move_tiles(*level.grid, editor.move_end - editor.move_start);
                        move_tiles(*level.floor, editor.move_end - editor.move_start);
                        editor.select_start += editor.move_end - editor.move_start;
                        editor.select_end += editor.move_end - editor.move_start;
                    }
                }
            }
        }
        case .STAMP; {
            if input.mouse_just_pressed {
                stamp_tiles(*level.grid, *editor.copy_buffer);
            }
        }
        case .LINK; {
            if editor.link_state == .NOT_STARTED {
                if !input.mouse_just_pressed {
                    return;
                }
                if !is_in_bounds(mouse_tile, *level) {
                    return;
                }
                if get_block_type(level.grid[mouse_tile.x][mouse_tile.y]) != .PORTAL {
                    return;
                }
                editor.link_start = mouse_tile;
                editor.link_state = .STARTED;
                level.grid[mouse_tile.x][mouse_tile.y].interaction_id = 0;
                level_mesh_needs_update = true;
            } else if editor.link_state == .STARTED {
                if input.mouse_just_released == false {
                    return;
                }
                if !is_in_bounds(mouse_tile, *level) {
                    return;
                }
                if get_block_type(level.grid[mouse_tile.x][mouse_tile.y]) != .PORTAL {
                    return;
                }
                level.grid[editor.link_start.x][editor.link_start.y].interaction_id = 9999;
                level.grid[mouse_tile.x][mouse_tile.y].interaction_id = 9999;
                level_mesh_needs_update = true;
                editor.link_state = .NOT_STARTED;
            }
        }
    }
}

editor_draw :: () {
    using context.game_state;
    if editor.editing_level == false || editor.enabled == false {
        return;
    }
    
    if (editor.tool == .BRUSH || editor.tool == .FILL) && is_in_bounds(editor.mouse_tile, *level) {
        block := editor.selected_block;
        source := get_block_source(block);
        dest := Rect.{xx (editor.mouse_tile.x * 64), xx (editor.mouse_tile.y * 64), 64, 64};
        draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);
    }

    spawn : Block;
    spawn.id = 4;
    source := get_block_source(spawn);
    dest := Rect.{xx (level.player_spawn_pos.x*64), xx (level.player_spawn_pos.y*64), 64, 64};
    draw_texture(source, dest, *sprites, intermediate_vao, intermediate_vbo);

    // Editor draw final pass
    use_shader(color_shader);
    TILE_SIZE :: 64;

    // Select tool
    if (editor.tool == .SELECT || editor.tool == .MOVE) && editor.select_state != .NOT_STARTED
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
        rect = CoordRect(rect);
        
        draw_rect_with_outline(rect, 4, color_vao, color_vbo);
    }

    if editor.tool == .STAMP {
        start, end : v2i;
        start = editor.mouse_tile;
        end = start + editor.copy_size;
        
        selection_size := end - start;

        rect : Rect;
        rect.x = xx (start.x * TILE_SIZE);
        rect.y = xx (start.y * TILE_SIZE);
        rect.w = xx (selection_size.x * TILE_SIZE);
        rect.h = xx (selection_size.y * TILE_SIZE);
        rect = CoordRect(rect);
        
        draw_rect_with_outline(rect, 4, color_vao, color_vbo);
    }

    if editor.tool == .LINK {
        if editor.link_state == .STARTED {
            first := editor.link_start;
            p1 := Vector2.{xx first.x * 64.0, xx first.y * 64.0};
            p2 := Vector2.{xx editor.mouse_tile.x * 64.0, xx editor.mouse_tile.y * 64.0};
            p1 += .{32.0, 32.0};
            p2 += .{32.0, 32.0};
            draw_line_with_thickness(p1, p2, 10);
        }
    }

    if editor.show_portal_connections {
        draw_portal_connections();
    }
}

draw_portal_connections :: () {
    using context.game_state;
    shader_uniform(color_shader, "color", Vector4.{0, 0, 1, 1});
    for 0..portal_list.count-1 {
        defer it += 1;
        first := portal_list[it];
        second := portal_list[it + 1];
        if second == .{-1, -1} continue;

        p1 := Vector2.{xx first.x * 64.0, xx first.y * 64.0};
        p2 := Vector2.{xx second.x * 64.0, xx second.y * 64.0};
        p1 += .{32.0, 32.0};
        p2 += .{32.0, 32.0};
        draw_line_with_thickness(p1, p2, 10);
    }
}

HSV :: (h: float, s: float, v: float, a: float = 1.0) -> Vector4 {
    r, g, b: float;
    ImGui.ColorConvertHSVtoRGB(h, s, v, *r, *g, *b);
    return .{r, g, b, a};
}

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
    level_mesh_needs_update = true;
}

flip_tiles :: (blocks: *type_of(Level.grid), flip_x: bool, flip_y: bool) {
    using context.game_state;
    start, end : v2i;
    start.x = min(editor.select_end.x, editor.select_start.x);
    start.y = min(editor.select_end.y, editor.select_start.y);
    end.x   = max(editor.select_end.x, editor.select_start.x);
    end.y   = max(editor.select_end.y, editor.select_start.y);
    
    selection_size := end - start;

    for x: 0..ifx flip_x selection_size.x/2 else selection_size.x {
        for y: 0..ifx flip_y selection_size.y/2 else selection_size.y {
            temp_block := blocks.*[start.x + x][start.y + y];
            end_block := *blocks.*[ifx flip_x end.x - x else start.x + x][ifx flip_y end.y - y else start.y + y];
            blocks.*[start.x + x][start.y + y] = end_block.*;
            end_block.* = temp_block;
        }
    }
    level_mesh_needs_update = true;
}

rotate_tiles :: (blocks: *type_of(Level.grid), $clockwise: bool) {
    using context.game_state;
    start, end : v2i;
    start.x = min(editor.select_end.x, editor.select_start.x);
    start.y = min(editor.select_end.y, editor.select_start.y);
    end.x   = max(editor.select_end.x, editor.select_start.x);
    end.y   = max(editor.select_end.y, editor.select_start.y);
    selection_size := end - start + .{1, 1};

    for x: 0..selection_size.x-1 {
        for y: 0..selection_size.y-1 {
            editor.temp_buffer[x][y] = blocks.*[start.x + x][start.y + y];
            blocks.*[start.x + x][start.y + y] = BLOCK_NONE;
        }
    }

    for src_x: 0..selection_size.x-1 {
        for src_y: 0..selection_size.y-1 {
            #if !clockwise {
                dest_x := start.x + src_y;
                dest_y := start.y + selection_size.x - 1 - src_x;
            } else {
                dest_x := start.x + selection_size.y - 1 - src_y;
                dest_y := start.y + src_x;
            }
            blocks.*[dest_x][dest_y] = editor.temp_buffer[src_x][src_y];
        }
    }

    editor.select_end.x = editor.select_start.x + selection_size.y - 1;
    editor.select_end.y = editor.select_start.y + selection_size.x - 1;
    level_mesh_needs_update = true;
}

copy_tiles :: (blocks: *type_of(Level.grid), copy_buffer: *type_of(Editor_State.copy_buffer)) {
    using context.game_state;
    start, end : v2i;
    start.x = min(editor.select_end.x, editor.select_start.x);
    start.y = min(editor.select_end.y, editor.select_start.y);
    end.x   = max(editor.select_end.x, editor.select_start.x);
    end.y   = max(editor.select_end.y, editor.select_start.y);

    selection_size := end - start;

    if selection_size.x > EDITOR_MAX_COPY_SIZE || selection_size.y > EDITOR_MAX_COPY_SIZE {
        print("ERROR: Selection too big to copy!\n");
        return;
    }

    editor.copy_size = selection_size + .{1, 1};
    for x: 0..selection_size.x {
        for y: 0..selection_size.y {
            editor.copy_buffer[x][y] = blocks.*[start.x + x][start.y + y];
        }
    }
    level_mesh_needs_update = true;
}

stamp_tiles :: (blocks: *type_of(Level.grid), copy_buffer: *type_of(Editor_State.copy_buffer)) {
    using context.game_state;
    start, end : v2i;
    start = editor.mouse_tile;
    end = start + editor.copy_size;
    
    for x: 0..editor.copy_size.x-1 {
        for y: 0..editor.copy_size.y-1 {
            blocks.*[start.x + x][start.y + y] = copy_buffer.*[x][y];
        }
    }
    level_mesh_needs_update = true;
}

paint_fill :: (level: *Level, editor: *Editor_State, start_pos: v2i, start_block: Block) {
    field := cast(*Visibility_Field)New(Visibility_Field);
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            field.*[x][y] = .{false, false};
        }
    }

    blocks: *type_of(Level.grid);
    if editor.layer == 0 {
        blocks = *level.grid;
    } else if editor.layer == 1 {
        blocks = *level.floor;
    }

    queue := cast(*Queue(v2i, 1000))New(Queue(v2i, 1000));
    queue_add(queue, start_pos);
    comparison_block := blocks.*[start_pos.x][start_pos.y];

    dirs := v2i.[.{1,0}, .{0,1}, .{-1,0}, .{0,-1}];

    while outter := queue_is_empty(queue) == false {
        coord := queue_remove(queue);
        node := *field.*[coord.x][coord.y];
        if node.visited continue;
        node.visible = true;
        node.visited = true;
        for dir: dirs {
            pos := coord + dir;
            
            if !is_in_bounds(pos, level) continue;
            new_node := field.*[pos.x][pos.y];
            if new_node.visited continue;
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
                if other_block != comparison_block && get_block_type(other_block) != .NONE {
                    continue;
                }
            }
            
            queue_add(queue, pos);
            if queue.count == queue.MAX_SIZE {
                break outter;
            }
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
    
    context.game_state.level_mesh_needs_update = true;
}