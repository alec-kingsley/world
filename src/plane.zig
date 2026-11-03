const Vec3D = @import("vec3d.zig").Vec3D;
const Scalar = @import("scalar.zig").Scalar;

pub const Plane = struct {
    origin: Vec3D,
    normal: Vec3D,

    pub fn fromPoints(a: Vec3D, b: Vec3D, c: Vec3D) Plane {
        return Plane{
            .origin = a, // any point on the plane
            .normal = a.minus(b).crossProduct(b.minus(c)),
        };
    }
};
