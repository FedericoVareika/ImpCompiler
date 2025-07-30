const std = @import("std");

pub const TokenType = enum {
    Illegal, 
    EOF, 

    // Identifiers + Constructors
    Identifier, 
    // Constructor,  // Cannot determine if its an id or constructor in lexer
    
    // Operators
    Assign, 
    Arrow, 

    // Delimiters
    Semicolon, 
    Comma, 

    LeftParen, 
    RightParen, 
    LeftBracket, 
    RightBracket, 
    LeftCurlyBracket, 
    RightCurlyBracket, 

    // Keywords
    Local,

    Case, 
    CaseOf, 

    While, 
    WhileIs, 

    DefineFunction, 
    FunctionReturns, 
    CallOn, 


    const multiCharacterLookup = std.StaticStringMap(TokenType).initComptime(.{
        .{ ":=", .Assign }, 
        .{ "->", .Arrow }, 
        .{ "local", .Local }, 
        .{ "case", .Case }, 
        .{ "of", .CaseOf }, 
        .{ "while", .While }, 
        .{ "is", .WhileIs }, 
        .{ "def", .DefineFunction }, 
        .{ "returns", .FunctionReturns }, 
        .{ "on", .CallOn }, 
    });

    pub fn parse(str: []const u8) ?TokenType {
        return multiCharacterLookup.get(str);
    }

    pub fn format(
        self: TokenType,
        comptime fmt: []const u8, 
        options: std.fmt.FormatOptions,
        writer: anytype,     
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s}", .{ switch (self) {
            .Illegal => "ILLEGAL",
            .EOF => "EOF",
            .Identifier => "identifier", 
            .Assign => ":=", 
            .Arrow => "->", 
            .Semicolon => ";", 
            .Comma => ",", 
            .LeftParen => "(", 
            .RightParen => ")", 
            .LeftBracket => "[", 
            .RightBracket => "]", 
            .LeftCurlyBracket => "{", 
            .RightCurlyBracket => "}", 
            .Local => "local",
            .Case => "case", 
            .CaseOf => "of", 
            .While => "while", 
            .WhileIs => "is", 
            .DefineFunction => "def", 
            .FunctionReturns => "returns", 
            .CallOn => "on", 
        }});
    }
};

pub const Token = struct {
    pub const literalLength = 100;
    pub const LiteralType = [literalLength:0]u8;

    type: TokenType = TokenType.Illegal, 
    literal: LiteralType = std.mem.zeroes(LiteralType),
    position: u32 = 0,
};
