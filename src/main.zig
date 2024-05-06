const std = @import("std");

const c = @cImport({
    @cInclude("md4c.h");
});

pub const TextType = enum(u32) {
    // Normal text.
    normal = 0,

    // NULL character. CommonMark requires replacing NULL character with
    // the replacement char U+FFFD, so this allows caller to do that easily.
    nullchar,

    // Line breaks.
    // Note these are not sent from blocks with verbatim output (MD_BLOCK_CODE
    // or MD_BLOCK_HTML). In such cases, '\n' is part of the text itself.
    br, // <br> (hard break)
    softbar, // '\n' in source text where it is not semantically meaningful (soft break)

    // Entity.
    // (a) Named entity, e.g. &nbsp;
    //     (Note MD4C does not have a list of known entities.
    //     Anything matching the regexp /&[A-Za-z][A-Za-z0-9]{1,47};/ is
    //     treated as a named entity.)
    // (b) Numerical entity, e.g. &#1234;
    // (c) Hexadecimal entity, e.g. &#x12AB;
    //
    // As MD4C is mostly encoding agnostic, application gets the verbatim
    // entity text into the MD_PARSER::text_callback().
    entity,

    // Text in a code block (inside MD_BLOCK_CODE) or inlined code (`code`).
    // If it is inside MD_BLOCK_CODE, it includes spaces for indentation and
    // '\n' for new lines. MD_TEXT_BR and MD_TEXT_SOFTBR are not sent for this
    // kind of text.
    code,

    // Text is a raw HTML. If it is contents of a raw HTML block (i.e. not
    // an inline raw HTML), then MD_TEXT_BR and MD_TEXT_SOFTBR are not used.
    // The text contains verbatim '\n' for the new lines.
    html,

    // Text is inside an equation. This is processed the same way as inlined code
    // spans (`code`).
    latex,
};

pub const Text = struct {
    text: []const u8,
    text_type: TextType,
};

const md4c_flag_t = packed struct(u32) {
    // In MD_TEXT_NORMAL, collapse non-trivial whitespace into single ' '
    collapsewhitespace: bool = true,

    // Do not require space in ATX headers ( ###header )
    permissiveatxheaders: bool = false,

    // Recognize URLs as autolinks even without '<', '>'
    permissiveurlautolinks: bool = false,

    // Recognize e-mails as autolinks even without '<', '>' and 'mailto:'
    permissiveemailautolinks: bool = false,

    // Disable indented code blocks. (Only fenced code works.)
    noindentedcodeblocks: bool = false,

    // Disable raw HTML blocks.
    nohtmlblocks: bool = false,

    // Disable raw HTML (inline).
    nohtmlspans: bool = false,

    // Enable tables extension.
    tables: bool = false,

    // Enable strikethrough extension.
    strikethrough: bool = false,

    // Enable WWW autolinks (even without any scheme prefix, if they begin with 'www.')
    permissivewwwautolinks: bool = false,

    // Enable task list extension.
    tasklists: bool = false,

    // Enable $ and $$ containing LaTeX equations.
    latexmathspans: bool = false,

    // Enable wiki links extension.
    wikilinks: bool = false,

    // Enable underline extension (and disables '_' for normal emphasis).
    underline: bool = false,

    // Force all soft breaks to act as hard breaks.
    hard_soft_breaks: bool = false,

    _: u17 = 0,
};

fn promoteTo(comptime T: type, ptr: ?*anyopaque) ?T {
    const p = ptr orelse return null;
    const t_ptr: *T = @alignCast(@ptrCast(p));
    return t_ptr.*;
}

pub const Attribute = struct {
    c_data: c.MD_ATTRIBUTE,
    index: usize = 0,

    pub fn next(a: *Attribute) ?Text {
        _ = a;
        return null;
    }
};

pub const Alignment = struct {};

pub const BlockInfo = union(enum(u32)) {
    // <body>...</body>
    doc: void,

    // <blockquote>...</blockquote>
    quote: void,

    // <ul>...</ul>
    // Detail: Structure MD_BLOCK_UL_DETAIL.
    ul: struct {
        // Non-zero if tight list, zero if loose.
        is_tight: bool,
        // Item bullet character in MarkDown source of the list, e.g. '-', '+', '*'.
        mark: u8,
    },

    // <ol>...</ol>
    // Detail: Structure MD_BLOCK_OL_DETAIL.
    ol: struct {
        // Start index of the ordered list
        start: usize,
        // Non-zero if tight list, zero if loose.
        is_tight: bool,
        // Item bullet character in MarkDown source of the list, e.g. '-', '+', '*'.
        mark_delimiter: u8,
    },

    // <li>...</li>
    // Detail: Structure MD_BLOCK_LI_DETAIL.
    li: struct {
        // Can be non-zero only with MD_FLAG_TASKLISTS
        is_task: bool,
        // If is_task, then one of 'x', 'X' or ' '. Undefined otherwise.
        task_mark: u8,
        // If is_task, then offset in the input of the char between '[' and ']'.
        task_mark_offset: usize,
    },

    // <hr>
    hr: void,

    // <h1>...</h1> (for levels up to 6)
    // Detail: Structure MD_BLOCK_H_DETAIL.
    h: struct {
        level: usize,
    },

    // <pre><code>...</code></pre>
    // Note the text lines within code blocks are terminated with '\n'
    // instead of explicit MD_TEXT_BR.
    code: struct {
        info: Attribute,
        lang: Attribute,
        fence_char: u8,
    },

    // Raw HTML block. This itself does not correspond to any particular HTML
    // tag. The contents of it _is_ raw HTML source intended to be put
    // in verbatim form to the HTML output.
    html: void,

    // <p>...</p>
    p: void,

    // <table>...</table> and its contents.
    // Detail: Structure MD_BLOCK_TABLE_DETAIL (for MD_BLOCK_TABLE),
    //         structure MD_BLOCK_TD_DETAIL (for MD_BLOCK_TH and MD_BLOCK_TD)
    // Note all of these are used only if extension MD_FLAG_TABLES is enabled.
    table: struct {
        column_count: usize,
        head_row_count: usize,
        body_row_count: usize,
    },
    thead: void,
    tbody: void,
    tr: void,
    th: struct {
        alignment: Alignment,
    },
    rd: struct {
        alignment: Alignment,
    },

    pub fn init_c(b: c.MD_BLOCKTYPE, details: ?*anyopaque) BlockInfo {
        const tag = std.meta.intToEnum(
            std.meta.Tag(BlockInfo),
            @as(u32, @intCast(b)),
        ) catch unreachable;

        switch (tag) {
            .ul => {
                const d = promoteTo(c.MD_BLOCK_UL_DETAIL, details).?;
                return .{ .ul = .{ .is_tight = d.is_tight != 0, .mark = d.mark } };
            },
            .ol => {
                const d = promoteTo(c.MD_BLOCK_OL_DETAIL, details).?;
                return .{ .ol = .{
                    .start = d.start,
                    .is_tight = d.is_tight != 0,
                    .mark_delimiter = d.mark_delimiter,
                } };
            },
            .li => {
                const d = promoteTo(c.MD_BLOCK_LI_DETAIL, details).?;
                return .{ .li = .{
                    .is_task = d.is_task != 0,
                    .task_mark = d.task_mark,
                    .task_mark_offset = d.task_mark_offset,
                } };
            },
            .h => {
                const d = promoteTo(c.MD_BLOCK_H_DETAIL, details).?;
                return .{ .h = .{
                    .level = d.level,
                } };
            },
            .code => {
                const d = promoteTo(c.MD_BLOCK_CODE_DETAIL, details).?;
                return .{ .code = .{
                    .info = .{ .c_data = d.info },
                    .lang = .{ .c_data = d.lang },
                    .fence_char = d.fence_char,
                } };
            },
            .table => {
                const d = promoteTo(c.MD_BLOCK_TABLE_DETAIL, details).?;
                return .{ .table = .{
                    .column_count = d.col_count,
                    .head_row_count = d.head_row_count,
                    .body_row_count = d.body_row_count,
                } };
            },
            .th => {
                return .{ .th = .{ .alignment = .{} } };
            },
            .rd => {
                return .{ .rd = .{ .alignment = .{} } };
            },
            inline else => |t| return @unionInit(BlockInfo, @tagName(t), {}),
        }
    }
};

pub const SpanInfo = union(enum(u32)) {
    // <em>...</em>
    em: void,

    // <strong>...</strong>
    strong: void,

    // <a href="xxx">...</a>
    // Detail: Structure MD_SPAN_A_DETAIL.
    a: struct {
        href: Attribute,
        title: Attribute,
        autolink: bool,
    },

    // <img src="xxx">...</a>
    // Detail: Structure MD_SPAN_IMG_DETAIL.
    // Note: Image text can contain nested spans and even nested images.
    // If rendered into ALT attribute of HTML <IMG> tag, it's responsibility
    // of the parser to deal with it.
    img: struct {
        src: Attribute,
        title: Attribute,
    },

    // <code>...</code>
    code: void,

    // <del>...</del>
    // Note: Recognized only when MD_FLAG_STRIKETHROUGH is enabled.
    del: void,

    // For recognizing inline ($) and display ($$) equations
    // Note: Recognized only when MD_FLAG_LATEXMATHSPANS is enabled.
    latexmath: void,
    latexmath_display: void,

    // Wiki links
    // Note: Recognized only when MD_FLAG_WIKILINKS is enabled.
    wikilink: struct {
        target: Attribute,
    },

    // <u>...</u>
    // Note: Recognized only when MD_FLAG_UNDERLINE is enabled.
    u: void,

    pub fn init_c(b: c.MD_SPANTYPE, details: ?*anyopaque) SpanInfo {
        const tag = std.meta.intToEnum(
            std.meta.Tag(SpanInfo),
            @as(u32, @intCast(b)),
        ) catch unreachable;

        switch (tag) {
            .a => {
                const d = promoteTo(c.MD_SPAN_A_DETAIL, details).?;
                return .{ .a = .{
                    .href = .{ .c_data = d.href },
                    .title = .{ .c_data = d.title },
                    .autolink = d.is_autolink != 0,
                } };
            },
            .img => {
                const d = promoteTo(c.MD_SPAN_IMG_DETAIL, details).?;
                return .{ .img = .{
                    .src = .{ .c_data = d.src },
                    .title = .{ .c_data = d.title },
                } };
            },
            .wikilink => {
                const d = promoteTo(c.MD_SPAN_WIKILINK_DETAIL, details).?;
                return .{ .wikilink = .{
                    .target = .{ .c_data = d.target },
                } };
            },
            inline else => |t| return @unionInit(SpanInfo, @tagName(t), {}),
        }
    }
};

/// Compile time wrapper of md4c
pub fn MD4CParser(comptime Implementation: type) type {
    return struct {
        const Self = @This();

        pub const Options = struct {
            flags: md4c_flag_t = .{},
        };

        c_parser: c.MD_PARSER,
        implementation: Implementation,

        fn enter_block(
            block_type: c.MD_BLOCKTYPE,
            details: ?*anyopaque,
            data: ?*anyopaque,
        ) callconv(.C) c_int {
            const _field_name = "enterBlock";
            if (@hasDecl(Implementation, _field_name)) {
                const block = BlockInfo.init_c(block_type, details);
                const impl: *Implementation = @alignCast(@ptrCast(data.?));
                @field(Implementation, _field_name)(
                    impl,
                    block,
                ) catch return 1;
            } else @compileError("Missing field: " ++ _field_name);
            return 0;
        }

        fn leave_block(
            block_type: c.MD_BLOCKTYPE,
            details: ?*anyopaque,
            data: ?*anyopaque,
        ) callconv(.C) c_int {
            const _field_name = "leaveBlock";
            if (@hasDecl(Implementation, _field_name)) {
                const block = BlockInfo.init_c(block_type, details);
                const impl: *Implementation = @alignCast(@ptrCast(data.?));
                @field(Implementation, _field_name)(
                    impl,
                    block,
                ) catch return 1;
            } else @compileError("Missing field: " ++ _field_name);
            return 0;
        }

        fn enter_span(
            span_type: c.MD_SPANTYPE,
            details: ?*anyopaque,
            data: ?*anyopaque,
        ) callconv(.C) c_int {
            const _field_name = "enterSpan";
            if (@hasDecl(Implementation, _field_name)) {
                const span = SpanInfo.init_c(span_type, details);
                const impl: *Implementation = @alignCast(@ptrCast(data.?));
                @field(Implementation, _field_name)(
                    impl,
                    span,
                ) catch return 1;
            } else @compileError("Missing field: " ++ _field_name);
            return 0;
        }

        fn leave_span(
            span_type: c.MD_SPANTYPE,
            details: ?*anyopaque,
            data: ?*anyopaque,
        ) callconv(.C) c_int {
            const _field_name = "leaveSpan";
            if (@hasDecl(Implementation, _field_name)) {
                const span = SpanInfo.init_c(span_type, details);
                const impl: *Implementation = @alignCast(@ptrCast(data.?));
                @field(Implementation, _field_name)(
                    impl,
                    span,
                ) catch return 1;
            } else @compileError("Missing field: " ++ _field_name);
            return 0;
        }

        fn text_callback(
            t: c.MD_TEXTTYPE,
            ptr: [*c]const c.MD_CHAR,
            len: c.MD_SIZE,
            data: ?*anyopaque,
        ) callconv(.C) c_int {
            const _field_name = "textCallback";
            if (@hasDecl(Implementation, _field_name)) {
                const impl: *Implementation = @alignCast(@ptrCast(data.?));
                @field(Implementation, _field_name)(impl, Text{
                    .text = ptr[0..len],
                    .text_type = @as(TextType, @enumFromInt(t)),
                }) catch return 1;
            } else @compileError("Missing field: " ++ _field_name);
            return 0;
        }

        fn promoteSelf(ptr: ?*anyopaque) *Self {
            const p = ptr.?;
            return @alignCast(@ptrCast(p));
        }

        /// Initialize a parser.
        pub fn init(impl: Implementation, opts: Options) Self {
            const parser: c.MD_PARSER = .{
                .abi_version = 0,
                .flags = @as(c_uint, @bitCast(opts.flags)),
                .enter_block = Self.enter_block,
                .leave_block = Self.leave_block,
                .enter_span = Self.enter_span,
                .leave_span = Self.leave_span,
                .text = Self.text_callback,
            };
            return .{
                .c_parser = parser,
                .implementation = impl,
            };
        }

        /// Parse a given text
        pub fn parse(p: *Self, text: []const u8) !void {
            const errno = c.md_parse(
                text.ptr,
                @intCast(text.len),
                &p.c_parser,
                @alignCast(@ptrCast(&p.implementation)),
            );

            switch (errno) {
                0 => return,
                else => return error.MD4CUnknownError,
            }
        }
    };
}
