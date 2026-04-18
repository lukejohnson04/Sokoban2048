
Tween :: struct {
    ptr: *float;
    start: float;
    end: float;
    len: float;

    timer: float;
    interp : (float, float, float) -> float = default_tween_interp;
}

default_tween_interp :: (a: float, b: float, t: float) -> float {
    return a + (b - a) * t;
}

add_number :: (value: int) -> int {
    return value + 1;
}


tweens_update :: (tweens: *Array(Tween)) {
    using context.game_state;
    ind := 0;
    while ind < tweens.count {
        tween := *tweens.data[ind];
        tween.timer += delta;
        t := tween.timer / tween.len;
        if t > 1.0 {
            // delete
            tween.ptr = null;
            tweens.data[ind] = tweens.data[tweens.count-1];
            tweens.count -= 1;
            ind -= 1;
        } else {
            tween.ptr.* = tween.interp(tween.start, tween.end, t);
        }
        ind += 1;
    }
}

create_tween :: (ptr: *float, start: float, end: float, len: float) -> *Tween {
    using context.game_state;
    tween: Tween;
    tween.ptr = ptr;
    tween.start = start;
    tween.end = end;
    tween.len = len;
    
    return add_to_array(*game_tweens, tween);
}