const std = @import("std");
const libscalar = @import("scalar.zig");
const Scalar = libscalar.Scalar;

const Angle = @import("angle.zig").Angle;

pub const Vec3D = struct {
    x: Scalar,
    y: Scalar,
    z: Scalar,

    pub fn isParallel(self: Vec3D, other: Vec3D) bool {
        return self.crossProduct(other).magnitude() < libscalar.planck_distance;
    }

    pub fn distanceFrom(self: Vec3D, other: Vec3D) Scalar {
        const x_diff: Scalar = self.x - other.x;
        const y_diff: Scalar = self.y - other.y;
        const z_diff: Scalar = self.z - other.z;
        return std.math.sqrt(x_diff * x_diff + y_diff * y_diff + z_diff * z_diff);
    }

    pub fn plus(self: Vec3D, other: Vec3D) Vec3D {
        return Vec3D{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn minus(self: Vec3D, other: Vec3D) Vec3D {
        return Vec3D{
            .x = self.x - other.x,
            .y = self.y - other.y,
            .z = self.z - other.z,
        };
    }

    pub fn dotProduct(self: Vec3D, other: Vec3D) Scalar {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn crossProduct(self: Vec3D, other: Vec3D) Vec3D {
        return Vec3D{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn timesScalar(self: Vec3D, scalar: Scalar) Vec3D {
        return Vec3D{
            .x = self.x * scalar,
            .y = self.y * scalar,
            .z = self.z * scalar,
        };
    }

    pub fn magnitude(self: Vec3D) Scalar {
        return std.math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn normalize(self: Vec3D) Vec3D {
        const mag = self.magnitude();

        return Vec3D{
            .x = self.x / mag,
            .y = self.y / mag,
            .z = self.z / mag,
        };
    }

    pub fn right(self: Vec3D) Vec3D {
        return self.crossProduct(z_unit).normalize();
    }

    pub fn rotate(self: Vec3D, axis: Vec3D, a: Angle) Vec3D {
        // Source - https://stackoverflow.com/a/10787529
        // Posted by Drise, modified by community. See post 'Timeline' for change
        // Retrieved 2026-08-14, License - CC BY-SA 3.0

        const cosa = std.math.cos(a);
        const sina = std.math.sin(a);
        const cosa_compliment = 1.0 - cosa;

        var q: [3][3]Scalar = undefined;

        q[0][0] = axis.x * axis.x * cosa_compliment + cosa;
        q[0][1] = axis.y * axis.x * cosa_compliment + axis.z * sina;
        q[0][2] = axis.z * axis.x * cosa_compliment - axis.y * sina;

        q[1][0] = axis.y * axis.x * cosa_compliment - axis.z * sina;
        q[1][1] = axis.y * axis.y * cosa_compliment + cosa;
        q[1][2] = axis.z * axis.y * cosa_compliment + axis.x * sina;

        q[2][0] = axis.x * axis.z * cosa_compliment + axis.y * sina;
        q[2][1] = axis.z * axis.y * cosa_compliment - axis.x * sina;
        q[2][2] = axis.z * axis.z * cosa_compliment + cosa;

        return Vec3D{
            .x = self.x * q[0][0] + self.y * q[0][1] + self.z * q[0][2],
            .y = self.x * q[1][0] + self.y * q[1][1] + self.z * q[1][2],
            .z = self.x * q[2][0] + self.y * q[2][1] + self.z * q[2][2],
        };
    }

    pub fn rotateDown(self: Vec3D, a: Angle) Vec3D {
        return self.rotate(self.right(), a);
    }

    pub fn rotateRight(self: Vec3D, a: Angle) Vec3D {
        return self.rotate(z_unit, a);
    }

    pub fn print(self: Vec3D, io: std.Io) !void {
        const stdout = std.Io.File.stdout();
        var buffer: [32]u8 = undefined;
        var writer = stdout.writer(io, &buffer);
        try writer.interface.print("<{}, {}, {}>", .{ self.x, self.y, self.z });
        try writer.interface.flush();
    }
};

pub const x_unit = Vec3D{ .x = 1, .y = 0, .z = 0 };
pub const y_unit = Vec3D{ .x = 0, .y = 1, .z = 0 };
pub const z_unit = Vec3D{ .x = 0, .y = 0, .z = 1 };
pub const origin = Vec3D{ .x = 0, .y = 0, .z = 0 };

fn isqrt(value: Scalar) Scalar {
    return 1.0 / std.math.sqrt(value);
}
