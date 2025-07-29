const std = @import("std");
const token = @import("token.zig");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");
const TokenType = token.TokenType;

const printf = @cImport("stdio.h").printf;

pub const ParseError = union(enum) {
    UnexpectedToken: struct {
        position: u32,
        line: []const u8,
        expectedToken: TokenType,
        actualToken: TokenType, 
    },

    pub fn format(
        self: ParseError,
        comptime fmt: []const u8, 
        options: std.fmt.FormatOptions,
        writer: anytype,     
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .UnexpectedToken => |err| {
                const errMsg = 
                    \\ error: expected '{[expectedToken]s}', found '{[actualToken]s}'
                    \\    {[line]s}
                    \\    {[carat]s:[position]}
                ;
                try writer.print(errMsg, .{
                    .expectedToken = std.enums.tagName(TokenType, err.expectedToken) orelse "NONE",
                    .actualToken = std.enums.tagName(TokenType, err.actualToken) orelse "NONE",
                    .line = err.line, 
                    .position = err.position,
                    .carat = "^",
                });
            }
        }
    }
};

pub const Parser = struct {

    lexer: *lexer.Lexer,
    curToken: token.Token = .{},
    peekToken: token.Token = .{},

    errors: std.ArrayList([]const u8),

    pub fn nextToken(self: *Parser) void {
        self.curToken = self.peekToken;
        self.peekToken = self.lexer.nextToken();
    }

    pub fn init(l: *lexer.Lexer) Parser {
        var p: Parser = .{
            .lexer = l,
            .errors = std.ArrayList([]const u8).init(std.heap.page_allocator),
        };
        p.nextToken();
        p.nextToken();
        return p;
    }

    fn unexpectedTokenError(
        self: *Parser,
        actualToken: token.Token,
        expectedTokenType: TokenType,
    ) void {
        const errorMsg = std.fmt.allocPrint(
            std.heap.page_allocator,
            "ERROR: expected {s}, found {s}",
            .{ 
                std.enums.tagName(token.TokenType, expectedTokenType) orelse "NONE",
                std.enums.tagName(token.TokenType, actualToken.type) orelse "NONE",
            },
        ) catch {
            std.debug.panic("Allocation error\n", .{});
        };

        const start, const end = self.lexer.getLineCoords(actualToken.position);
        self.errors.appendSlice(&[_][]const u8{
            errorMsg,
            self.lexer.input[start..end],
        }) catch {
            std.debug.panic("Could not append error\n", .{});
        };
    }

    fn expectCurToken(self: *Parser, tokType: TokenType) bool {
        if (self.curToken.type != tokType) {
            self.unexpectedTokenError(self.curToken, tokType);
            return false;
        }

        return true;
    }

    fn expectPeekToken(self: *Parser, tokType: TokenType) bool {
        if (self.peekToken.type != tokType) {
            self.unexpectedTokenError(self.peekToken, tokType);
            return false;
        }

        return true;
    }

    pub fn printErrors(self: *Parser) void {
        const print = std.debug.print;
        const errs = self.errors.toOwnedSlice() catch {
            print("Could not turn errors to slice\n", .{});
            return;
        };
        for (errs) |err| {
            print("{s}\n", .{err});
        }
    }

    // Assumes that there is at least one element in list
    fn parseList(
        self: *Parser,
        T: type,
        comptime parseValue: fn (*Parser) ?T,
        delimiterToken: TokenType,
        stopToken: TokenType,
    ) ?[]T {
        var list: std.ArrayList(T) = std.ArrayList(T)
            .init(std.heap.page_allocator);

        while (self.curToken.type != stopToken) {
            const val = parseValue(self) orelse return null;
            list.append(val) catch return null;
            if (self.curToken.type == delimiterToken) {
                self.nextToken();
            } else {
                break;
            }
        }

        return list.toOwnedSlice() catch null;
    }

    fn parseExpression(self: *Parser) ?ast.Expression {
        if (!self.expectCurToken(TokenType.Identifier))
            return null;

        if (self.peekToken.type == TokenType.LeftBracket) {
            const constructor = self.parseConstructor() orelse return null;
            return .{ .Constructor = constructor };
        }

        const variable = self.parseVariable() orelse return null;
        return .{ .Variable = variable };
    }

    fn parseVariable(self: *Parser) ?ast.Variable {
        if (!self.expectCurToken(TokenType.Identifier))
            return null;

        defer self.nextToken();

        return .{ .name = self.curToken.literal };
    }

    fn parseConstructor(self: *Parser) ?ast.Constructor {
        if (!self.expectCurToken(TokenType.Identifier)
            or !self.expectPeekToken(TokenType.LeftBracket)) 
            return null;

        defer self.nextToken();

        const literal = self.curToken.literal;

        // Skip [
        self.nextToken();
        self.nextToken();

        const parameters = self.parseList(
            ast.Expression,
            parseExpression,
            TokenType.Comma,
            TokenType.RightBracket) orelse return null;

        if (!self.expectCurToken(TokenType.RightBracket))
            return null;

        return .{ .literal = literal, .parameters = parameters };
    }

    pub fn parseProgram(self: *Parser) ?ast.Program {
        const stmts = self.parseList(
            ast.Statement, 
            parseStatement,
            TokenType.Semicolon,
            TokenType.EOF) orelse return null;

        return .{ .statements = stmts };
    }

    fn parseStatement(self: *Parser) ?ast.Statement {
        switch (self.curToken.type) {
            // A statement beginning with an identifier, can only be an
            // assignment
            .Identifier => {
                const assign = self.parseAssignment() orelse return null;
                return .{ .Assign = assign };
            },
            .Local => {
                const local = self.parseLocal() orelse return null;
                return .{ .Local = local };
            },
            else => {
                return null;
            },
        }
    }

    fn parseAssignment(self: *Parser) ?ast.Assignment {
        if (!self.expectCurToken(TokenType.Identifier)) 
            return null;

        const vars = self.parseList(
            ast.Variable,
            parseVariable,
            TokenType.Comma,
            TokenType.Assign) orelse return null;

        if (!self.expectCurToken(TokenType.Assign)
            or !self.expectPeekToken(TokenType.Identifier)) 
            return null;

        // Skip :=
        self.nextToken();

        const expressions = self.parseList(
            ast.Expression,
            parseExpression,
            TokenType.Comma,
            TokenType.Semicolon) orelse return null;

        return .{ .vars = vars, .expressions = expressions };
    }

    fn parseLocal(self: *Parser) ?ast.Local {
        if (!self.expectCurToken(TokenType.Local)) 
            return null;
        
        self.nextToken();

        if (!self.expectCurToken(TokenType.LeftBracket)) 
            return null;

        self.nextToken();

        const localVariables = self.parseList(
            ast.Variable, 
            parseVariable, 
            TokenType.Comma, 
            TokenType.RightBracket) orelse return null;

        if (!self.expectCurToken(TokenType.LeftCurlyBracket)) 
            return null;

        const localProg = self.parseProgram() orelse return null; 

        if (!self.expectCurToken(TokenType.RightCurlyBracket)) 
            return null;

        return .{ .vars = localVariables, .scope = localProg };
    }
};

test "assign three variables to other three variables" {
    const input = "x, y, z := a, b, c";

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    if (parser.parseProgram()) |program| {
        ast.printProgram(program);
    } else {
        parser.printErrors();
    }
}

test "assign constructor to variable" {
    const input = "x := O []";

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        parser.printErrors();
        return;
    };
    ast.printProgram(program);
}

test "assign difficult constructor to variable" {
    const input = "x := Node [ Node [ Leaf [], a ], Leaf [] ]";

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        parser.printErrors();
        return;
    };
    ast.printProgram(program);
}

test "assignation errors" {
    const input = 
        \\ x := ;
        \\ x := b;
        \\ x, := b;
    ;

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        std.debug.print("\nCould not parse program: \n", .{});
        parser.printErrors();
        return;
    };
    ast.printProgram(program);
}
