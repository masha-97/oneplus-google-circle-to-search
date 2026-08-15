#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define INPUT_DEVICE "/dev/input/event0"
#define LOCK_FILE "/data/local/tmp/contextual-sidekey.lock"
#define PID_FILE "/data/local/tmp/contextual-sidekey.pid"
#define LONG_PRESS_MS 800
#define RETRY_DELAY_MS 500

static volatile sig_atomic_t running = 1;

static void log_message(const char *format, ...) {
    struct timespec now;
    clock_gettime(CLOCK_REALTIME, &now);
    fprintf(stderr, "[%lld.%03lld] ", (long long) now.tv_sec,
            (long long) (now.tv_nsec / 1000000));

    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fputc('\n', stderr);
    fflush(stderr);
}

static void handle_signal(int signal_number) {
    (void) signal_number;
    running = 0;
}

static int64_t monotonic_ms(void) {
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
        return -1;
    }
    return (int64_t) now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

static void delay_ms(int milliseconds) {
    struct timespec delay = {
        .tv_sec = milliseconds / 1000,
        .tv_nsec = (long) (milliseconds % 1000) * 1000000L,
    };
    while (running && nanosleep(&delay, &delay) != 0 && errno == EINTR) {
    }
}

static int acquire_singleton_lock(void) {
    int fd = open(LOCK_FILE, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
    if (fd < 0) {
        log_message("cannot open singleton lock: %s", strerror(errno));
        return -1;
    }
    if (flock(fd, LOCK_EX | LOCK_NB) != 0) {
        log_message("another daemon instance is already running");
        close(fd);
        return -1;
    }
    return fd;
}

static int write_pid_file(void) {
    int fd = open(PID_FILE, O_CREAT | O_TRUNC | O_WRONLY | O_CLOEXEC, 0600);
    if (fd < 0) {
        return -1;
    }
    char buffer[32];
    int length = snprintf(buffer, sizeof(buffer), "%ld\n", (long) getpid());
    ssize_t written = write(fd, buffer, (size_t) length);
    close(fd);
    return written == length ? 0 : -1;
}

static int run_contextual_search(void) {
    pid_t child = fork();
    if (child < 0) {
        log_message("cannot fork contextual search command: %s", strerror(errno));
        return -1;
    }
    if (child == 0) {
        execl("/system/bin/service", "service", "call", "contextual_search",
              "2", "i32", "2", (char *) NULL);
        _exit(127);
    }

    int status = 0;
    while (waitpid(child, &status, 0) < 0) {
        if (errno != EINTR) {
            log_message("cannot wait for contextual search command: %s", strerror(errno));
            return -1;
        }
    }
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
        log_message("contextual search command failed: status=%d", status);
        return -1;
    }
    log_message("contextual search started");
    return 0;
}

struct key_state {
    bool down;
    bool triggered;
    int64_t down_at_ms;
};

static void reset_key_state(struct key_state *state, const char *reason) {
    if (state->down || state->triggered) {
        log_message("key state reset: %s", reason);
    }
    state->down = false;
    state->triggered = false;
    state->down_at_ms = -1;
}

static void maybe_trigger_long_press(struct key_state *state) {
    if (!state->down || state->triggered || state->down_at_ms < 0) {
        return;
    }
    int64_t now_ms = monotonic_ms();
    if (now_ms < 0 || now_ms - state->down_at_ms < LONG_PRESS_MS) {
        return;
    }
    state->triggered = true;
    log_message("long press detected: duration_ms=%lld",
                (long long) (now_ms - state->down_at_ms));
    run_contextual_search();
}

static int poll_timeout_ms(const struct key_state *state) {
    if (!state->down || state->triggered || state->down_at_ms < 0) {
        return 1000;
    }
    int64_t now_ms = monotonic_ms();
    if (now_ms < 0) {
        return 100;
    }
    int64_t remaining = LONG_PRESS_MS - (now_ms - state->down_at_ms);
    if (remaining <= 0) {
        return 0;
    }
    return remaining > 1000 ? 1000 : (int) remaining;
}

static bool handle_input_event(const struct input_event *event,
                               struct key_state *state) {
    if (event->type == EV_SYN && event->code == SYN_DROPPED) {
        reset_key_state(state, "SYN_DROPPED");
        return false;
    }
    if (event->type != EV_KEY || event->code != BTN_TRIGGER_HAPPY32) {
        return true;
    }

    if (event->value == 1) {
        if (state->down) {
            reset_key_state(state, "new DOWN while already down");
        }
        state->down = true;
        state->triggered = false;
        state->down_at_ms = monotonic_ms();
        log_message("key down");
    } else if (event->value == 0) {
        maybe_trigger_long_press(state);
        log_message("key up");
        reset_key_state(state, "key up");
    }
    return true;
}

static void monitor_input_device(void) {
    while (running) {
        int fd = open(INPUT_DEVICE, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0) {
            log_message("open %s failed: %s", INPUT_DEVICE, strerror(errno));
            delay_ms(RETRY_DELAY_MS);
            continue;
        }

        log_message("monitoring %s without an exclusive grab", INPUT_DEVICE);
        struct key_state state = {
            .down = false,
            .triggered = false,
            .down_at_ms = -1,
        };
        bool reopen = false;

        while (running && !reopen) {
            struct pollfd input = {
                .fd = fd,
                .events = POLLIN,
                .revents = 0,
            };
            int ready = poll(&input, 1, poll_timeout_ms(&state));
            if (ready < 0) {
                if (errno == EINTR) {
                    continue;
                }
                log_message("poll failed: %s", strerror(errno));
                reopen = true;
                continue;
            }
            if (ready == 0) {
                maybe_trigger_long_press(&state);
                continue;
            }
            if (input.revents & (POLLERR | POLLHUP | POLLNVAL)) {
                log_message("input device disconnected: revents=0x%x", input.revents);
                reopen = true;
                continue;
            }
            if (!(input.revents & POLLIN)) {
                continue;
            }

            struct input_event events[16];
            ssize_t count = read(fd, events, sizeof(events));
            if (count == 0) {
                log_message("input device reached EOF");
                reopen = true;
                continue;
            }
            if (count < 0) {
                if (errno != EAGAIN && errno != EINTR) {
                    log_message("input read failed: %s", strerror(errno));
                    reopen = true;
                }
                continue;
            }
            if (count % (ssize_t) sizeof(struct input_event) != 0) {
                log_message("partial input event read: bytes=%zd", count);
                reopen = true;
                continue;
            }

            size_t event_count = (size_t) count / sizeof(struct input_event);
            for (size_t index = 0; index < event_count; index++) {
                if (!handle_input_event(&events[index], &state)) {
                    reopen = true;
                    break;
                }
            }
            maybe_trigger_long_press(&state);
        }

        reset_key_state(&state, running ? "device reopen" : "shutdown");
        close(fd);
        if (running) {
            delay_ms(RETRY_DELAY_MS);
        }
    }
}

static int self_test(void) {
    if (LONG_PRESS_MS <= 0 || access("/system/bin/service", X_OK) != 0) {
        return 1;
    }
    puts("PASS contextual-sidekey self-test");
    return 0;
}

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "--self-test") == 0) {
        return self_test();
    }
    if (argc != 1) {
        fprintf(stderr, "usage: %s [--self-test]\n", argv[0]);
        return 2;
    }

    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    signal(SIGHUP, handle_signal);
    setvbuf(stderr, NULL, _IOLBF, 0);

    int lock_fd = acquire_singleton_lock();
    if (lock_fd < 0) {
        return 1;
    }
    if (write_pid_file() != 0) {
        log_message("cannot write pid file: %s", strerror(errno));
        close(lock_fd);
        return 1;
    }

    log_message("contextual-sidekey started: threshold_ms=%d", LONG_PRESS_MS);
    monitor_input_device();
    unlink(PID_FILE);
    close(lock_fd);
    log_message("contextual-sidekey stopped");
    return 0;
}
