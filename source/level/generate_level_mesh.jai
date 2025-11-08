
Level_Mesh :: struct {
    floor: Mesh;
    tiles: Mesh;
    goal: Mesh;
    gold: Mesh;
    timer: Mesh;

    // Overall buffer for combined render of every light mask 
    light_buffer: Framebuffer;
}


// To tween movement of blocks we create two meshes
// The first mesh is of all the tiles that haven't changed since the last move
// The second mesh is all the tiles at the end of the movement animation (which is exactly what we have now)
// Then, we just iterate through the move delta, pass proper uniforms, and draw each one at the tweened location 

level_mesh_init :: (using mesh: *Level_Mesh) {
    mesh_init(*mesh.floor);
    mesh_init(*mesh.tiles);
    mesh_init(*mesh.gold);
    mesh_init(*mesh.goal);
    mesh_init(*mesh.timer);
}

level_mesh_free :: (using mesh: *Level_Mesh) {
    mesh_free(*mesh.floor);
    mesh_free(*mesh.tiles);
    mesh_free(*mesh.gold);
    mesh_free(*mesh.goal);
    mesh_free(*mesh.timer);
}

level_mesh_generate :: (using mesh: *Level_Mesh) {
    mesh_generate(*mesh.floor);
    mesh_generate(*mesh.tiles);
    mesh_generate(*mesh.gold);
    mesh_generate(*mesh.goal);
    mesh_generate(*mesh.timer);
}


generate_screen_mesh :: () {

}

CHARACTER_DRAW_OFFSET :: 16;

generate_screen_mesh :: (screen_pos: v2i, blocks: *type_of(Level.grid), mesh: *Level_Mesh, mesh_layer: *Mesh, generate_lights: bool, generate_tween: bool) {
    using context.game_state;
    start_x := SCREEN_TILE_WIDTH * screen_pos.x;
    start_y := SCREEN_TILE_HEIGHT * screen_pos.y;
    for x: start_x..(SCREEN_TILE_WIDTH + start_x - 1) {
        for y: start_y..(SCREEN_TILE_HEIGHT + start_y - 1) {
            block := blocks.*[x][y];
            if block.flags & .TIMER {
                if timer_is_active(block) == false {
                    continue;
                }
            }
            // Empty block
            is_player := level.player_pos.x == xx x && level.player_pos.y == xx y;
            if block.id == 0 && is_player == false continue;
            if generate_lights {
                if is_player || block_is_light_source(block) {
                    light := *lights[light_count];

                    light_pos := (Vector2.{xx x, xx y} + Vector2.{0.5, 0.5}) * 64;
                    color := ifx is_player then Vector4.{1,1,1,1} else Vector4.{1,1,0,1};
                    init_light(light, light_pos, 5.5 * 64, color);

                    compute_light_points(light);
                    
                    array_add(*light.mesh, light.mesh[1]);
                    for *corner: light.mesh {
                        corner.x -= light.pos.x;
                        corner.y -= light.pos.y;
                        corner.x += light.radius;
                        corner.y += light.radius;
                    }

                    light_count += 1;
                }
            }

            empty_block :: Block.{};
            if block == empty_block continue;

            if generate_tween {
                if turn_memory.curr.prev {
                    assert(turn_memory.curr.prev.type == .MOVE);
                    delta_data := turn_memory.curr.prev.move_delta;
                    tween_block := false;
                    if delta_data.count > 0 {
                        // print("Blocks be moving!\n");
                        for 0..delta_data.count-1 {
                            if delta_data.deltas[it].coord == .{x, y} {
                                tween_block = true;
                                // print("Tween at coord: %, %\n", x, y);
                                break;
                            }
                        }
                    }
                    if tween_block continue y;
                }
            }

            if editor.editing_level == false && field[x][y].visible == false {
                // continue;
            }

            // Section for changing how the rendering based on the type of the block
            source, dest: Rect;
            source = get_block_source(block);
            dest = Rect.{xx (x * 64), xx (y * 64), 64, 64};
            if get_block_type(block) == .NUMBERED {
                dest.h += 10 * 4;
            }
            if block.id == 128 {
                dest.y += CHARACTER_DRAW_OFFSET;
            }

            u1, u2, v1, v2 : float32;
            u1 = source.x / sprites.width;
            u2 = (source.x + source.w) / sprites.width;
            v1 = source.y / sprites.height;
            v2 = (source.y + source.h) / sprites.height;

            if block.flags & .FLIPPED_X {
                dest.x += dest.w;
                dest.w *= -1;
            }
            if block.flags & .FLIPPED_Y {
                dest.y += dest.h;
                dest.h *= -1;
            }

            z_pos := -(1.0 - (dest.y / (512 * 64.0)));
            vertices := Vertex.[
                .{dest.x,           dest.y,         z_pos, u1, v1},
                .{dest.x+dest.w,    dest.y,         z_pos, u2, v1},
                .{dest.x+dest.w,    dest.y+dest.h,  z_pos, u2, v2},

                .{dest.x,           dest.y,         z_pos, u1, v1},
                .{dest.x,           dest.y+dest.h,  z_pos, u1, v2},
                .{dest.x+dest.w,    dest.y+dest.h,  z_pos, u2, v2},
            ];

            for *vertices {
                if block_is_goal(block) {
                    if block.flags & .GOAL {
                        array_add(*mesh.goal.vertices, it);
                    } else {
                        array_add(*mesh.gold.vertices, it);
                    }
                    continue;
                }
                array_add(*mesh_layer.vertices, it);
            }
        }
    }
}

generate_level_mesh :: (just_current_screen := false) {
    using context.game_state;

    level_mesh_free(*world_mesh);
    level_mesh_free(*tween_mesh);

    light_count = 0;
    
    generate_mesh_of_layer :: (blocks: *type_of(Level.grid), mesh: *Level_Mesh, mesh_layer: *Mesh, generate_lights: bool, tween: bool) #expand {
        if just_current_screen == false {
            for x: 0..(Level.MAX_WIDTH / SCREEN_TILE_WIDTH)-1 {
                for y: 0..(Level.MAX_HEIGHT / SCREEN_TILE_HEIGHT)-1 {
                    generate_screen_mesh(.{x, y}, blocks, mesh, mesh_layer, generate_lights, tween);
                }
            }
        } else {
            current_screen := get_current_screen_coord(*context.game_state.level);
            generate_screen_mesh(current_screen, blocks, mesh, mesh_layer, generate_lights, tween);
        }
    }

    generate_tween := turn_memory.curr.prev && turn_memory.curr.prev.type == .MOVE;
    generate_mesh_of_layer(*level.floor, *world_mesh, *world_mesh.floor, false, false);
    generate_mesh_of_layer(*level.grid, *world_mesh, *world_mesh.tiles, false, false);
    if turn_memory.curr.prev {
        generate_mesh_of_layer(*level.floor, *tween_mesh, *tween_mesh.floor, false, generate_tween);
        generate_mesh_of_layer(*level.grid, *tween_mesh, *tween_mesh.tiles, false, generate_tween);
    }

    // Note to self: the main performance issue I have identified so far is the light point compute time in the
    // "compute_light_points" procedure. Profile this procedure further. It might be faster to do all the
    // compute_light_point calls in one big batch because right now it could be a bit random when it does the calls.
    level_mesh_generate(*world_mesh);
    level_mesh_generate(*tween_mesh);
    if world_mesh.light_buffer.id == 0 {
        world_mesh.light_buffer = create_framebuffer(WINDOW_WIDTH, WINDOW_HEIGHT);
    }

    render_map();
}

generate_portal_pairs :: () {
    using context.game_state;

    // Generate portal list so we don't have to search every time for corresponding portals
    portal_list.count = 0;
    for x: 0..level.dimensions.x-1 {
        for y: 0..level.dimensions.y-1 {
            tile := level.grid[x][y];
            if get_block_type(tile) != .PORTAL {
                continue;
            }
            for portal_list {
                if it == .{x, y}
                    continue y;
            }

            corresponding_portal := get_matching_portal(tile, .{x,  y});
           
            array_add(*portal_list, .{x, y});
            array_add(*portal_list, corresponding_portal);
        }
    }
    
    portal_id := 1;
    for 0..portal_list.count-1 {
        p1 := portal_list[it];
        p2 := v2i.{-1, -1};
        if it != portal_list.count-1 {
            p2 = portal_list[it+1];
        }

        if p2 != .{-1, -1} {
            level.grid[p1.x][p1.y].interaction_id = xx portal_id;
            level.grid[p2.x][p2.y].interaction_id = xx portal_id;
        } else {
            level.grid[p1.x][p1.y].interaction_id = 0;
        }
        it += 1;
        portal_id += 1;
    }
}