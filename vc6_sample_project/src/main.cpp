#include <iostream>
#include "sample.h"

int main() {
    std::cout << "VC6 Sample Project" << std::endl;
    
    Sample sample;
    std::cout << "1 + 2 = " << sample.add(1, 2) << std::endl;
    
    return 0;
}