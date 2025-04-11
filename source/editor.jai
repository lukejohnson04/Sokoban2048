Editor_State :: struct {
    selected_block := 0;
    selected_block_pos : Vector2;

    editing_level := false;
}

draw_editor :: (using game_state: *Game_State) {
    draw_list := ImGui.GetWindowDrawList();
    window_pos := ImGui.GetCursorScreenPos();

    tile_scale :: 2;
    tile_size :: 16 * tile_scale;

    source := ImGui.ImVec2.{xx sprites_imgui.width, xx sprites_imgui.height};
    dest := ImGui.ImVec2.{xx (sprites_imgui.width * tile_scale), xx (sprites_imgui.height * tile_scale)};

    if editor.editing_level == false {
        if ImGui.Button("Edit Level") {
            editor.editing_level = true;
        }
    } else {
        if ImGui.Button("Save Level") {

        }
        if ImGui.Button("Play Level") {

        }

        img_pos := window_pos + .{0, 48};

        draw_list.AddImage(draw_list, cast,no_check(*void)(sprites.id), img_pos, img_pos + dest);

        // Selected tile
        focused := ImGui.IsWindowFocused();
        mouse_x, mouse_y := get_mouse_position();

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
                    print("Focused\n");
                    if ImGui.IsMouseDown(ImGui.MouseButton.Left) {
                        print("Mouse down\n");
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
                } else {
                    print("Not focused\n");
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
