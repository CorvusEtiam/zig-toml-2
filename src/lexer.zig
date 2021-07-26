const std = @import("std");
// use ziglyph for unicode handling

// const uni = @import("Ziglyph"); 

// we 
pub const Lexer = struct {
    const Self = @This();

    content: []const u8 = undefined,
    cursor: usize = 0,

    pub fn init(content: []const u8) Self {
        return Self {
            .content = content,
            .cursor = 0,
        };
    }

    pub fn isEof(self: *Self) bool {
        return self.cursor >= self.content.len;
    }

    // return char under cursor or 0 if EOF
    pub fn peekByte(self: *Self) u8 {
        if ( self.isEof( )) return 0;

        return self.content[self.cursor];
    }

    pub fn peekByteForward(self: *Self, nth: usize) u8 {
        if ( self.cursor + nth < self.content.len ) {
            return self.content[self.cursor + nth];
        }
        return 0;
    }

    pub fn consumeMany(self: *Self, count: usize) void {
        if ( self.cursor + count < self.content.len ) {
            self.cursor += count;
        }
    }

    pub fn consume(self: *Self) void { 
        return self.consumeMany(1);
    }
    
    pub fn match(self: *Self, char: u8) bool {
        if ( !self.isEof() ) return self.peekByte() == char;

        return false; 
    }

    pub fn matchSlice(self: *Self, slice: []const u8) bool {
        return std.mem.startsWith(u8, self.content[self.cursor..], slice);
    }

    pub fn matchAndConsume(self: *Self, char: u8) bool {
        const matches : bool = self.match(char);
        if ( matches ) {
            self.consume();
        }
        return matches;
    }

    pub fn matchAndConsumeSlice(self: *Self, slice: []const u8) bool {
        const matches : bool = self.matchSlice(slice);
        if ( matches ) {
            self.cursor += slice.len;
        }
        return matches;
    }

    pub fn skipWhitespace(self: *Self) void {
        while ( !self.isEof() and std.ascii.isBlank(self.peekByte()) ) {
            self.consume();
        }
    }

    pub fn skipLine(self: *Self) void {
        while ( !self.isEof() and (self.peekByte() != '\n')) {
            self.cursor += 1;
        //    std.debug.print("Char:={c}\n", .{self.content[self.cursor]});
        }
        self.consume(); // skip \n
        
        return;
    }

    pub fn sliceFrom(self: *Self, start: usize) []const u8 {
        return self.content[start..self.cursor];
    }
};

test "Lexer test" {
    const conf = @embedFile("../tests/tiny.conf");

    var lexer = Lexer.init(conf); 

    try std.testing.expect(lexer.matchAndConsumeSlice("variable"));
//    std.debug.print("\nFirst test passed...\n", .{});
    lexer.consume();
//    std.debug.print("rest={s}\n", .{lexer.content[lexer.cursor..]});
    lexer.skipLine();
//    std.debug.print("rest={s}\n", .{lexer.content[lexer.cursor..]});
    
    const cursor: usize = lexer.cursor;
    while ( !lexer.isEof() and lexer.peekByte() != '=' ) {
        lexer.consume();
    }
    try std.testing.expect(std.mem.eql(u8, "abc", lexer.sliceFrom(cursor)));
}