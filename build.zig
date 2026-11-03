const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const lib_names = [_][]const u8{
        "terminal",
        "braille_display",
        "vec3d",
        "scalar",
        "angle",
        "camera",
        "plane",
        "cube",
        "world",
        "ray",
    };

    inline for (lib_names) |lib_name| {
        const lib = b.addLibrary(.{
            .name = lib_name,
            .linkage = .static,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/" ++ lib_name ++ ".zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.linkLibrary(lib);
        b.installArtifact(lib);
    }

    b.installArtifact(exe);
}
