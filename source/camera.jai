Camera :: struct {
    position: Vector3;
    front: Vector3;

    yaw : float32 = -90;
    pitch : float32 = 0;

    distance: float32 = 1.5;
}

CAMERA_UP :: Vector3.{0, 1, 0};

Camera2D :: struct {
    pos: Vector2;
    zoom : float = 1;
}



camera_view_matrix :: (using camera: Camera2D) -> Matrix4 {
    view := Matrix4_Identity;
    // view = translate(view, .{WINDOW_WIDTH * 0.5, WINDOW_HEIGHT * 0.5, 0});
    mult := 1.0 / camera.zoom;
    CAMERA_SIZE := Vector2.{WINDOW_WIDTH * mult, WINDOW_HEIGHT * mult};
    view = scale(view, .{zoom, zoom, 1});
    view = translate(view, .{-pos.x, -pos.y, 0});
    view = translate(view, .{CAMERA_SIZE.x * 0.5, CAMERA_SIZE.y * 0.5, 0});
    return view;
}

get_mouse_world_pos :: (camera: Camera2D) -> Vector2 {
    pos := get_mouse_position();
    
    screenCenter := Vector2.{WINDOW_WIDTH/2, WINDOW_HEIGHT/2};
    translated := pos - screenCenter;
    scaled := translated * (1/camera.zoom);
    worldPos := camera.pos + scaled;

    return worldPos;
}

camera_zoom :: (using camera: *Camera2D, zoom_into: Vector2, zoom_factor: float32) {
    screen_half := Vector2.{ WINDOW_WIDTH * 0.5, WINDOW_HEIGHT * 0.5 };

    world_before := camera.pos + (zoom_into - screen_half) * (1.0 / camera.zoom);
    camera.zoom *= zoom_factor;
    world_after := camera.pos + (zoom_into - screen_half) * (1.0 / camera.zoom);

    camera.pos += world_before - world_after;
}

get_camera_level_bounds :: (camera: Camera2D, level: *Level) -> v2i, v2i {
    camera_bound_begin, camera_bound_end : v2i;

    zoom := 1.0 / camera.zoom;
    CAMERA_SIZE := Vector2.{WINDOW_WIDTH * zoom, WINDOW_HEIGHT * zoom};
    CAMERA_TILE_SIZE := v2i.{xx (CAMERA_SIZE.x / 64), xx (CAMERA_SIZE.y / 64)} + .{2, 2};
    camera_bound_begin.x = xx (floor(camera.pos.x / 64) - CAMERA_TILE_SIZE.x/2);
    camera_bound_begin.y = xx (floor(camera.pos.y / 64) - CAMERA_TILE_SIZE.y/2);
    camera_bound_end = camera_bound_begin + CAMERA_TILE_SIZE;

    tile_begin, tile_end : v2i;
    tile_begin.x = ifx camera_bound_begin.x < 0 then 0 else ifx camera_bound_begin.x >= level.dimensions.x then level.dimensions.x else camera_bound_begin.x;
    tile_begin.y = ifx camera_bound_begin.y < 0 then 0 else ifx camera_bound_begin.y >= level.dimensions.y then level.dimensions.y else camera_bound_begin.y;
    tile_end.x = ifx camera_bound_end.x < 0 then 0 else ifx camera_bound_end.x >= level.dimensions.x then level.dimensions.x else camera_bound_end.x;
    tile_end.y = ifx camera_bound_end.y < 0 then 0 else ifx camera_bound_end.y >= level.dimensions.y then level.dimensions.y else camera_bound_end.y;

    return tile_begin, tile_end;
}


lerp_player_camera :: (window: *SDL_Window) {
    using context.game_state;
    // camera deadzone
    if editor.enabled == false || editor.editing_level == false {
        DEADZONE_PERCENT :: 0.05;
        player_coord : Vector2;
        player_coord.x = xx (level.player_pos.x * 64);
        player_coord.y = xx (level.player_pos.y * 64);
        camera_dest := player_coord + Vector2.{32, 32};
        if abs(camera.pos.x - camera_dest.x) > WINDOW_WIDTH * DEADZONE_PERCENT {
            camera.pos.x = lerp(camera.pos.x, camera_dest.x, 0.008);
        }
        if abs(camera.pos.y - camera_dest.y) > WINDOW_HEIGHT * DEADZONE_PERCENT {
            camera.pos.y = lerp(camera.pos.y, camera_dest.y, 0.008);
        }

    } else if (SDL_GetWindowFlags(window) & SDL_WINDOW_INPUT_FOCUS) != 0 {
        DEBUG_CAMERA_SPEED := 12 * (1.0 / camera.zoom);
        DEADZONE_PERCENT :: 0.01;

        mouse_pos := get_mouse_position();
        if mouse_pos.x >= WINDOW_WIDTH - WINDOW_WIDTH*DEADZONE_PERCENT {
            camera.pos.x += DEBUG_CAMERA_SPEED;
        } else if mouse_pos.x < WINDOW_WIDTH*DEADZONE_PERCENT {
            camera.pos.x -= DEBUG_CAMERA_SPEED;
        }
        if mouse_pos.y >= WINDOW_HEIGHT - WINDOW_HEIGHT*DEADZONE_PERCENT {
            camera.pos.y += DEBUG_CAMERA_SPEED;
        } else if mouse_pos.y < WINDOW_HEIGHT*DEADZONE_PERCENT {
            camera.pos.y -= DEBUG_CAMERA_SPEED;
        }
    }
}