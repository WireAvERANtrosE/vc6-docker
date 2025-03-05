#include "hello.h"
#include <stdio.h>
#include <stdlib.h>

// Include the generated IDL header
#include "calculator.h"

int main(int argc, char** argv) {
    printf("VC6 CMake Proxy Example\n");
    printf("=======================\n\n");
    
    // Call our hello function
    const char* name = argc > 1 ? argv[1] : "World";
    say_hello(name);
    
    // Show that we have access to the IDL-generated interface
    printf("\nIDL Interface GUID: %s\n", __uuidof(ICalculator));
    
    return 0;
}