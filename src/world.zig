const std = @import("std");
const Cube = @import("cube.zig").Cube;
const Camera = @import("camera.zig").Camera;
const BrailleDisplay = @import("braille_display.zig").BrailleDisplay;
const ScreenPoint = @import("braille_display.zig").Point;

const Scalar = @import("scalar.zig").Scalar;
const Ray = @import("ray.zig").Ray;
const planck_distance = @import("scalar.zig").planck_distance;

const display_point_height: Scalar = planck_distance;
const display_point_width: Scalar = planck_distance * 1.8;
const render_distance: Scalar = 20.0;

pub const World = struct {
    cube: *Cube,

    pub fn render(self: *World, io: std.Io, braille_display: *BrailleDisplay, camera: Camera) !void {
        const unit_right = camera.dir.right();
        const unit_up = unit_right.crossProduct(camera.dir);
        const screen_size = try BrailleDisplay.size();

        const screen_middle = .{
            .x = @as(Scalar, @floatFromInt(screen_size.x)) / 2.0,
            .y = @as(Scalar, @floatFromInt(screen_size.y)) / 2.0,
        };

        braille_display.clear();

        const left_side_of_screen = unit_right.timesScalar(-screen_middle.x * display_point_width);
        for (0..screen_size.y) |y| {
            var point = left_side_of_screen.plus(unit_up.timesScalar(-(@as(Scalar, @floatFromInt(y)) - screen_middle.y) * display_point_height));
            for (0..screen_size.x) |x| {
                const ray = Ray{
                    .pos = camera.pos,
                    .dir = camera.dir.plus(point).normalize(),
                };
                const pixel = self.cube.distance(ray);
                if (pixel.dist) |_| {
                    if (pixel.pixel) {
                        braille_display.plotPoint(.{ .x = x, .y = y });
                    }
                }
                point = point.plus(unit_right.timesScalar(display_point_width));
            }
        }
        try braille_display.render(io);
    }
};
