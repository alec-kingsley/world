const std = @import("std");
var terminal = &@import("terminal.zig").terminal;
const World = @import("world.zig").World;
const bd = @import("braille_display.zig");
const Camera = @import("camera.zig").Camera;
const Cube = @import("cube.zig").Cube;
const vec3d = @import("vec3d.zig");

const BrailleDisplay = bd.BrailleDisplay;
const Point = bd.Point;

pub fn main(init: std.process.Init) !void {
    const spin_speed = 0.08;
    const movement_speed = 0.2;

    const gpa = std.heap.page_allocator;
    terminal.init(init.io);
    try terminal.enableRaw();
    defer terminal.disableRaw() catch {};

    const display = try bd.BrailleDisplay.init(gpa);
    defer display.deinit(gpa) catch {};

    const cube = try Cube.init(gpa, vec3d.origin, 1.0);
    defer cube.deinit();

    var camera = Camera{
        .pos = .{ .x = -3.0, .y = 0.0, .z = 1.2 },
        .dir = .{ .x = 2.0, .y = 0.0, .z = -0.6 },
    };

    var world = World{ .cube = cube };

    while (true) {
        try world.render(init.io, display, camera);
        switch (try terminal.getKey()) {
            .char => |c| switch (c) {
                'h' => camera.dir = camera.dir.rotateRight(-spin_speed),
                'j' => camera.dir = camera.dir.rotateDown(spin_speed),
                'k' => camera.dir = camera.dir.rotateDown(-spin_speed),
                'l' => camera.dir = camera.dir.rotateRight(spin_speed),
                'w' => camera.moveForward(movement_speed),
                'a' => camera.moveRight(-movement_speed),
                's' => camera.moveForward(-movement_speed),
                'd' => camera.moveRight(movement_speed),
                'q' => break,
                else => {},
            },
            else => {},
        }
    }
}
