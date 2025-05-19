
main :: () {
    condition := true;

    a : u32 = 10;
    b : u32 = 15;
    // Crashes because the ifx returns an s64
    c : u32 = ifx condition then 10 else 15;
}


main :: () {
    condition := true;

    random_procedure :: (number: u32) {
        print("Number is %\n", number);
    }

    // Crashes because the ifx returns an s64
    random_procedure(ifx condition 10 else 15);
}

#import "Basic";