const std = @import("std");
const terminal = @import("terminal.zig");
const World = @import("world.zig").World;
const bd = @import("braille_display.zig");
const Camera = @import("camera.zig").Camera;
const Cube = @import("cube.zig").Cube;
const vec3d = @import("vec3d.zig");

const BrailleDisplay = bd.BrailleDisplay;
const Point = bd.Point;

const Queue = std.Io.Queue;

const Key = terminal.Key;

const planck_dist = @import("scalar.zig").planck_distance;
const Scalar = @import("scalar.zig").Scalar;
const Vec3D = @import("vec3d.zig").Vec3D;

fn plot_crosshair(io: std.Io) !void {
    const window_size = try terminal.getWindowSize();
    var buffer: [1000]u8 = undefined;
    var writer = std.Io.File.Writer.initInterface(&buffer);
    try terminal.moveCursor(&writer, window_size.rows / 2, window_size.cols / 2);
    _ = try writer.write("•");
    try std.Io.File.stdout().writeStreamingAll(io, writer.buffered());
}

fn engine(io: std.Io, key_queue: *Queue(Key)) !void {
    const spin_speed = 0.08;
    const movement_speed = 0.2;
    const player_height = 1.2;
    const world_gravity = 0.015;

    const tick_ns = std.time.ns_per_ms * 20;

    const gpa = std.heap.page_allocator;
    const display = try bd.BrailleDisplay.init(gpa);
    defer display.deinit(gpa) catch {};
    const cube = try Cube.init(gpa, vec3d.origin, 1.0);
    defer cube.deinit();
    var camera = Camera{
        .pos = .{ .x = -3.0, .y = 0.0, .z = player_height },
        .dir = .{ .x = 2.0, .y = 0.0, .z = -0.6 },
    };

    var world = World{ .cube = cube };

    var f3_menu = false;

    var velocity: Vec3D = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    var last_tick_ns = std.Io.Timestamp.now(io, std.Io.Clock.real).nanoseconds;
    var last_frame_ns = last_tick_ns;
    while (true) {
        try world.render(io, display, camera);
        if (f3_menu) {
            var buffer: [1000]u8 = undefined;
            var writer = std.Io.File.Writer.initInterface(&buffer);
            try terminal.moveCursor(&writer, 2, 1);
            _ = try writer.print("pos (x, y, z): ({}, {}, {})", .{ camera.pos.x, camera.pos.y, camera.pos.z });
            try terminal.moveCursor(&writer, 3, 1);
            _ = try writer.print("dir (x, y, z): ({}, {}, {})", .{ camera.dir.x, camera.dir.y, camera.dir.z });
            try terminal.moveCursor(&writer, 4, 1);
            _ = try writer.print("vel (x, y, z): ({}, {}, {})", .{ velocity.x, velocity.y, velocity.z });
            try terminal.moveCursor(&writer, 5, 1);
            const frame_ns = std.Io.Timestamp.now(io, std.Io.Clock.real).nanoseconds;
            const fps = @divTrunc(std.time.ns_per_s, (frame_ns - last_frame_ns));
            last_frame_ns = frame_ns;
            _ = try writer.print("fps: {}", .{fps});
            try std.Io.File.stdout().writeStreamingAll(io, writer.buffered());
            try plot_crosshair(io);
        }

        var key: Key = undefined;
        while (try key_queue.get(io, (&key)[0..1], 0) == 1) {
            switch (key) {
                .char => |c| switch (c) {
                    'h' => camera.lookRight(-spin_speed),
                    'j' => camera.lookDown(spin_speed),
                    'k' => camera.lookDown(-spin_speed),
                    'l' => camera.lookRight(spin_speed),
                    'w' => camera.moveForward(movement_speed),
                    'a' => camera.moveRight(-movement_speed),
                    's' => camera.moveForward(-movement_speed),
                    'd' => camera.moveRight(movement_speed),
                    ' ' => velocity.z = 0.2,
                    'q' => break,
                    else => {},
                },
                .function => |f| switch (f) {
                    3 => f3_menu = !f3_menu,
                    else => {},
                },
                else => {},
            }
        }
        const cur_ts_ns = std.Io.Timestamp.now(io, std.Io.Clock.real).nanoseconds;
        const elapsed_ns = cur_ts_ns - last_tick_ns;
        if (elapsed_ns >= tick_ns) {
            if (camera.pos.z < player_height + planck_dist and velocity.z < planck_dist) {
                velocity.z = 0.0;
            } else {
                velocity.z -= world_gravity;
            }
            const elapsed_ticks = @divFloor(elapsed_ns, tick_ns);
            camera.pos.z += velocity.z * @as(Scalar, @floatFromInt(elapsed_ticks));
            last_tick_ns = cur_ts_ns;
        }
    }
}

pub fn main(init: std.process.Init) !void {
    terminal.terminal.init(init.io);
    try terminal.terminal.enableRaw();
    defer terminal.terminal.disableRaw() catch {};
    var key_buf: [10]Key = undefined;
    var queue: Queue(Key) = .init(&key_buf);
    var thread = try std.Thread.spawn(.{}, engine, .{ init.io, &queue });
    thread.detach();
    while (true) {
        const key = try terminal.terminal.getKey();
        try queue.putOne(init.io, key);
        if (key == .char and key.char == 'q') break;
    }
}
