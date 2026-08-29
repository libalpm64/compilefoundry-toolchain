#include <flat_map>
#include <generator>
#include <stdexcept>

std::generator<int> values() {
    co_yield 2;
    co_yield 3;
}

int main() {
    std::flat_map<int, int> values_by_key{{2, 4}, {3, 9}};
    try {
        if (values_by_key.at(2) == 4) {
            throw std::runtime_error("ok");
        }
    } catch (const std::runtime_error&) {
        int total = 0;
        for (int value : values()) {
            total += value;
        }
        return total == 5 ? 0 : 1;
    }
    return 1;
}

