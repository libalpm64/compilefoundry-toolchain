#include <barrier>
#include <latch>
#include <stop_token>
#include <thread>

int main() {
    std::barrier sync_point(2);
    std::latch done(1);
    std::jthread worker([&](std::stop_token token) {
        sync_point.arrive_and_wait();
        if (!token.stop_requested()) {
            done.count_down();
        }
    });
    sync_point.arrive_and_wait();
    done.wait();
    worker.request_stop();
    return 0;
}

