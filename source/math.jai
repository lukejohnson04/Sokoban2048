
v2 :: struct ($T: Type) {
    x, y: T;
}

operator + :: (a: v2($T), b: v2(T)) -> v2(T) {
    result: v2(T);
    result.x = a.x + b.x;
    result.y = a.y + b.y;
    return result;
}

operator - :: (a: v2($T), b: v2(T)) -> v2(T) {
    result: v2(T);
    result.x = a.x - b.x;
    result.y = a.y - b.y;
    return result;
}

operator * :: (a: v2($T), mult: T) -> v2(T) #symmetric {
    result := a;
    result.x *= mult;
    result.y *= mult;
    return result;
}

operator == :: (a: v2($T), b: v2(T)) -> bool {
    return a.x == b.x && a.y == b.y;
}


Rect :: struct {
    x: float32;
    y: float32;
    w: float32;
    h: float32;

    #place x;
    pos: Vector2 = ---;

    #place w;
    size: Vector2 = ---;
}

iRect :: struct {
    x, y, w, h: s64;
}

v2i :: v2(s64);
v2f :: v2(float32);
v2d :: v2(float64);

rect_contains_point :: (using rect: iRect, px: s64, py: s64) -> bool {
    if (!w || !h) {
        return false;
    }
    return (px >= x && px <= x + w && py >= y && py <= y + h);
}

radians :: (degrees: float32) -> float32 {
    return degrees * (PI / 180.0);
}

angle_to_point :: (a: Vector2, b: Vector2) -> float {
    return atan2(a.y - b.y, a.x - b.x);
}



// ChatGPT code lol
make_quaternion_from_axis_angle :: (axis: Vector3, degrees: float32) -> Quaternion {
    // Normalize the axis if it isn't already
    normalized_axis := normalize(axis);

    angle_radians := degrees * (PI / 180.0);
    half_angle := angle_radians * 0.5;
    s := sin(half_angle);

    result: Quaternion;
    result.x = normalized_axis.x * s;
    result.y = normalized_axis.y * s;
    result.z = normalized_axis.z * s;
    result.w = cos(half_angle);

    return result;
}

#import "Math";