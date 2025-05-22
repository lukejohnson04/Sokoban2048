Light :: struct {
    pos: Vector2;
    radius: float;

    shadow_buffer: Framebuffer;
    light_buffer: Framebuffer;
    initialized := false;
}

init_light :: (light: *Light, pos: Vector2, radius: float) {
    light.pos = pos;
    light.radius = radius;

    if light.initialized == false {
        light.initialized = true;
        size := light.radius * 2;
        light.shadow_buffer = create_framebuffer(xx size, xx size);
        light.light_buffer = create_framebuffer(xx size, xx size);
    }    
}

// Returns every point to draw triangle strips of
compute_light_points :: (light: Light, light_mesh: *[..] Vector2) {
    using context.game_state;
    // Get all blocks within radius
    corners: [..] Vector2;
    corners.allocator = temp;

    light_top_left := light.pos - .{light.radius, light.radius};
    light_bot_right := light.pos + .{light.radius, light.radius};
    min_x, min_y, max_x, max_y := block_range(light_top_left, light_bot_right, *level);
    for x: min_x..max_x {
        for y: min_y..max_y {
            if level.grid[x][y].type == .NONE continue;
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

    top_left := light.pos - .{light.radius, light.radius};
    array_add(*corners, top_left);
    array_add(*corners, top_left + .{light.radius * 2, 0});
    array_add(*corners, top_left + .{0, light.radius * 2});
    array_add(*corners, top_left + .{light.radius * 2, light.radius * 2});

    // Go through all corners and raycast
    for corner: corners {
        col := get_collision(light.pos, corner, *level);

        if col.collides == false {
            array_add(light_mesh, corner);
            continue;
        }
        defer array_add(light_mesh, col.collision_point);
        
        // Now we check for collision beyond
        v := corner - light.pos;
        v = normalize(v);
        tx := ifx (abs(v.x) > 0) then ((light.radius) / abs(v.x)) else 1000000000;
        ty := ifx (abs(v.y) > 0) then ((light.radius) / abs(v.y)) else 1000000000;
        t := min(tx, ty);

        left_pos := light.pos + rotate(v, 0.005) * t;
        right_pos := light.pos + rotate(v, -0.005) * t;

        // if it goes through a block just discard
        // col_test := col.collision_point + v * 0.001;
        // if level.grid[xx (col_test.x / 64.0)][xx (col_test.y / 64.0)].type != .NONE {
        //     continue;
        // }

        for past_pos: Vector2.[left_pos, right_pos] {
            past := get_collision(light.pos, past_pos, *level);

            if past.collides {
                if past.collision_point == col.collision_point {
                    continue;
                }
                array_add(light_mesh, past.collision_point);
            } else {
                array_add(light_mesh, past_pos);
            }
        }
    }

    for light_mesh.* {
        found : bool;
        for second: it_index+1..light_mesh.count-1 {
            if it == light_mesh.*[second] {
                found = true;
                break;
            }
        }
        if found {
            remove it;
        }
    }
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

angle_sort_clockwise :: (a: Vector2, b: Vector2) -> float {
    ppos := Vector2.{xx context.game_state.level.player_pos.x, xx context.game_state.level.player_pos.y};
    ppos += .{0.5, 0.5};
    ppos *= 64;
    first := a - ppos;
    second := b - ppos;
    angle_a := atan2(first.y, first.x);
    angle_b := atan2(second.y, second.x);
    
    angle := angle_a - angle_b;
    return angle;
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

    for x: min_x..max_x {
        for y: min_y..max_y {
            block := level.grid[x][y];
            if block.type == .NONE continue;
            segments : [4] Segment;

            p1 := Vector2.{xx x, xx y};
            p1 *= 64;

            segments[0] =   .{p1, p1 + .{64, 0}};
            segments[1] =   .{p1, p1 + .{0, 64}};
            segments[2] =   .{p1 + .{0, 64}, p1 + .{64, 64}};
            segments[3] =   .{p1 + .{64, 0}, p1 + .{64, 64}};

            for seg: segments {
                col := get_intersection(from, to, seg.p1, seg.p2);
                if (col.collides) {
                    dist := distance(from, col.collision_point);
                    if (res.collides == false || dist <= closest) {
                        closest = dist;
                        res = col;
                    }
                }
            }
        }
    }

    return res;
}
