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
    // view = scale(view, .{zoom, zoom, 1});
    // view = translate(view, Vector3.{-WINDOW_WIDTH * 0.5, -WINDOW_HEIGHT * 0.5, 0});
    view = translate(view, Vector3.{-pos.x, -pos.y, 0});
    return view;
}


// glm::mat4 CalculateCameraViewMatrix(Camera *camera)
// {
//     glm::mat4 view = glm::mat4(1.0);
//     view = glm::translate(
//         view,
//         glm::vec3(WINDOW_WIDTH * 0.5f, WINDOW_HEIGHT * 0.5f, 0.0f));

//     view = glm::scale(
//         view,
//         glm::vec3(camera->zoom, camera->zoom, 1.0f));

//     view = glm::translate(
//         view,
//         glm::vec3(-WINDOW_WIDTH * 0.5f, -WINDOW_HEIGHT * 0.5f, 0.0f));
    
//     view = glm::translate(
//         view,
//         glm::vec3(-camera->pos.x, -camera->pos.y, 0.0f));
    
//     return view;
// }

// v2 GetMouseWorldPos(Camera *camera)
// {
//     v2i mPos = GetMousePosition();
//     v2 pos = (v2)mPos;
//     v2 screenCenter = {WINDOW_WIDTH/2.f, WINDOW_HEIGHT/2.f};

//     v2 translated = pos - screenCenter;
//     v2 scaled = translated * (1.f/camera->zoom);
//     v2 worldPos = camera->pos + scaled + screenCenter;
//     return worldPos;
// }
