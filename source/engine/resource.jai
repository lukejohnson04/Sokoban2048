
Resource_Header :: struct {
    MAX_PATH_LENGTH :: 64;
    path: [MAX_PATH_LENGTH] u8;
    modtime: Apollo_Time;
    size: s64;
}

Resource :: struct($T: Type) {
    #as using data: T;

    union {
        header: Resource_Header;
        vert_header: Resource_Header;
    }
    union {
        frag_header: Resource_Header;
        italic_header: Resource_Header;
    }
    union {
        bold_header: Resource_Header;
    }
}

Resource_Tracker :: struct {
    textures: [MAX_RESOURCE_COUNT] *Resource(Texture);
    texture_count := 0;
    shaders: [MAX_RESOURCE_COUNT] *Resource(Shader);
    shader_count := 0;
    mix_chunks: [MAX_RESOURCE_COUNT] *Resource(*Mix_Chunk);
    mix_chunk_count := 0;
    mix_musics: [MAX_RESOURCE_COUNT] *Resource(*Mix_Music);
    mix_music_count := 0;
    fonts: [MAX_FONT_COUNT] *Resource(Font);
    font_count := 0;
    MAX_RESOURCE_COUNT :: 128;
    MAX_FONT_COUNT :: 16;

    resource_check_timer : float32;
}

resource_tracker_reload_resources :: (using tracker: *Resource_Tracker, delta: float) {
    resource_check_timer += delta;

    if resource_check_timer > 0.25 {
        for 0..texture_count-1 {
            res := textures[it];
            modtime, size, reload := check_resource_reload(*res.header);
            if reload {
                n_data, success := load_texture(xx res.header.path);
                if success {
                    res.data = n_data;
                    res.header.modtime = modtime;
                    res.header.size = size;
                }
            }
        }
        
        for 0..shader_count-1 {
            res := shaders[it];
            modtime, size, reload :=        check_resource_reload(*res.vert_header);
            modtime2, size2, reload2 :=     check_resource_reload(*res.frag_header);
            if reload || reload2 {
                if create_shader(*res.data, xx res.vert_header.path, xx res.frag_header.path) {
                    res.vert_header.modtime = modtime;
                    res.vert_header.size = size;

                    res.frag_header.modtime = modtime2;
                    res.frag_header.size = size2;
                }
            }
        }

        for 0..mix_chunk_count-1 {
            res := mix_chunks[it];
            modtime, size, reload := check_resource_reload(*res.header);
            if reload {
                res.data = Mix_LoadWAV(res.header.path.data);
                res.header.modtime = modtime;
                res.header.size = size;
            }
        }
    }
}

resource_set_path :: (header: *Resource_Header, path: string) {
    assert(path.count <= header.MAX_PATH_LENGTH);
    memcpy(header.path.data, path.data, path.count);
    for path.count..header.MAX_PATH_LENGTH-1 {
        header.path[it] = 0;
    }
}

check_resource_reload :: (header: *Resource_Header) -> Apollo_Time, s64, bool {
    modtime, size, success := File_Utilities.file_modtime_and_size(xx header.path);

    if success == false {
        return modtime, size, false;
    }
    if header.modtime != modtime || header.size != size {
        return modtime, size, true;
    }
    return modtime, size, false;
}

load_texture_from_disk :: (resource: *Resource(Texture), path: string) {
    resource.data = load_texture(path);

    resource_set_path(*resource.header, path);
    modtime, size, success := File_Utilities.file_modtime_and_size(xx path);
    resource.header.modtime = modtime;
    resource.header.size = size;

    using context.game_state;
    resource_tracker.textures[resource_tracker.texture_count] = resource;
    resource_tracker.texture_count += 1;
    assert(resource_tracker.texture_count <= Resource_Tracker.MAX_RESOURCE_COUNT);
}

load_shader_from_disk :: (resource: *Resource(Shader), frag_path: string, vert_path: string) {
    if !create_shader(*resource.data, frag_path, vert_path) {
        print("ERROR: Failed to load shader from disk! Frag path: %\tVert path: %\n", frag_path, vert_path);
        return;
    }

    {
        resource_set_path(*resource.header, frag_path);
        modtime, size, success := File_Utilities.file_modtime_and_size(xx vert_path);
        resource.header.modtime = modtime;
        resource.header.size = size;
    }
    {
        resource_set_path(*resource.frag_header, vert_path);
        modtime, size, success := File_Utilities.file_modtime_and_size(xx frag_path);
        resource.frag_header.modtime = modtime;
        resource.frag_header.size = size;
    }

    using context.game_state;
    resource_tracker.shaders[resource_tracker.shader_count] = resource;
    resource_tracker.shader_count += 1;
    assert(resource_tracker.shader_count <= Resource_Tracker.MAX_RESOURCE_COUNT);
}

load_mix_chunk_from_disk :: (resource: *Resource(*Mix_Chunk), path: string) {
    resource.data = Mix_LoadWAV(path.data);

    resource_set_path(*resource.header, path);
    modtime, size, success := File_Utilities.file_modtime_and_size(xx path);
    resource.header.modtime = modtime;
    resource.header.size = size;

    using context.game_state;
    resource_tracker.mix_chunks[resource_tracker.mix_chunk_count] = resource;
    resource_tracker.mix_chunk_count += 1;
    assert(resource_tracker.mix_chunk_count <= Resource_Tracker.MAX_RESOURCE_COUNT);
}

load_mix_music_from_disk :: (resource: *Resource(*Mix_Music), path: string) {
    resource.data = Mix_LoadMUS(path.data);

    resource_set_path(*resource.header, path);
    modtime, size, success := File_Utilities.file_modtime_and_size(xx path);
    resource.header.modtime = modtime;
    resource.header.size = size;

    using context.game_state;
    resource_tracker.mix_musics[resource_tracker.mix_music_count] = resource;
    resource_tracker.mix_music_count += 1;
    assert(resource_tracker.mix_chunk_count <= Resource_Tracker.MAX_RESOURCE_COUNT);
}

load_font_from_disk :: (resource: *Resource(Font), path: string, italic_path := "", bold_path := "", font_size: int) -> bool {
    resource.size = font_size;

    if !load_font(resource, path, italic_path, bold_path, font_size) {
        return false;
    }
    resource_set_path(*resource.header, path);
    modtime, size, success := File_Utilities.file_modtime_and_size(xx path);
    resource.header.modtime = modtime;
    resource.header.size = size;

    if italic_path != "" {
        resource_set_path(*resource.italic_header, italic_path);
        modtime, size, success = File_Utilities.file_modtime_and_size(xx italic_path);
        resource.italic_header.modtime = modtime;
        resource.italic_header.size = size;
    }

    if bold_path != "" {
        resource_set_path(*resource.bold_header, bold_path);
        modtime, size, success = File_Utilities.file_modtime_and_size(xx bold_path);
        resource.bold_header.modtime = modtime;
        resource.bold_header.size = size;
    }

    using context.game_state;
    resource_tracker.fonts[resource_tracker.font_count] = resource;
    resource_tracker.font_count += 1;
    assert(resource_tracker.font_count <= Resource_Tracker.MAX_RESOURCE_COUNT);
    return true;
}