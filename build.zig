const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const md4c_dep = b.dependency("md4c", .{
        .target = target,
        .optimize = optimize,
        .@"md4c-shared" = false,
    });

    const md4c = md4c_dep.artifact("md4c");

    const mod = b.addModule("md4zig", .{
        .root_source_file = b.path("src/main.zig"),
        .link_libc = true,
    });
    mod.linkLibrary(md4c);

    const lib = b.addSharedLibrary(.{
        .name = "md4zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    lib.linkLibrary(md4c);

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_unit_tests.linkLibC();
    lib_unit_tests.linkLibrary(md4c);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
