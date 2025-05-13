Light :: struct {
    pos: Vector2;
    radius: float;
}

Light_Mesh_Node :: struct {
    #as using pos: Vector2;
    extension: bool;
}

// Returns every point to draw triangle strips of
do_lighting :: (light: Light) -> [..] Light_Mesh_Node {
    using context.game_state;
    // Get all blocks within radius
    corners: [..] Light_Mesh_Node;
    corners.allocator = temp;

    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            if level.grid[x][y].type == .NONE continue;
            for corner: 0..3 {
                pos := Vector2.{xx x, xx y};
                pos.x += corner % 2;
                pos.y += corner / 2;
                pos *= 64;

                // We add 1 to the radius to get everything within the box, then we can crop it out later
                if distance(pos, light.pos) <= light.radius + 128 {
                    array_add(*corners, .{pos, false});
                }
            }
        }
    }

    top_left := light.pos - .{light.radius, light.radius};
    array_add(*corners, .{top_left, false});
    array_add(*corners, .{top_left + .{light.radius * 2, 0}, false});
    array_add(*corners, .{top_left + .{0, light.radius * 2}, false});
    array_add(*corners, .{top_left + .{light.radius * 2, light.radius * 2}, false});

    results : [..] Light_Mesh_Node;
    results.allocator = temp;

    // Go through all corners and raycast
    for corner: corners {
        col := get_collision(light.pos, corner, *level);

        if col.collides == false {
            array_add(*results, .{corner, true});
            continue;
        }
        if col.collision_point != corner {
            if it_index >= corners.count - 4 {
                array_add(*results, .{col.collision_point, true});
            }
            continue;
        }
        if it_index >= corners.count - 4 {
            continue;
        }
        defer array_add(*results, .{col.collision_point, false});
        
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
                array_add(*results, .{past.collision_point, true});
            } else {
                array_add(*results, .{past_pos, true});
            }
        }
    }

    for results {
        found : bool;
        for second: it_index+1..results.count-1 {
            if it.pos == results[second].pos && it.extension == results[second].extension {
                found = true;
                break;
            }
        }
        if found {
            remove it;
        }
    }

    return results;
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


get_collision :: (from: Vector2, to: Vector2, level: *Level) -> Intersection {
    res: Intersection;
    closest := -1.0;

    Segment :: struct {
        p1, p2: Vector2;
    } 

    // Range of blocks
    min_x :int= xx (min(from.x, to.x)/64.0);
    max_x :int= xx (max(from.x, to.x)/64.0);
    min_y :int= xx (min(from.y, to.y)/64.0);
    max_y :int= xx (max(from.y, to.y)/64.0);

    min_x -= 1;
    min_y -= 1;
    max_x += 1;
    max_y += 1;

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
