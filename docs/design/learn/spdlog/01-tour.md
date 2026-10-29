# spdlog: a guided tour of the parts you might not know

A single lesson, not a full course. It covers what spdlog does underneath and the
features that are easy to miss.

Versions checked: **spdlog 1.17.0** and **fmt 12.1** (the ones Conan gives mdot),
built with `SPDLOG_COMPILED_LIB` and `SPDLOG_FMT_EXTERNAL`. Every behavior marked
"verified" below was run in a scratch program against those exact builds.

---

## 1. Mental model

spdlog is three layers:

```
spdlog::info("x {}", 1)
      │
      ▼
  logger  ── has a name, a level, and a list of sinks
      │       (drops the message here if it's below the logger's level)
      ▼
  sink(s) ── each one has its own level and its own formatter (pattern)
      │       (each sink can drop the message again)
      ▼
  stdout / stderr / a file / a ring buffer / your callback
```

- **Logger:** the thing you call `.info()` on. It's cheap to pass around as a
  `std::shared_ptr<spdlog::logger>`.
- **Sink:** where the bytes go. One logger can write to several sinks, for example
  colored stderr *and* a file.
- **Registry:** a global name → logger map. `spdlog::stderr_color_mt("errlog")`
  creates a logger *and registers it* under the name `"errlog"`.
- **Default logger:** what the free functions `spdlog::info(...)` etc. use.
  Out of the box it's an unnamed, colored logger writing to **stdout** (verified).

The C analogy: a logger is a `FILE*` with a level filter. A sink is the fd behind
it, except one logger can fan out to many fds.

---

## 2. Things worth knowing

### 2.1 Levels: two filters, and debug is off by default

The levels from lowest to highest are `trace`, `debug`, `info`, `warn`, `err`,
`critical`, then `off`. The default level is **info**, so `spdlog::debug(...)`
prints nothing until you lower it (verified):

```cpp
spdlog::debug("hidden");                        // dropped
spdlog::set_level(spdlog::level::debug);
spdlog::debug("now shown");                     // printed
```

Both the **logger and each sink** filter. A message has to pass both (verified):

```cpp
auto sink = std::make_shared<spdlog::sinks::stderr_color_sink_mt>();
sink->set_level(spdlog::level::warn);
spdlog::logger lg("weather", sink);
lg.set_level(spdlog::level::trace);
lg.info("dropped by the sink");    // logger lets it through, sink drops it
lg.warn("printed");
```

This is how you get "everything to the log file, only warnings to the terminal"
with one logger and two sinks.

### 2.2 Control the level from the environment for free

```cpp
#include <spdlog/cfg/env.h>
spdlog::cfg::load_env_levels();   // reads SPDLOG_LEVEL
```

Running with `SPDLOG_LEVEL=debug ./tool` turns on debug output with no
`--verbose` flag needed (verified). It also accepts per-logger settings such as
`SPDLOG_LEVEL=info,mylogger=trace`. There's also `spdlog/cfg/argv.h`, which does
the same from `argv` (`SPDLOG_LEVEL=...` as an argument).

### 2.3 Patterns: you can make it not look like a log

The `[2026-10-22 20:44:25.181] [info]` prefix is just the default pattern. You can
change it per logger, or globally:

```cpp
spdlog::set_pattern("%^%l%$: %v");
spdlog::warn("disk almost full");   // prints: warning: disk almost full
                                    // with "warning" in color (verified)
```

Useful flags (the full list is in `spdlog/pattern_formatter-inl.h`):

| Flag | Meaning |
|---|---|
| `%v` | the message itself |
| `%l` / `%L` | level name (`warning`) / short level (`W`) |
| `%n` | logger name |
| `%^` … `%$` | the part between these is colored by level |
| `%H:%M:%S`, `%e` | time, milliseconds |
| `%s`, `%#`, `%!` | source file basename, line, function (macros only, see 2.6) |
| `%P`, `%t` | process id, thread id |
| `%+` | the default pattern |

### 2.4 Format strings are fmt, and they're checked at compile time

spdlog formats with **fmt**, not `std::format`, because mdot builds it with
`SPDLOG_FMT_EXTERNAL`. The syntax is nearly identical. A wrong format string is a
**compile error**, not a runtime surprise (verified with fmt 12):

```cpp
spdlog::info("missing {} {}", 1);
// error: call to consteval function 'fmt::v12::fstring<int>(...)' is not a
//        constant expression ... "argument not found"
```

If you build the format string at runtime (`fmt::runtime(str)`), the check moves to
runtime. spdlog then **catches** the error and prints
`[*** LOG ERROR #0001 ***] ... argument not found` instead of throwing (verified).
You can replace that behavior with `spdlog::set_error_handler(...)`.

### 2.5 You can format more than strings and ints

fmt ships formatters for standard types. You just need the right header (verified):

```cpp
#include <fmt/std.h>      // std::filesystem::path, std::optional, std::variant, ...
#include <fmt/ranges.h>   // vectors, maps, tuples, fmt::join

std::filesystem::path p = "/tmp/a b";
std::vector<int> v{1, 2, 3};
spdlog::info("path {}", p);                       // path /tmp/a b
spdlog::info("{} / {}", v, fmt::join(v, ", "));  // [1, 2, 3] / 1, 2, 3
```

This means no more `.string()` on every path argument.

### 2.6 Macros vs functions: source location and zero cost

```cpp
SPDLOG_DEBUG("parsed {} rows", n);   // macro
spdlog::debug("parsed {} rows", n);  // function
```

The differences:

1. **Source location.** Only the macros fill in `%s` / `%#` / `%!`. With pattern
   `[%s:%#] %v`, the macro printed `[t.cpp:21] from macro` and the function printed
   `[:] from function` (verified).
2. **Compiled out.** Macros below `SPDLOG_ACTIVE_LEVEL` disappear at compile time:
   the arguments aren't even evaluated. The default is `SPDLOG_LEVEL_INFO`, so
   **`SPDLOG_DEBUG` and `SPDLOG_TRACE` do nothing even after `set_level(debug)`**
   (verified). To keep them, `#define SPDLOG_ACTIVE_LEVEL SPDLOG_LEVEL_TRACE`
   *before* including spdlog (or pass it as a `-D` flag to every file).

### 2.7 Backtrace: debug logs that only appear when something fails

This is the most underrated feature. spdlog keeps the last N messages in a ring,
**even ones below the current level**, and prints them only when you ask:

```cpp
spdlog::enable_backtrace(3);
for (int i = 0; i < 5; i++) spdlog::debug("step {}", i);  // not printed
spdlog::error("failed");
spdlog::dump_backtrace();
```

Output (verified):

```
[error] failed
[info] ****************** Backtrace Start ******************
[debug] step 3
[debug] step 4
[error] failed
[info] ****************** Backtrace End ********************
```

The output stays quiet on success, and you still get context on failure.

### 2.8 Sinks you can test against

To assert on log output in a unit test, don't parse stderr. Swap in a memory sink:

- `ringbuffer_sink_mt(n)`: keeps the last n messages. `last_formatted()` returns
  them as strings, each **with a trailing newline** (verified).
- `callback_sink_mt(fn)`: calls your lambda with each `log_msg`. `msg.payload` is
  the formatted text without the pattern, and `msg.level` is the level (verified).

```cpp
auto ring = std::make_shared<spdlog::sinks::ringbuffer_sink_mt>(10);
spdlog::logger lg("test", ring);
lg.set_pattern("%l %v");
lg.warn("two");
// ring->last_formatted() == {"warning two\n"}
```

Other sinks exist (`basic_file_sink`, `rotating_file_sink`, `daily_file_sink`,
`syslog_sink`, `systemd_sink`, `dup_filter_sink`, `null_sink`). Look in
`spdlog/sinks/`.

### 2.9 Small extras

- `spdlog::stopwatch sw; ... spdlog::info("took {:.3}", sw);` prints elapsed
  seconds (`took 0.0192`, verified). It's a cheap profiler for "why is this slow".
- `_mt` vs `_st`: `stderr_color_mt` uses a mutex, while `_st` is single-threaded and
  slightly faster. If you're unsure, use `_mt`.
- `flush_on(level::err)`: flush immediately at that level and above. This matters
  for file sinks if the program crashes.

---

## 3. Traps

| Situation | What happens | What to do |
|---|---|---|
| `spdlog::debug(...)` prints nothing | default level is info | `set_level(debug)` or `SPDLOG_LEVEL=debug` |
| `SPDLOG_DEBUG(...)` prints nothing even at debug level | compiled out by `SPDLOG_ACTIVE_LEVEL` (default info) | define it before the include |
| Creating the same named logger twice | throws `spdlog_ex`: `logger with name 'x' already exists` (verified) | create once; look it up with `spdlog::get("x")`, which returns `nullptr` if missing (verified) |
| Format string built at runtime is wrong | caught, prints `*** LOG ERROR ***`, program continues | use literal format strings so the compiler checks them |
| Output piped to a file or `less` | the color sinks drop color codes when the stream isn't a TTY (verified: plain when piped, ANSI codes under a pseudo-terminal) | nothing; it's automatic. Force it with the sink's `set_color_mode(spdlog::color_mode::always)` if needed |
| Logger level says yes, nothing appears | the sink's own level drops it | check both levels |
| Pattern shows `[:]` for `%s:%#` | you used the function, not the macro | use `SPDLOG_*` macros when you need location |
| `std::format`-only formatter for your type | spdlog uses fmt here, which won't see it | write a `fmt::formatter` specialization, or format to a string first |

---

## 4. Exercises (in `learn/spdlog/`, not mdot)

1. **Quiet by default.** Write a tiny "word counter" CLI that prints its *result*
   (the count) to stdout as plain text, and *diagnostics* to stderr through spdlog
   with the pattern `%^%l%$: %v`. Add `-v` (debug) and `-q` (warn only). Check that
   `./wc file > out.txt` leaves `out.txt` with only the number in it.
2. **Backtrace.** Make the counter log `debug` for every line it reads, with
   backtrace enabled at 5. Make it fail on a line containing `BAD` and dump the
   backtrace. Without `-v`, does the user still see the lines before the failure?
3. **Test the logs.** In a Catch2 test, give a function a logger backed by a
   `ringbuffer_sink`, and assert that it logged exactly one warning for a given
   input. Think about how the function *gets* the logger: a global, a parameter,
   or `spdlog::get`. Which one is easiest to test?
4. **Compile-time levels.** Put a `SPDLOG_TRACE` call whose argument is a function
   that prints to stdout as a side effect. With and without
   `SPDLOG_ACTIVE_LEVEL=SPDLOG_LEVEL_TRACE`, is the function called?

---

## 5. Bridge to mdot

mdot currently sends everything through spdlog with the default pattern, so
`linked: a -> b` comes out with a timestamp in front. That's on the deferred-polish
list. Before you touch it, write your own rules (a few lines each) for these:

1. **Results vs diagnostics.** Which mdot messages are *results* the user asked for
   (`would link a -> b`), and which are *diagnostics* (`reading spec.lua`)? Should
   results go through spdlog at all, or through plain `fmt::print`? Which stream
   does each one belong on (stdout or stderr)? Think about `mdot plan ... | grep`.
2. **Verbosity.** Do you want `-v` / `-q` flags, `SPDLOG_LEVEL`, or both?
3. **Failures with context.** When a spec fails to load or a link conflicts, would a
   backtrace of what mdot was doing just before (which spec, which clause) help?
4. **Testability.** If `run` (the coordinator) ever logs, how will a test see
   those messages? Look at how your `Core` struct already carries `errlog`.
