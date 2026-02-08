# zefx

Reactive state management for Zig, inspired by [Effector](https://effector.dev).

**Event → Store → sample → Effect** — declarative data flow graphs with comptime type safety.

## Install

```sh
zig fetch --save https://github.com/neolite/zefx/archive/refs/tags/v0.1.0.tar.gz
```

Then in your `build.zig`:

```zig
const zefx_dep = b.dependency("zefx", .{});
exe.root_module.addImport("zefx", zefx_dep.module("zefx"));
```

## Quick start

```zig
const zefx = @import("zefx");

var eng = zefx.Engine.init(allocator);
defer eng.deinit();

// Events — facts that happened
var clicked = zefx.Event(i32){ .eng = &eng };
defer clicked.deinit();

// Stores — reactive state
var $count = zefx.Store(i32){ .eng = &eng, .value = 0, .prev = 0 };
defer $count.deinit();

_ = $count.on(&clicked, &struct {
    fn r(state: i32, payload: i32) ?i32 { return state + payload; }
}.r);

// Watch — side effects (logging, rendering)
_ = $count.watch(&struct {
    fn w(v: i32) void {
        std.debug.print("count = {d}\n", .{v});
    }
}.w);

clicked.emit(5);  // → count = 5
clicked.emit(3);  // → count = 8
```

## API

### Core primitives

| Primitive | Description |
|-----------|-------------|
| `Engine` | Owns the reactive graph. Two-phase flush: pure reducers → effect watchers |
| `Event(T)` | A signal carrying payload `T`. Emit to trigger the graph |
| `Store(T)` | Holds state `T`. Updated by `.on(event, reducer)` or `.set(value)` |

### Operators

#### `sample` — connect clock, source, transform, target

When `clock` fires, snapshot `source`, apply `fn_`, push result to `target`.

```zig
// clock fires → read $count → double it → push to doubled_ev
_ = zefx.sample(&eng, .{
    .clock  = &clicked,
    .source = &$count,
    .fn_    = &struct {
        fn f(src: i32) i32 { return src * 2; }
    }.f,
    .target = &doubled_ev,
});
```

Target can be an `Event` or a `Store`. If omitted, `sample` auto-creates and returns a new `*Event(R)`:

```zig
const squared = zefx.sample(&eng, .{
    .clock  = &clicked,
    .source = &$count,
    .fn_    = &struct {
        fn f(src: i32) i32 { return src * src; }
    }.f,
});
_ = squared.watch(&log);
```

#### `guard` — conditional pass-through

Like `sample`, but with a `filter` instead of `fn_`. Only passes values where filter returns `true`:

```zig
_ = zefx.guard(&eng, .{
    .clock  = &clicked,
    .source = &$count,
    .filter = &struct {
        fn f(v: i32) bool { return v > 5; }
    }.f,
    .target = &big_values_ev,
});
```

#### `sample` with shape source

Combine multiple stores into a single snapshot:

```zig
_ = zefx.sample(&eng, .{
    .clock  = &clicked,
    .source = .{ .a = &$count, .b = &$other },
    .fn_    = &struct {
        fn f(snap: zefx.shape.SnapshotTypeOf(
            struct { a: *zefx.Store(i32), b: *zefx.Store(i32) }
        )) i32 {
            return snap.a + snap.b;
        }
    }.f,
    .target = &sum_ev,
});
```

#### `forward` — pipe one unit to another

```zig
_ = zefx.forward(&eng, &source_event, &target_event);
```

#### `restore` — create a store from an event

```zig
const $last = zefx.restore(&eng, &clicked, 0);
// $last always holds the most recent value emitted by `clicked`
```

### Factory constructors

Engine-managed allocation (auto-freed on `eng.deinit()`):

```zig
const ev = zefx.createEvent(&eng, i32);
const st = zefx.createStore(&eng, i32, 0);
```

## Execution model

1. `event.emit(payload)` schedules reducer thunks (pure) and watcher thunks (effects)
2. Engine flushes in two phases:
   - **Phase 1**: all pure reducers run, stores update, derived samples fire
   - **Phase 2**: all effect watchers run
3. If no flush is in progress, `emit` auto-flushes immediately

This guarantees consistent state snapshots — watchers always see the final state of the current tick.

## Run the demo

```sh
git clone https://github.com/neolite/zefx.git
cd zefx
zig build run
```

## License

MIT
