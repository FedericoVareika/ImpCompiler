const std = @import("std");
const token = @import("token.zig");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");

pub const Parser = struct {
    const TokenType = token.TokenType;

    lexer: *lexer.Lexer,
    curToken: token.Token = .{},
    peekToken: token.Token = .{},

    pub fn nextToken(self: *Parser) void {
        self.curToken = self.peekToken;
        self.peekToken = self.lexer.nextToken();
    }

    pub fn init(l: *lexer.Lexer) Parser {
        var p: Parser = .{
            .lexer = l,
        };
        p.nextToken();
        p.nextToken();
        return p;
    }

    // Assumes that there is at least one element in list
    // List delimiter is TokenType.Comma
    fn ParseList(
        self: *Parser,
        T: type,
        comptime parseValue: fn (*Parser) T,
        delimiter: TokenType,
    ) []T {
        var list: std.ArrayList(T) = std.ArrayList(T)
            .init(std.heap.page_allocator);

        while (true) {
            list.append(parseValue(self)) catch {};
            self.nextToken();
            if (self.curToken.type == delimiter) {
                self.nextToken();
            } else {
                break;
            }
        }

        return list.toOwnedSlice() catch &[0]T{};
    }

    pub fn ParseProgram(self: *Parser) ast.Program {
        var program = ast.Program.init();

        while (self.curToken.type != TokenType.EOF) {
            const stmt = self.ParseStatement();
            program.statements.append(stmt) catch {};
            self.nextToken();
        }

        return program;
    }

    fn ParseStatement(self: *Parser) ast.Statement {
        switch (self.curToken.type) {
            // A statement beginning with an identifier, can only be an
            // assignment
            .Identifier => {
                return .{ .Assign = self.ParseAssignment() };
            },
            else => {
                return .{ .Illegal = {} };
            },
        }
    }

    fn ParseAssignment(self: *Parser) ast.Assignment {
        std.debug.assert(self.curToken.type == TokenType.Identifier);

        const vars = self.ParseList(ast.Variable, ParseVariable, TokenType.Comma);

        std.debug.assert(self.peekToken.type == TokenType.Assign);

        // Skip :=
        self.nextToken();
        self.nextToken();

        std.debug.assert(self.peekToken.type == TokenType.Identifier);

        const expressions = self.ParseList(ast.Expression, ParseExpression, TokenType.Comma);

        return .{ .vars = vars, .expressions = expressions };
    }

    fn ParseExpression(self: *Parser) ast.Expression {
        std.debug.assert(self.curToken.type == TokenType.Identifier);

        if (self.peekToken.type == TokenType.LeftBracket) {
            return .{ .Constructor = self.ParseConstructor() };
        }

        return .{ .Variable = self.ParseVariable() };
    }

    fn ParseVariable(self: *Parser) ast.Variable {
        std.debug.assert(self.curToken.type == TokenType.Identifier);

        defer self.nextToken();

        return .{ .name = self.curToken.literal };
    }

    fn ParseConstructor(self: *Parser) ast.Constructor {
        std.debug.assert(self.curToken.type == TokenType.Identifier);
        std.debug.assert(self.peekToken.type == TokenType.LeftBracket);

        defer self.nextToken();

        const literal = self.curToken.literal;

        // Skip [
        self.nextToken();
        self.nextToken();

        const parameters = self.ParseList(ast.Expression, ParseExpression, TokenType.Comma);

        return .{ .literal = literal, .parameters = parameters };
    }
};

fn printAssignment(assignment: ast.Assignment) void {
    const print = std.debug.print;

    print("Assignment:\n", .{});

    for (assignment.vars.len) |i| {
        print("{s} := ", .{
            &assignment.vars[i],
        });
        switch (assignment.expressions[i]) {
            .Variable => |variable| {
                print("{s}\n", .{&variable});
            },
        }
    }

    for (assignment.expressions) |variable| {
        print("Var: {s}\n", .{&variable});
    }
}

fn printStatement(stmt: ast.Statement) void {
    switch (stmt) {
        .Assign => |assignment| {
            printAssignment(assignment);
        },
    }
}

fn printProgram(prog: ast.Program) void {
    for (prog.statements.allocatedSlice()[0..prog.statements.items.len]) |stmt| {
        printStatement(stmt);
    }
}

test "assign one variable ast" {
    const input = "x := b";

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.ParseProgram();
    _ = program;
}
