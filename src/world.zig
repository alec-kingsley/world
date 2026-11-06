const std = @import("std");
const Cube = @import("cube.zig").Cube;
const Intersection = @import("cube.zig").Intersection;
const Camera = @import("camera.zig").Camera;
const BrailleDisplay = @import("braille_display.zig").BrailleDisplay;
const ScreenPoint = @import("braille_display.zig").Point;
const Vec3D = @import("vec3d.zig").Vec3D;

const Scalar = @import("scalar.zig").Scalar;
const Ray = @import("ray.zig").Ray;
const planck_distance = @import("scalar.zig").planck_distance;

const display_point_height: Scalar = planck_distance;
const display_point_width: Scalar = planck_distance * 1.8;
const render_distance: Scalar = 20.0;

pub const World = struct {
    cubes: [32]*Cube,
    cube_ct: u32,
    gpa: std.mem.Allocator,

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
                var closest_pixel: ?Intersection = null;
                for (0..self.cube_ct) |i| {
                    if (self.cubes[i].distance(ray)) |pixel| {
                        if (closest_pixel == null or closest_pixel.?.dist > pixel.dist) {
                            closest_pixel = pixel;
                        }
                    }
                }
                if (closest_pixel != null) {
                    if (closest_pixel.?.pixel) {
                        braille_display.plotPoint(.{ .x = x, .y = y });
                    }
                }
                point = point.plus(unit_right.timesScalar(display_point_width));
            }
        }
        try braille_display.render(io);
    }

    pub fn spawn_cube(self: *World, center: Vec3D) !void {
        if (self.cube_ct == self.cubes.len) {
            return error.TooManyCubes;
        }
        self.cubes[self.cube_ct] = try Cube.init(self.gpa, center, 1.0);
        self.cube_ct += 1;
    }

    pub fn init(gpa: std.mem.Allocator) !*World {
        var world = try gpa.create(World);
        world.gpa = gpa;
        world.cube_ct = 0;
        return world;
    }

    pub fn deinit(self: *World) void {
        for (0..self.cube_ct) |i| {
            self.gpa.destroy(self.cubes[i]);
        }
        self.gpa.destroy(self);
    }
};
