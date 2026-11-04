const Plane = @import("plane.zig").Plane;

const Vec3D = @import("vec3d.zig").Vec3D;
const Scalar = @import("scalar.zig").Scalar;
const Angle = @import("angle.zig").Angle;

pub const Camera = struct {
    pos: Vec3D,
    dir: Vec3D,

    pub fn moveForward(self: *Camera, dist: Scalar) void {
        var dir: Vec3D = self.dir;
        dir.z = 0;
        dir = dir.normalize();
        self.pos = self.pos.plus(dir.timesScalar(dist));
    }

    pub fn moveRight(self: *Camera, dist: Scalar) void {
        self.pos = self.pos.plus(self.dir.right().timesScalar(dist));
    }

    pub fn lookDown(self: *Camera, angle: Angle) void {
        self.dir = self.dir.rotateDown(angle);
    }

    pub fn lookRight(self: *Camera, angle: Angle) void {
        self.dir = self.dir.rotateRight(angle);
    }
};
