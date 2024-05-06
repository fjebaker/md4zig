# md4zig

A Zig wrapper of [md4c](https://github.com/mity/md4c) for parsing Markdown.

Exposes a single function that puts a parser type together from comptime-known Zig functions. The generalisation to using vtables is left as an exercise to the user.

## Usage

```zig
const Impl = struct {
    fn enterBlock(_: *Impl, block: BlockInfo) !void {
        std.debug.print(">> {any}\n", .{block});
    }
    fn leaveBlock(_: *Impl, block: BlockInfo) !void {
        std.debug.print("<< {any}\n", .{block});
    }
    fn enterSpan(_: *Impl, span: SpanInfo) !void {
        std.debug.print(">> {any}\n", .{span});
    }
    fn leaveSpan(_: *Impl, span: SpanInfo) !void {
        std.debug.print("<< {any}\n", .{span});
    }
    fn textCallback(_: *Impl, text: Text) !void {
        std.debug.print("   {any}\n", .{text});
    }
};

pub fn main() !void {
    const impl: Impl = .{};

    var parser = MD4CParser(Impl).init(impl .{});
    try parser.parse("# Hello World\nHow are *you*!");
}

```

This will then something like output:

```
>> main.BlockInfo{ .doc = void }
>> main.BlockInfo{ .h = main.BlockInfo.BlockInfo__struct_7312{ .level = 1 } }
   main.Text{ .text = { 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100 }, .text_type = main.TextType.normal }
<< main.BlockInfo{ .h = main.BlockInfo.BlockInfo__struct_7312{ .level = 1 } }
>> main.BlockInfo{ .p = void }
   main.Text{ .text = { 72, 111, 119, 32, 97, 114, 101, 32 }, .text_type = main.TextType.normal }
>> main.SpanInfo{ .em = void }
   main.Text{ .text = { 121, 111, 117 }, .text_type = main.TextType.normal }
<< main.SpanInfo{ .em = void }
<< main.BlockInfo{ .p = void }
<< main.BlockInfo{ .doc = void }
```
