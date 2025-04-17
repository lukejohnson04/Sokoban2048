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
    view = translate(view, Vector3.{-pos.x, -pos.y, 0});
    return view;
}

get_mouse_world_pos :: (camera: Camera2D) -> Vector2 {
    pos := get_mouse_position();
    
    screenCenter := Vector2.{WINDOW_WIDTH/2, WINDOW_HEIGHT/2};

    translated := pos - screenCenter;
    scaled := translated * (1/camera.zoom);
    worldPos := camera.pos + scaled + screenCenter;

    return worldPos;
}


get_camera_level_bounds :: (camera: Camera2D, level: *Level) -> v2i, v2i {
    camera_bound_begin := v2i.{xx (floor(camera.pos.x / 64) - 1), xx (floor(camera.pos.y / 64) - 1)};
    camera_bound_end := v2i.{xx (ceil(WINDOW_WIDTH / 64) + 2), xx (ceil(WINDOW_HEIGHT / 64) + 2)};
    camera_bound_end += camera_bound_begin;

    tile_begin, tile_end : v2i;
    tile_begin.x = ifx camera_bound_begin.x < 0 then 0 else ifx camera_bound_begin.x >= level.dimensions.x then level.dimensions.x else camera_bound_begin.x;
    tile_begin.y = ifx camera_bound_begin.y < 0 then 0 else ifx camera_bound_begin.y >= level.dimensions.y then level.dimensions.y else camera_bound_begin.y;
    tile_end.x = ifx camera_bound_end.x < 0 then 0 else ifx camera_bound_end.x >= level.dimensions.x then level.dimensions.x else camera_bound_end.x;
    tile_end.y = ifx camera_bound_end.y < 0 then 0 else ifx camera_bound_end.y >= level.dimensions.y then level.dimensions.y else camera_bound_end.y;

    return tile_begin, tile_end;
}