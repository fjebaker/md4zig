# md4zig

A Zig wrapper of [md4c](https://github.com/mity/md4c) for parsing Markdown.

Exposes a single function that puts a parser type together from comptime-known Zig functions. The generalisation to using vtables is left as an exercise to the user.

## Usage

```zig
const std = @import("std");

const md4zig = @import("md4zig");

const MD4CParser = md4zig.MD4CParser;
const BlockInfo = md4zig.BlockInfo;
const SpanInfo = md4zig.SpanInfo;
const Text = md4zig.Text;

const Impl = struct {
    pub fn enterBlock(_: *Impl, block: BlockInfo) !void {
        std.debug.print(">> {any}\n", .{block});
    }
    pub fn leaveBlock(_: *Impl, block: BlockInfo) !void {
        std.debug.print("<< {any}\n", .{block});
    }
    pub fn enterSpan(_: *Impl, span: SpanInfo) !void {
        std.debug.print(">> {any}\n", .{span});
    }
    pub fn leaveSpan(_: *Impl, span: SpanInfo) !void {
        std.debug.print("<< {any}\n", .{span});
    }
    pub fn textCallback(_: *Impl, text: Text) !void {
        std.debug.print("   {any}\n", .{text});
    }
};

pub fn main() !void {
    const impl: Impl = .{};

    var parser = MD4CParser(Impl).init(impl, .{});
    try parser.parse("# Hello World\nHow are *you*!");
}
```

This will then something like output:

```
>> main.BlockInfo{ .doc = void }
>> main.BlockInfo{ .h = main.BlockInfo.BlockInfo__struct_7319{ .level = 1 } }
   main.Text{ .text = { 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100 }, .text_type = main.TextType.normal }
<< main.BlockInfo{ .h = main.BlockInfo.BlockInfo__struct_7319{ .level = 1 } }
>> main.BlockInfo{ .p = void }
   main.Text{ .text = { 72, 111, 119, 32, 97, 114, 101, 32 }, .text_type = main.TextType.normal }
>> main.SpanInfo{ .em = void }
   main.Text{ .text = { 121, 111, 117 }, .text_type = main.TextType.normal }
<< main.SpanInfo{ .em = void }
   main.Text{ .text = { 33 }, .text_type = main.TextType.normal }
<< main.BlockInfo{ .p = void }
<< main.BlockInfo{ .doc = void }
```

## Including in a project

Use the Zig package manager

```bash
zig fetch --save=md4zig https://github.com/fjebaker/md4zig/archive/master.tar.gz
```

Then include the module in your `build.zig` for your target:

```zig
const md4zig = b.dependency(
    "md4zig",
    .{ .optimize = optimize, .target = target },
).module("md4zig");

// ...

exe.root_module.addImport("md4zig", md4zig);
```
