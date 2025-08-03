
render_map :: () {
    using context.game_state;

    set_framebuffer(*map_buffer);
    clear_framebuffer(0.1, 0.1, 0.1, 1);
    use_shader(color_shader);
    map_proj := orthographic_projection_matrix(0, xx map_buffer.w, xx map_buffer.h, 0, -1, 1);
    shader_uniform(color_shader, "view", Matrix4_Identity);
    shader_uniform(color_shader, "projection", map_proj);

    shader_uniform(color_shader, "color", Vector4.{1, 0, 0, 1});
    player_room_x := level.player_pos.x / SCREEN_TILE_WIDTH;
    player_room_y := level.player_pos.y / SCREEN_TILE_HEIGHT;

    for x: 0..WORLD_ROOM_WIDTH-1 {
        for y: 0..WORLD_ROOM_HEIGHT-1 {
            if stats.visited_room[x][y] {
                rect := Rect.{xx ((x * SCREEN_TILE_WIDTH)), xx ((y * SCREEN_TILE_HEIGHT)), SCREEN_TILE_WIDTH, SCREEN_TILE_HEIGHT};
                shader_uniform(color_shader, "color", Vector4.{0.3, 0.3, 0.3, 1});
                draw_rect(CoordRect(rect));

                // Draw each tile
                shader_uniform(color_shader, "color", Vector4.{0.0, 0.0, 0.0, 1});
                for ix: 0..SCREEN_TILE_WIDTH-1 {
                    for iy: 0..SCREEN_TILE_HEIGHT-1 {
                        coord_x := ix + x * SCREEN_TILE_WIDTH;
                        coord_y := iy + y * SCREEN_TILE_HEIGHT;
                        if field[coord_x][coord_y].visible == false || get_block_type(level.grid[coord_x][coord_y]) == .WALL {
                            pixel_rect := Rect.{rect.x + ix, rect.y + iy, 1, 1};
                            draw_rect(CoordRect(pixel_rect));
                        }
                    }
                }

                if player_room_x == x && player_room_y == y {
                    shader_uniform(color_shader, "color", Vector4.{1, 0, 0, 1});
                } else {
                    shader_uniform(color_shader, "color", Vector4.{0.1, 0.1, 0.15, 1});
                }
                draw_rect_with_outline(CoordRect(rect), 1);
            }
        }
    }
    set_framebuffer(null);

    projection := orthographic_projection_matrix(0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, -1, 1);
    shader_uniform(color_shader, "view", camera_view_matrix(camera));
    shader_uniform(color_shader, "projection", projection);
}


get_player_room :: () -> int, int {
    using context.game_state;
    player_room_x := level.player_pos.x / SCREEN_TILE_WIDTH;
    player_room_y := level.player_pos.y / SCREEN_TILE_HEIGHT;
    return player_room_x, player_room_y;
}