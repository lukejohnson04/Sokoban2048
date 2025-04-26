
Resource_Header :: struct {
    modtime: Apollo_Time;
    size: s64;
}

Resource :: struct($T: Type) {
    data: T;

    MAX_PATH_LENGTH :: 64;
    path: [MAX_PATH_LENGTH] u8;

    header: Resource_Header;
}

resource_set_path :: (resource: *Resource($T), path: string) {
    assert(path.count <= Resource.MAX_PATH_LENGTH);
    memcpy(resource.path.data, path.data, path.count);
    for path.count..Resource.MAX_PATH_LENGTH-1 {
        resource.path[it] = 0;
    }
}

check_resource_reload :: (res: *Resource($T)) -> bool {
    modtime, size, success := File_Utilities.file_modtime_and_size(xx res.path);
    if success == false {
        print("Error! Reloading asset did not work.\n");
        return false;
    }
    if res.header.modtime != modtime || res.header.size != size {
        #if T == Texture {
            res.data = load_texture(xx res.path);
        }
        res.header.modtime = modtime;
        res.header.size = size;
        return true;
    }
    return false;
}