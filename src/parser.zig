// load `ini` namespace
const std  = @import("std");
const Lexer = @import("./lexer.zig").Lexer;
const ini = @import("./ini.zig");

fn is_ws(char: u8) bool {
    return char == ' ' or char == '\t';
}
fn is_newline(chars: []u8) bool {
    return (char[0] == '\r' and char[1] == '\n') or chars[0] == '\n';
}


const TokenType = enum {
    plus,
    minus,
    comment,
    newline,
    whitespace,
    colon,
    comma,
    dot,
    leftBrace,
    rightBrace,
    leftBracket,
    rightBracket,
    quotedString,
    keyLike,
    keyValSep,
};

const Token = struct {
    span: []const u8 = undefined, // slice of content
    tok_type: TokenType,
};


fn is_keylike_char(char: u8) bool {
    return (char >= '0' and char <= '9') or (char >= 'A' and char <= 'Z') or (char >= 'a' and char <= 'z') or char == '_' or char == '-';
}

const Tokenizer = struct {
    const Self = @This();
    lexer: Lexer,
    start_token: usize = 0,
    empty: bool = false,
    alloc: *std.mem.Allocator = undefined,

    pub fn init(alloc: *std.mem.Allocator, content: []const u8) Self {
        return .{
            .lexer = Lexer.init(content),
            .alloc = alloc,
        };
    }

    fn createToken(self: *Self, tok_type: TokenType) !Token {
        return .{ .span = try std.mem.dupe(u8, self.lexer.sliceFrom(self.start_token)), .tok_type = tok_type };
    }

    pub fn getToken(self: *Self) !?Token {
        if ( self.lexer.isEof() ) {
            if ( self.empty ) { 
                return null; 
            } else {
                self.empty = true;
                return Token { .span = "", .tok_type = .eof };
            }
        } 
        self.start_token = self.lexer.cursor();
        switch ( self.lexer.peekByte() ) {
            '\n' => { self.lexer.consume(); return self.createToken(.newline); },
            '\r' => { if ( self.lexer.matchAndConsumeSlice("\r\n")) { return self.createToken(.newline); } else { return self.createToken(.whitespace); } },
            '#'  => { self.lexer.skipLine(); return self.createToken(.comment); },
            '='  => { self.lexer.consume(); return self.createToken(.keyValSep); },
            '.'  => { self.lexer.consume(); return self.createToken(.dot); },
            ':'  => { self.lexer.consume(); return self.createToken(.colon); },
            ','  => { self.lexer.consume(); return self.createToken(.comma); },
            '+'  => { self.lexer.consume(); return self.createToken(.plus); },
            '-'  => { self.lexer.consume(); return self.createToken(.minus); },
            '}'  => { self.lexer.consume(); return self.createToken(.leftBrace); },
            '{'  => { self.lexer.consume(); return self.createToken(.rightBrace); },
            '['  => { self.lexer.consume(); return self.createToken(.leftBracket); },
            ']'  => { self.lexer.consume(); return self.createToken(.rightBracket); },
            ' ', '\t'  => {         
                self.lexer.skipWhitespace();
                return self.createToken(.whitespace);
            },
            '\'', '\"' => |quote| {
                self.lexer.consume();
                while ( !self.lexer.isEof() and self.lexer.peekByte() != quote ) {
                    if ( self.lexer.peekByte() == '\\' and self.lexer.peekByteForward(1) == quote ) {
                        self.lexer.consumeMany(2);
                    } else {
                        self.lexer.consume();
                    }
                }
                if ( self.lexer.isEof() ) {
                    self.empty = true; 
                    return Token { .span = "", .tok_type = .eof }; 
                }

                self.lexer.consume();
                return self.createToken(.quotedString);
            },
            else => | ch | {
                if ( is_keylike_char(ch) ) {
                    while ( !self.lexer.isEof() and is_keylike_char(self.lexer.peekByte())) {
                        self.lexer.consume();
                    }
                    return self.createToken(.keyLike);
                }
            }
        }
    }

    pub fn expectToken(self: *Self, tok_type: TokenType) !Token {
        if ( self.getToken() ) | tok | {
            if ( tok.tok_type == tok_type ) return tok;
        } return error.unexpectedToken;
    }
};


pub const IniParser = struct {
    const Self = @This();
    pub const IniParserError = error {
        unexpectedCharacter,
        unexpectedToken,
    };
    
    // no default values -- it requires that struct should be created with `init`&`deinit` pair
    alloc: *std.mem.Allocator,
    tokenizer: Tokenizer,
    line_number: usize = 0,
    root: *ini.Table = undefined,
    context: *ini.Table = undefined,

    pub fn init(alloc: *std.mem.Allocator, content: []const u8) !Self {
        return .{
            .alloc = alloc,
            .tokenizer = Tokenizer.init(content),
        };
    }

    pub fn deinit(self: *Self) void {
        // deinitialization code
    }

    /// Main parsing entrypoint. 
    pub fn parse(self: *Self, root_context: *ini.Table) !void {
        self.root = root_context;
        self.context = root_context;
        while ( self.tokenizer.getToken() ) | token | {
            switch ( token.tok_type ) {
                .comment, .whitespace => { continue; },
                .newline => {
                    self.line_number += 1;
                    continue;
                },
                .leftBracket => { 
                    const is_array_path = self.tokenizer.lexer.match('[');
                    if ( is_array_path ) self.tokenizer.getToken(); // skip [[
                    try self._parseDottedPath(self.root);
                },
                .keyLike, .quotedString => {
                    self.tokenizer.lexer.skipWhitespace();
                    self.tokenizer.expectToken(.keyValSep);
                    self.tokenizer.lexer.skipWhitespace();
                    try self.root.entries.put(key.span, try self._parseValue());
                },
                else => {
                    std.log.err("[TOML] Parsing error on line: {d} on token: {any}", .{ self.line_number, token });
                    return error.unexpectedToken;
                }
            }
        }
        return;
    }

    /// recursively traverse dotted path 
    fn _parseDottedPath(self: *Self, ctx: *ini.Table) void {
        const key_token = self.tokenizer.expectToken(.keyLike);
        if ( self.tokenizer.lexer.match('.') ) {
            var table = try self._createTable();
            try ctx.entries.put(key_token.span, .{ .table = table });
            return self._parseDottedPath(table);
        } else if ( self.tokenizer.lexer.matchAndConsumeSlice("]]") ) {
            // end of header of array
            var array = try self._createArray();
            var final_section = try self._createTable();
            try array.entries.append(.{ .table = final_section });
            self.context = final_section;
            try ctx.entries.put(key_token.span, .{ .array = array });
        } else if ( self.tokenizer.lexer.matchAndConsume(']') ) {
            var final_section = try self._createTable();
            self.context = final_section;
            try ctx.entries.put(key_token.span, .{ .table = final_section });
        }
    }

    fn _createArray(self: *Self) !*ini.Array {
        var array: *ini.Array = try self.alloc.create(ini.Array);
        array.* = ini.Array.init(self.alloc);
        return array;
    }
    
    fn _createTable(self: *Self) !*ini.Table {
        var table: *ini.Table = try self.alloc.create(ini.Table);
        table.* = ini.Table.init(self.alloc);
        return table;
    }

    fn _parseValue(self: *Self) !ini.Entry {
        const token = (try self.tokenizer.getToken()).?;
        switch ( token.tok_type ) {
            .quotedString => { 
                return .{ .string = token.span };
            },
            .boolean => { 
                if ( token.span[0] == 't' ) {
                    return .{ .boolean = true };
                } else {
                    return .{ .boolean = false };
                }
            },
            .double => {
                return try self._parseNumber(token);
            },
            .leftBrace => {
                return try self._parseInlineTable();
            },
            .leftBracket => {
                return try self._parseInlineArray();
            }
        }
        // numbers 
        // boolean
        // datetime
        // inline-array
        // inline-Table
    }

    fn _parseInlineArray(self: *Self, array: *ini.Array) !void {
        // [
        try self._parseValue();
        self.tokenizer.lexer.skipWhitespace();
        if (self.tokenizer.lexer.matchAndConsume(',')) { 
            try array.entries.append(try self._parseValue());
        } else if ( self.tokenizer.lexer.matchAndConsume(']') ) {
            return;
        }
    }

    fn _parseInlineTable(self: *Self) !void {
        // {
        self.tokenizer._parseKeyVal();
    }
    
};