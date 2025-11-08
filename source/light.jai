Light :: struct {
    pos: Vector2;
    radius: float;
    color: Vector4;

    shadow_buffer: Framebuffer;
    light_buffer: Framebuffer;
    mesh: [..] Vertex(.UV_DISABLED);

    initialized := false;
}

init_light :: (light: *Light, pos: Vector2, radius: float, color: Vector4) {
    light.pos = pos;
    light.radius = radius;
    light.color = color;
    light.mesh.count = 0;

    if light.initialized == false {
        light.initialized = true;
        size := light.radius * 2;
        light.shadow_buffer = create_framebuffer(xx size, xx size);
        light.light_buffer = create_framebuffer(xx size, xx size);
    }    
}

get_light_rect :: (light: Light) -> Rect {
    rect: Rect;
    rect.x = light.pos.x - light.radius;
    rect.y = light.pos.y - light.radius;
    rect.w = light.radius * 2;
    rect.h = light.radius * 2;
    return rect;
}

// Returns every point to draw triangle strips of
compute_light_points :: (light: *Light) {
    using context.game_state;
    // Get all blocks within radius
    corners: [..] Vector2;
    corners.allocator = temp;

    light_top_left := light.pos - .{light.radius, light.radius};
    light_bot_right := light.pos + .{light.radius, light.radius};
    min_x, min_y, max_x, max_y := block_range(light_top_left, light_bot_right, *level);
    for x: min_x..max_x {
        for y: min_y..max_y {
            if block_blocks_light(level.grid[x][y]) == false continue;
            if x == xx floor(light.pos.x / 64.0) && y == xx floor(light.pos.y / 64.0) {
                continue;
            }
            // Don't raycast to corners that are part of the light block itself
            for corner: 0..3 {
                pos := Vector2.{xx x, xx y};
                pos.x += corner % 2;
                pos.y += corner / 2;
                pos *= 64;

                // We add 1 to the radius to get everything within the box, then we can crop it out later
                if distance(pos, light.pos) <= light.radius + 64 {
                    array_add(*corners, pos);
                }
            }
        }
    }


    mesh_add :: (thing: Vector2) #expand {
        array_add(*light.mesh, .{thing.x, thing.y, 0});
    }

    top_left := light.pos - .{light.radius, light.radius};
    array_add(*corners, top_left);
    array_add(*corners, top_left + .{light.radius * 2, 0});
    array_add(*corners, top_left + .{0, light.radius * 2});
    array_add(*corners, top_left + .{light.radius * 2, light.radius * 2});

    light.mesh.count = 0;
    mesh_add(light.pos);
    
    // Go through all corners and raycast
    for corner: corners {
        col := get_collision(light.pos, corner, *level);

        if col.collides == false {
            mesh_add(corner);
            continue;
        }
        defer mesh_add(col.collision_point);
        
        // Now we check for collision beyond
        v := corner - light.pos;
        v = normalize(v);
        tx := ifx (abs(v.x) > 0) then ((light.radius) / abs(v.x)) else 1000000000;
        ty := ifx (abs(v.y) > 0) then ((light.radius) / abs(v.y)) else 1000000000;
        t := min(tx, ty);

        left_pos := light.pos + rotate(v, 0.005) * t;
        right_pos := light.pos + rotate(v, -0.005) * t;

        // if it goes through a block just discard
        // Note: If there's a lighting bug in the future it might be this code. I randomly
        // decided to uncomment it and I am hoping it works. #YOLO
        col_test := col.collision_point + v * 0.001;
        if level.grid[xx (col_test.x / 64.0)][xx (col_test.y / 64.0)].id != 0 {
            continue;
        }

        for past_pos: Vector2.[left_pos, right_pos] {
            past := get_collision(light.pos, past_pos, *level);

            if past.collides {
                if past.collision_point == col.collision_point {
                    continue;
                }
                mesh_add(past.collision_point);
            } else {
                mesh_add(past_pos);
            }
        }
    }


    for light.mesh {
        found : bool;
        for second: it_index+1..light.mesh.count-1 {
            if it.x == light.mesh[second].x && it.y == light.mesh[second].y {
                found = true;
                break;
            }
        }
        if found {
            remove it;
        }
    }

    for *vert: light.mesh {
        ppos := light.pos;
        a := Vector2.{vert.x, vert.y};
        pos := a - ppos;
        vert.z = atan2(pos.y, pos.x);
    }
    // Quick sort by z element
    sort_view : [] Vertex(.UV_DISABLED);
    sort_view.count = light.mesh.count - 1;
    sort_view.data = light.mesh.data + 1;
    Sort.quick_sort(sort_view, angle_sort_clockwise);

    for *vert: light.mesh vert.z = 0;
}



Intersection :: struct {
    collision_point: Vector2;
    collides: bool;
};

determinant :: (a: Vector2, b: Vector2) -> float {
    return a.x * b.y - a.y * b.x;
}

get_intersection :: (ray_start: Vector2, ray_end: Vector2, seg_start: Vector2, seg_end: Vector2) -> Intersection {
    result: Intersection;

    A := ray_start;
    B := ray_end;
    C := seg_start;
    D := seg_end;

    col_1 := B - A;
    col_2 := -(D - C);

    det := determinant(col_1, col_2);

    if (det == 0) // Ray and segment are parallel
        return result;

    // A + t(B - A) = C + u(D - C)
    // t(B - A) - u(D - C) = C - A;
    w := C - A;

    t := determinant(w, col_2) / det;
    u := determinant(col_1, w) / det;

    if t >= 0 && t <= 1 && u >= 0 && u <= 1 {
        // Collision detected, calculate collision point
        result.collides = true;
        result.collision_point.x = ray_start.x + t * col_1.x;
        result.collision_point.y = ray_start.y + t * col_1.y;
    }

    return result;
}

angle_sort_clockwise :: (va: Vertex(.UV_DISABLED), vb: Vertex(.UV_DISABLED)) -> float {
    return va.z - vb.z;
}

block_range :: (from: Vector2, to: Vector2, level: *Level) -> min_x: int, min_y: int, max_x: int, max_y: int {
    min_x :int= xx (min(from.x, to.x)/64.0);
    max_x :int= xx (max(from.x, to.x)/64.0);
    min_y :int= xx (min(from.y, to.y)/64.0);
    max_y :int= xx (max(from.y, to.y)/64.0);

    min_x = max(min_x - 1, 0);
    min_y = max(min_y - 1, 0);
    max_x = min(max_x + 1, level.dimensions.x);
    max_y = min(max_y + 1, level.dimensions.y);

    return min_x, min_y, max_x, max_y;
}

get_collision :: (from: Vector2, to: Vector2, level: *Level) -> Intersection {
    res: Intersection;
    closest := -1.0;

    Segment :: struct {
        p1, p2: Vector2;
    } 

    // Range of blocks
    min_x, min_y, max_x, max_y := block_range(from, to, level);

    from_floored := v2i.{xx floor(from.x / 64.0), xx floor(from.y / 64.0)};

    segments : [4] Segment;
    for x: min_x..max_x {
        for y: min_y..max_y {
            block := level.grid[x][y];
            if block_blocks_light(block) == false continue;
            if x == from_floored.x && y == from_floored.y {
                continue;
            }

            p1 := Vector2.{xx x, xx y};
            p1 *= 64;
            
            segments[0] =   .{p1, p1 + .{64, 0}};
            segments[1] =   .{p1, p1 + .{0, 64}};
            segments[2] =   .{p1 + .{0, 64}, p1 + .{64, 64}};
            segments[3] =   .{p1 + .{64, 0}, p1 + .{64, 64}};

            for seg: segments {
                col := get_intersection(from, to, seg.p1, seg.p2);
                if col.collides {
                    dist := distance(from, col.collision_point);
                    if res.collides == false || dist <= closest {
                        closest = dist;
                        res = col;
                    }
                }
            }
        }
    }

    return res;
}


draw_lighting :: () {
    using context.game_state;
    /*    
        Our goal is to take the full screen resolution output render of the entire world.
        Then, we want to draw a low brightness version of that render. When drawing this
        version, we want to use a mask layer as well. For all values that are white in the
        mask, we want to draw the world layer at full brightness. Otherwise, we want to use
        a dim brightness.

        To do this, we draw the entire world. We also pass the mask and the uv of the mask
        to the shader. For all the pixels within the mask portion, we multiply it with the uv.
        Otherwise, the default value is the dim light, which is a uniform.

        So in short, we have a uniform for the texture, a uniform for the mask, a uv for the
        texture, a uv for the mask, and finally a uniform for the dim light.

        To generate the light mask texture, we first start with the full texture of the shadow
        layer. Then, we go onto a new framebuffer texture, and render the spotlight with the
        shadow layer as a mask.
    */
    // Lighting
    glDisable(GL_DEPTH_TEST);
    set_framebuffer(*world_mesh.light_buffer);
    clear_framebuffer(1, 1, 1, 0);
    view := camera_view_matrix(camera);
    projection := orthographic_projection_matrix(0, WINDOW_WIDTH, WINDOW_HEIGHT, 0, -1, 1);

    for index: 0..light_count-1 {
        light := *lights[index];

        set_framebuffer(*light.shadow_buffer);
        clear_framebuffer(0, 0, 0, 0);

        fb_projection := orthographic_projection_matrix(0, xx light.shadow_buffer.w, xx light.shadow_buffer.h, 0, -1, 1);

        uniform(color_shader, "projection", *fb_projection);
        light_color := Vector4.{1, 1, 1, 1};
        uniform(color_shader, "color", light_color);
        uniform(color_shader, "view", Matrix4_Identity);

        glBindVertexArray(intermediate_vao);
        glBindBuffer(GL_ARRAY_BUFFER, intermediate_vbo);
        glBufferData(GL_ARRAY_BUFFER, size_of(Vertex(.UV_DISABLED)) * light.mesh.count, light.mesh.data, GL_STATIC_DRAW);
        // position
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * size_of(float32), null);
        glEnableVertexAttribArray(0);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glDrawArrays(GL_TRIANGLE_FAN, 0, xx light.mesh.count);

        uniform(mask_shader, "projection", fb_projection);
        uniform(mask_shader, "view", Matrix4_Identity);
        uniform(mask_shader, "dim_level", 0);
        uniform(mask_shader, "blend_alpha", 1);
        uniform(mask_shader, "blend_rgb", 1);

        set_framebuffer(*light.light_buffer);
        clear_framebuffer(0, 0, 0, 0);
        sh_rect := Rect.{0, 0, xx light.light_buffer.tex.width, xx light.light_buffer.tex.height};
        sh_dest := Rect.{0, 0, xx light.light_buffer.tex.width, xx light.light_buffer.tex.height};
        draw_mask_textures(sh_rect, sh_dest, sh_rect, sh_dest, *light.shadow_buffer.tex, *spotlight);


        uniform(texture_shader, "view", view);
        uniform(texture_shader, "color_pass", light.color);
        set_framebuffer(*world_mesh.light_buffer);
        light_src := buffer_rect(light.light_buffer);
        light_rect := get_light_rect(light);
        draw_texture(light_src, light_rect, light.light_buffer.tex);
        uniform(texture_shader, "color_pass", Vector4.{1,1,1,1});
    }

    set_framebuffer(null);
    clear_framebuffer(0,0,0,1);
    final_buffer_src := buffer_rect(world_mesh.light_buffer);
    final_buffer_dest := final_buffer_src;
    screen_source := buffer_rect(floor_buffer);
    screen_dest := final_buffer_dest;
    flip_rect(*screen_dest);
    flip_rect(*final_buffer_dest);
    dim_level := 0.5;
    uniform(mask_shader, "projection", projection);
    uniform(mask_shader, "dim_level", dim_level);
    uniform(mask_shader, "blend_alpha", 0);
    uniform(mask_shader, "view", Matrix4_Identity);
    uniform(mask_shader, "blend_rgb", 0);

    draw_mask_textures(screen_source, screen_dest, final_buffer_src, final_buffer_dest, *floor_buffer.tex, *world_mesh.light_buffer.tex);

    uniform(texture_shader, "view", Matrix4_Identity);
    uniform(texture_shader, "colormult", 1.0);
    bind_texture(world_buffer.tex);
    draw_texture(screen_source, screen_dest, world_buffer.tex);
    uniform(texture_shader, "colormult", 1.0);
}