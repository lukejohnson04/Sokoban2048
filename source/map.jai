
Map_State :: struct {
    map_buffer : Framebuffer;
    map_display_buffer : Framebuffer;

    display_map := false;
    display_minimap := false;
    map_camera := Camera2D.{.{WORLD_ROOM_WIDTH*SCREEN_TILE_WIDTH*0.5, WORLD_ROOM_HEIGHT*SCREEN_TILE_HEIGHT*0.5}, 1};
    minimap_camera := Camera2D.{.{WORLD_ROOM_WIDTH*SCREEN_TILE_WIDTH*0.5, WORLD_ROOM_HEIGHT*SCREEN_TILE_HEIGHT*0.5}, 1};

    mouse_drag_start_pos: Vector2;
    camera_drag_start_pos: Vector2;

    view_state := Map_View_State.IDLE;
    Map_View_State :: enum {
        IDLE;
        DRAGGING;
    }
}

map_init :: (using map: *Map_State) {
    map_buffer = create_framebuffer(WORLD_ROOM_WIDTH*SCREEN_TILE_WIDTH, WORLD_ROOM_HEIGHT*SCREEN_TILE_HEIGHT);
    map_display_buffer = create_framebuffer(WINDOW_WIDTH, WINDOW_HEIGHT);
}

render_map :: () {
    using context.game_state;
    using map;

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

update_map :: (input: *Input_State) {
    using context.game_state;
    using map;

    regular_map :: () #expand {
        px, py := get_player_room();
        map_camera.pos = .{xx SCREEN_TILE_WIDTH * (px + 0.5), xx SCREEN_TILE_HEIGHT * (py + 0.5)};
        map_camera.zoom = 1;
        print("Display regular map\n");
    }

    minimap :: () #expand {
        px, py := get_player_room();
        minimap_camera.pos = .{xx SCREEN_TILE_WIDTH * (px + 0.5), xx SCREEN_TILE_HEIGHT * (py + 0.5)};
        minimap_camera.zoom = 4;
    }

    if input.just_pressed[SDL_SCANCODE_M] {
        display_map = !display_map;
        if display_map {
            if display_minimap {
                minimap();
            } else {
                regular_map();
            }
        }
    }
    if input.just_pressed[SDL_SCANCODE_N] {
        display_minimap = !display_minimap;
        if display_map {
            if display_minimap {
                minimap();
            } else {
                regular_map();
            }
        }
    }

    // camera controls
    if display_minimap {
        minimap();
    } else if display_map {
        if input.mouse_wheel {
            zoom_factor := ifx input.mouse_wheel > 0 then 2.0 else 0.5;
            zoom_pos := get_mouse_position();
            zoom_pos -= .{100, 100};
            camera_zoom(*map_camera, get_mouse_position(), zoom_factor, 512, 512);
        }

        if view_state == .IDLE {
            if input.mwheel_just_pressed {
                view_state = .DRAGGING;
                mouse_drag_start_pos = get_mouse_position();
                camera_drag_start_pos = map_camera.pos;
            }
        } else {
            map_camera.pos = camera_drag_start_pos + (mouse_drag_start_pos - get_mouse_position());
            if input.mwheel_just_released {
                view_state = .IDLE;
            }
        }
    }
}

get_player_room :: () -> int, int {
    using context.game_state;
    player_room_x := level.player_pos.x / SCREEN_TILE_WIDTH;
    player_room_y := level.player_pos.y / SCREEN_TILE_HEIGHT;
    return player_room_x, player_room_y;
}