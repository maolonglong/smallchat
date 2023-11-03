const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const strip = b.option(bool, "strip", "Omit debug symbols") orelse false;

    const exe = b.addExecutable(.{
        .name = "smallchat",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .single_threaded = true,
    });
    exe.strip = strip;
    const evio = b.dependency("evio", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("evio", evio.module("evio"));
    const mimalloc = b.dependency("mimalloc", .{
        .target = target,
        .optimize = optimize,
        .secure = true,
    });
    exe.linkLibrary(mimalloc.artifact("mimalloc"));
    exe.addModule("mimalloc", mimalloc.module("mimalloc"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
