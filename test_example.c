// Simple test program for CGS demonstration
// This program demonstrates symbolic execution with KLEE
//
// The program has 4 distinct execution paths based on the input values.
// KLEE will automatically generate test cases to cover all paths.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int process_data(int x, int y) {
    // This function has 4 different paths based on x and y values
    if (x > 100) {
        if (y < 50) {
            // Path 1: x > 100 AND y < 50
            printf("Path 1: x is large, y is small\n");
            return x + y;
        } else {
            // Path 2: x > 100 AND y >= 50
            printf("Path 2: x is large, y is not small\n");
            return x - y;
        }
    } else {
        if (y > 200) {
            // Path 3: x <= 100 AND y > 200
            printf("Path 3: x is not large, y is very large\n");
            return x * 2;
        } else {
            // Path 4: x <= 100 AND y <= 200
            printf("Path 4: both x and y are moderate\n");
            return y * 2;
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s <num1> <num2>\n", argv[0]);
        printf("Example: %s 150 30\n", argv[0]);
        return 1;
    }
    
    // Convert command-line arguments to integers
    int a = atoi(argv[1]);
    int b = atoi(argv[2]);
    
    printf("Input: x=%d, y=%d\n", a, b);
    
    // Process the data
    int result = process_data(a, b);
    
    printf("Result: %d\n", result);
    
    // Extra condition to make it more interesting
    if (result > 500) {
        printf("Wow, that's a large result!\n");
    }
    
    return 0;
}
