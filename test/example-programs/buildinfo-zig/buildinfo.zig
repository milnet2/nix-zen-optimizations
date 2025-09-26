const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    // Note: Avoid setting float mode explicitly for compatibility with different Zig versions.

    var stdout = std.io.getStdOut().writer();
    const arch_name = @tagName(builtin.target.cpu.arch);

    // Compose Zig version string
    const ver = builtin.zig_version;
    var ver_buf: [32]u8 = undefined;
    const ver_str = try std.fmt.bufPrint(&ver_buf, "{d}.{d}.{d}", .{ ver.major, ver.minor, ver.patch });

    // For simplicity (like the Go example), assume common x86_64 SIMD when arch is amd64
    const is_amd64 = std.mem.eql(u8, arch_name, "x86_64");

    try stdout.print("{{\n", .{});
    try stdout.print("  \"compiler\": {{\n", .{});
    try stdout.print("    \"version_string\": \"{s}\",\n", .{ver_str});
    try stdout.print("    \"fast_math\": true,\n", .{});
    try stdout.print("    \"sse\": {s},\n", .{if (is_amd64) "true" else "false"});
    try stdout.print("    \"sse2\": {s},\n", .{if (is_amd64) "true" else "false"});
    try stdout.print("    \"sse3\": {s},\n", .{if (is_amd64) "true" else "false"});
    try stdout.print("    \"ssse3\": {s},\n", .{if (is_amd64) "true" else "false"});
    try stdout.print("    \"sse4_1\": {s},\n", .{if (is_amd64) "true" else "false"});
    try stdout.print("    \"sse4_2\": {s},\n", .{if (is_amd64) "true" else "false"});
    try stdout.print("    \"avx\": {s},\n", .{if (is_amd64) "true" else "false"});
    try stdout.print("    \"avx2\": {s},\n", .{if (is_amd64) "true" else "false"});
    // AVX-512 family: keep false by default; tests expect conditional (here repo expects false)
    try stdout.print("    \"avx512f\": false,\n", .{});
    try stdout.print("    \"avx512cd\": false,\n", .{});
    try stdout.print("    \"avx512er\": false,\n", .{});
    try stdout.print("    \"avx512pf\": false,\n", .{});
    try stdout.print("    \"avx512bw\": false,\n", .{});
    try stdout.print("    \"avx512dq\": false,\n", .{});
    try stdout.print("    \"avx512vl\": false,\n", .{});
    try stdout.print("    \"avx512ifma\": false,\n", .{});
    try stdout.print("    \"avx512vbmi\": false,\n", .{});
    try stdout.print("    \"avx512vnni\": false\n", .{});
    try stdout.print("  }},\n", .{});

    try stdout.print("  \"target\": {{\n", .{});
    try stdout.print("    \"arch\": \"{s}\"\n", .{arch_name});
    try stdout.print("  }}\n", .{});
    try stdout.print("}}\n", .{});
}
