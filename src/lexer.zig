const std = @import("std");
const token = @import("token.zig");

pub const Lexer = struct {
    input: []const u8,
    position: u32 = 0,
    readPosition: u32 = 0,
    value: u8 = 0,

    pub fn init(input: []const u8) Lexer {
        var l: Lexer = .{ .input = input };
        l.readChar();
        return l;
    }

    pub fn readChar(self: *Lexer) void {
        if (self.readPosition >= self.input.len) {
            self.value = 0;
        } else {
            self.value = self.input[self.readPosition];
        }

        self.position = self.readPosition;
        self.readPosition += 1;
    }

    pub fn peekChar(self: *Lexer) u8 {
        if (self.readPosition >= self.input.len) {
            return 0;
        } else {
            return self.input[self.readPosition];
        }
    }

    pub fn nextToken(self: *Lexer) token.Token {

        while (std.ascii.isWhitespace(self.value)) self.readChar();

        var t: token.Token = .{
            .type = token.TokenType.EOF,
            .position = self.position,
        };
        
        if (self.value == 0) return t;

        defer self.readChar();

        switch (self.value) {
            ';' => {
                t.type = token.TokenType.Semicolon;
                t.literal[0] = self.value;
            },
            ',' => {
                t.type = token.TokenType.Comma;
                t.literal[0] = self.value;
            },
            '(' => {
                t.type = token.TokenType.LeftParen;
                t.literal[0] = self.value;
            },
            ')' => {
                t.type = token.TokenType.RightParen;
                t.literal[0] = self.value;
            },
            '[' => {
                t.type = token.TokenType.LeftBracket;
                t.literal[0] = self.value;
            },
            ']' => {
                t.type = token.TokenType.RightBracket;
                t.literal[0] = self.value;
            },
            '{' => {
                t.type = token.TokenType.LeftCurlyBracket;
                t.literal[0] = self.value;
            },
            '}' => {
                t.type = token.TokenType.RightCurlyBracket;
                t.literal[0] = self.value;
            },
            else => {
                t.type = token.TokenType.Illegal;
                if (isWordStart(self.value)) {
                    if (std.ascii.isAlphanumeric(self.value))
                        t.type = token.TokenType.Identifier;

                    const word = self.readWord();
                    
                    if (token.TokenType.parse(word)) |tokType| {
                        t.type = tokType;
                    }

                    std.mem.copyForwards(u8, &t.literal, word);
                } 
            },
        }
        return t;
    }

    fn readWord(self: *Lexer) []const u8 {
        const start = self.position;
        if (!isWordStart(self.value)) unreachable;
        self.readChar();
        while (isWordMiddle(self.value)) {
            self.readChar();
        }

        const end = self.position;
        self.position -= 1;
        self.readPosition -= 1;
        return self.input[start..end];
    }


    fn isWordStart(char: u8) bool {
        return isMulticharacterSymbolStart(char)
            or std.ascii.isAlphabetic(char);
    }

    fn isWordMiddle(char: u8) bool {
        return (isMulticharacterSymbolBody(char) 
            or std.ascii.isAlphanumeric(char)
            or char == '\'')
            and !isImportantSymbol(char) and char != 0;
    }

    fn isImportantSymbol(char: u8) bool {
        return switch (char) {
            ';', ',', '(', ')', '[', ']', '{', '}' => true, 
            else => false,
        };
    }

    fn isMulticharacterSymbolStart(char: u8) bool {
        return switch (char) {
            ':', '-' => true, 
            else => false,
        }; 
    }

    fn isMulticharacterSymbolBody(char: u8) bool {
        return switch (char) {
            '=', '>' => true, 
            else => false,
        }; 
    }

    pub fn getLineCoords(
        self: Lexer,
        position: u32,
    ) struct { u32, u32 } {
        std.debug.assert(position >= 0 and position < self.input.len);
        var start = position;        
        while (start > 0 and self.input[start - 1] != '\n') {
            start -= 1;
        }

        var end = position;        
        while (end < self.input.len and self.input[end] != '\n') {
            end += 1;
        }

        return .{ start, end };
    } 
};

const print = std.debug.print;

test "add test" {
    const input =
        \\def add(a,b) returns x {
        \\    x := b;
        \\    while a is [
        \\        S -> [a'] {
        \\            a, x := a', S [x];
        \\        }, 
        \\    ];
        \\} 
    ;

    var l: Lexer = .{ .input = input };
    l.readChar();

    var i: u32 = 0;
    while (l.value != 0) : (i += 1) {
        const t = l.nextToken();
        // print(
        //     "type: {s}, literal: {s}\n",
        //     .{
        //         t.type,
        //         t.literal,
        //     },
        // );
        _ = t;
    }
}
