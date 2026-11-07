const std = @import("std");
const vec3d = @import("vec3d.zig");
const Vec3D = vec3d.Vec3D;
const Scalar = @import("scalar.zig").Scalar;
const planck_distance = @import("scalar.zig").planck_distance;
const Ray = @import("ray.zig").Ray;

const Plane = @import("plane.zig").Plane;

pub const Intersection = struct {
    dist: Scalar,
    pixel: bool,
};

pub const Cube = struct {
    up: Vec3D,
    right: Vec3D,
    out: Vec3D,
    center: Vec3D,
    length: Scalar,
    gpa: std.mem.Allocator,

    faces: [6]Plane,

    const Basis = struct {
        x: Vec3D,
        y: Vec3D,
    };

    pub fn getBasis(self: *const Cube, face: Plane) Basis {
        return if (face.normal.isParallel(self.up))
            .{ .x = self.out, .y = self.right }
        else if (face.normal.isParallel(self.right))
            .{ .x = self.up, .y = self.out }
        else
            .{ .x = self.up, .y = self.right };
    }

    fn canIntersect(self: *const Cube, ray: Ray) bool {
        // can only intersect if ray also intersects a sphere in which `self`
        // is inscribed
        const center_minus_ray_pos = self.center.minus(ray.pos);
        const direct_dir = center_minus_ray_pos.normalize();
        // A . B = |A| |B| cosθ
        const angle = std.math.acos(ray.dir.dotProduct(direct_dir));
        if (angle > std.math.pi / 2.0) return false;
        if (angle < -std.math.pi / 2.0) return false;
        const sphere_radius: Scalar = std.math.sqrt(2) * self.length;
        const max_angle = std.math.atan(sphere_radius / center_minus_ray_pos.magnitude());
        return @abs(angle) < max_angle;
    }

    pub fn distance(self: *const Cube, ray: Ray) ?Intersection {
        if (!self.canIntersect(ray)) return null;
        var should_display: bool = false;
        var closest_dist: ?Scalar = null;
        for (self.faces) |face| {
            if (ray.distance(face)) |dist| {
                if (closest_dist != null and dist > closest_dist.?) continue;
                const point = ray.pos.plus(ray.dir.timesScalar(dist));
                const basis = self.getBasis(face);
                const x = point.minus(face.origin).dotProduct(basis.x);
                const y = point.minus(face.origin).dotProduct(basis.y);
                if (@abs(x) > self.length / 2) continue;
                if (@abs(y) > self.length / 2) continue;
                if (closest_dist == null or dist < closest_dist.?) {
                    closest_dist = dist;
                    should_display =
                        (@abs(x) > self.length / 3 or @abs(y) > self.length / 3);
                }
            }
        }
        if (closest_dist == null) return null;
        return .{ .dist = closest_dist.?, .pixel = should_display };
    }

    pub fn init(gpa: std.mem.Allocator, center: Vec3D, length: Scalar) !*Cube {
        var cube = try gpa.create(Cube);
        cube.center = center;
        cube.length = length;
        cube.gpa = gpa;

        cube.up = vec3d.z_unit;
        cube.right = vec3d.y_unit;
        cube.out = vec3d.x_unit;

        cube.faces[0] = Plane{
            .origin = cube.center.plus(vec3d.x_unit.timesScalar(length / 2)),
            .normal = vec3d.x_unit,
        };
        cube.faces[1] = Plane{
            .origin = cube.center.plus(vec3d.x_unit.timesScalar(-length / 2)),
            .normal = vec3d.x_unit.timesScalar(-1.0),
        };
        cube.faces[2] = Plane{
            .origin = cube.center.plus(vec3d.z_unit.timesScalar(length / 2)),
            .normal = vec3d.z_unit,
        };
        cube.faces[3] = Plane{
            .origin = cube.center.plus(vec3d.z_unit.timesScalar(-length / 2)),
            .normal = vec3d.z_unit.timesScalar(-1.0),
        };
        cube.faces[4] = Plane{
            .origin = cube.center.plus(vec3d.y_unit.timesScalar(length / 2)),
            .normal = vec3d.y_unit,
        };
        cube.faces[5] = Plane{
            .origin = cube.center.plus(vec3d.y_unit.timesScalar(-length / 2)),
            .normal = vec3d.y_unit.timesScalar(-1.0),
        };

        return cube;
    }

    pub fn deinit(self: *Cube) void {
        self.gpa.destroy(self);
    }
};
