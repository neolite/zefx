const event_mod = @import("event.zig");
const store_mod = @import("store.zig");
const sample_mod = @import("sample.zig");

pub const Engine = @import("engine.zig").Engine;
pub const Thunk = @import("engine.zig").Thunk;
pub const Subscription = @import("engine.zig").Subscription;
pub const Phase = @import("engine.zig").Phase;
pub const Event = event_mod.Event;
pub const Store = store_mod.Store;
pub const shape = @import("shape.zig");
pub const sample = sample_mod.sample;
pub const guard = sample_mod.guard;

// ─────────────────────────────────────────────
// Constructors (Effector-like)
// ─────────────────────────────────────────────

pub fn createEvent(eng: *Engine, comptime T: type) *Event(T) {
    const ev = eng.allocator.create(Event(T)) catch @panic("OOM");
    ev.* = .{ .eng = eng };
    eng.trackGraphAlloc(@ptrCast(ev), &struct {
        fn dtor(a: @import("std").mem.Allocator, p: *anyopaque) void {
            const e: *Event(T) = @ptrCast(@alignCast(p));
            e.deinit();
            a.destroy(e);
        }
    }.dtor);
    return ev;
}

pub fn createStore(eng: *Engine, comptime T: type, initial: T) *Store(T) {
    const st = eng.allocator.create(Store(T)) catch @panic("OOM");
    st.* = .{ .eng = eng, .value = initial, .prev = initial };
    eng.trackGraphAlloc(@ptrCast(st), &struct {
        fn dtor(a: @import("std").mem.Allocator, p: *anyopaque) void {
            const s: *Store(T) = @ptrCast(@alignCast(p));
            s.deinit();
            a.destroy(s);
        }
    }.dtor);
    return st;
}

// ─────────────────────────────────────────────
// forward(from, to) — sugar (deprecated in v23, use sample)
// ─────────────────────────────────────────────

pub fn forward(eng: *Engine, from: anytype, to: anytype) @TypeOf(to) {
    return sample(eng, .{ .clock = from, .source = from, .target = to });
}

// ─────────────────────────────────────────────
// restore(event, initial) → *Store(T)
// ─────────────────────────────────────────────

pub fn restore(eng: *Engine, ev: anytype, initial: @typeInfo(@TypeOf(ev)).pointer.child.Payload) *Store(@typeInfo(@TypeOf(ev)).pointer.child.Payload) {
    const T = @typeInfo(@TypeOf(ev)).pointer.child.Payload;
    const st = createStore(eng, T, initial);
    _ = st.on(ev, &struct {
        fn reduce(_: T, x: T) ?T {
            return x;
        }
    }.reduce);
    return st;
}
