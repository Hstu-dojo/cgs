// Simple test program for CGS demonstration
// This program demonstrates symbolic execution with KLEE
//
// The program has 4 distinct execution paths based on the input values.
// KLEE will automatically generate test cases to cover all paths.

#include <klee/klee.h>

int process_data(int x, int y) {
    // This function has 4 different paths based on x and y values
    if (x > 100) {
        if (y < 50) {
            // Path 1: x > 100 AND y < 50
            return x + y;
        } else {
            // Path 2: x > 100 AND y >= 50
            return x - y;
        }
    } else {
        if (y > 200) {
            // Path 3: x <= 100 AND y > 200
            return x * 2;
        } else {
            // Path 4: x <= 100 AND y <= 200
            return y * 2;
        }
    }
}

int main() {
    int a, b;
    
    // Make the variables symbolic
    // This tells KLEE to explore all possible values for a and b
    klee_make_symbolic(&a, sizeof(a), "a");
    klee_make_symbolic(&b, sizeof(b), "b");
    
    // Process the data
    int result = process_data(a, b);
    
    // Extra condition to make it more interesting
    if (result > 500) {
        // This creates an additional path condition
        return 1;
    }
    
    return 0;
}
