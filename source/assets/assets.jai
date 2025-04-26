
Resource_Header :: struct {
    modtime: Apollo_Time;
    size: s64;
}

Resource :: struct($T: Type) {
    #as using data: T;

    MAX_PATH_LENGTH :: 64;
    path: [MAX_PATH_LENGTH] u8;

    header: Resource_Header;
}

resource_set_path :: (resource: *Resource($T), path: string) {
    assert(path.count <= resource.MAX_PATH_LENGTH);
    memcpy(resource.path.data, path.data, path.count);
    for path.count..resource.MAX_PATH_LENGTH-1 {
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

load_resource :: (resource: *Resource($T), path: string) {
    #if T == Texture {
        resource.data = load_texture(path);
    }
    resource_set_path(resource, path);
    modtime, size, success := File_Utilities.file_modtime_and_size(xx path);
    resource.header.modtime = modtime;
    resource.header.size = size;
}