const Plane = @import("plane.zig").Plane;

const Vec3D = @import("vec3d.zig").Vec3D;
const scalar = @import("scalar.zig");

const Scalar = scalar.Scalar;
const planck_distance = scalar.planck_distance;

pub const Ray = struct {
    pos: Vec3D,
    dir: Vec3D,

    // taken from
    // https://davidjcobb.github.io/articles/ray-plane-intersection
    pub fn distance(self: Ray, plane: Plane) ?Scalar {
        const denom = plane.normal.dotProduct(self.dir);
        if (@abs(denom) > planck_distance) {
            const dist = plane.origin.minus(self.pos).dotProduct(plane.normal) / denom;
            if (dist > 0) {
                return dist;
            }
        }
        return null;
    }

    pub fn intersectionPoint(self: Ray, plane: Plane) ?Vec3D {
        if (self.distance(plane)) |dist|
            return self.pos.plus(self.dir.timesScalar(dist));
        return null;
    }
};
