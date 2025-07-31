const std = @import("std");
const token = @import("token.zig");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");
const TokenType = token.TokenType;
const ParseError = @import("parseError.zig").ParseError;

const printf = @cImport("stdio.h").printf;

pub const Parser = struct {
    lexer: *lexer.Lexer,
    curToken: token.Token = .{},
    peekToken: token.Token = .{},

    errors: std.ArrayList(ParseError),

    pub fn nextToken(self: *Parser) void {
        self.curToken = self.peekToken;
        self.peekToken = self.lexer.nextToken();
    }

    pub fn init(l: *lexer.Lexer) Parser {
        var p: Parser = .{
            .lexer = l,
            .errors = std.ArrayList(ParseError).init(std.heap.page_allocator),
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
        const start, const end = self.lexer.getLineCoords(actualToken.position);
        const newError: ParseError = .{
            .UnexpectedToken = .{
                .position = actualToken.position - start,
                .line = self.lexer.input[start..end], 
                .expectedToken = expectedTokenType, 
                .actualToken = actualToken.type,
            }
        }; 
        self.errors.append(newError) catch {
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

    fn parseList(
        self: *Parser,
        T: type,
        comptime parseValue: fn (*Parser) ?T,
        delimiterToken: TokenType,
        stopToken: TokenType,
    ) ?[]T {
        var list: std.ArrayList(T) = std.ArrayList(T)
            .init(std.heap.page_allocator);
        defer list.deinit();

        while (self.curToken.type != stopToken) {
            if (parseValue(self)) |val| {
                list.append(val) catch return null;
            }
            if (self.curToken.type == delimiterToken) {
                self.nextToken();
            } else {
                break;
            }
        }

        if (self.errors.items.len > 0) return null;

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

    fn parseBranch(self: *Parser) ?ast.Branch {
        if (!self.expectCurToken(TokenType.Identifier) 
            or !self.expectPeekToken(TokenType.LeftBracket))
            return null;

        const constructorName = self.curToken.literal;

        // Skip [
        self.nextToken();
        self.nextToken();

        const captureParameters = self.parseList(
            ast.Variable, 
            parseVariable, 
            TokenType.Comma,
            TokenType.RightBracket) orelse return null;

        if (!self.expectCurToken(TokenType.RightBracket)
            or !self.expectPeekToken(TokenType.Arrow))
            return null;

        // Skip ]
        self.nextToken();
        // Skip ->
        self.nextToken();

        const branchProgram = self.parseProgram() orelse return null;

        return .{
            .constructorName = constructorName,
            .captureParameters = captureParameters,
            .branchProgram = branchProgram,
        };
    }

    pub fn parseProgram(self: *Parser) ?ast.Program {
        var openScope = false;
        if (self.curToken.type == TokenType.LeftCurlyBracket) {
            openScope = true;
            self.nextToken();
        }

        const stmts = self.parseList(
            ast.Statement, 
            parseStatement,
            TokenType.Semicolon,
            TokenType.EOF) orelse return null;

        if (openScope) {
            if (!self.expectCurToken(TokenType.RightCurlyBracket))
                return null;
            self.nextToken();
        }

        return .{ .statements = stmts };
    }

    fn parseStatement(self: *Parser) ?ast.Statement {
        switch (self.curToken.type) {
            .Identifier => {
                if (self.peekToken.type == TokenType.LeftParen) {
                    const functionCall = self.parseFunctionCall() 
                        orelse return null;
                    return .{ .CallFunction = functionCall };
                } else {
                    const assign = self.parseAssignment() orelse return null;
                    return .{ .Assign = assign };
                }
            },
            .Local => {
                const local = self.parseLocal() orelse return null;
                return .{ .Local = local };
            },
            .Case => {
                const case = self.parseCase() orelse return null;
                return .{ .Case = case };
            },
            .While => {
                const whileStmt = self.parseWhile() orelse return null;
                return .{ .While = whileStmt };
            },
            .DefineFunction => {
                const defineFunction = self.parseDefineFunction() orelse return null;
                return .{ .DefineFunction = defineFunction };
            },
            .RightCurlyBracket => {
                return null;
            },
            else => {
                std.debug.print("Unexpected token {s}\n", .{ self.curToken.type });
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

        if (!self.expectCurToken(TokenType.RightBracket)) 
            return null;

        self.nextToken();

        if (!self.expectCurToken(TokenType.LeftCurlyBracket)) 
            return null;

        const localProg = self.parseProgram() orelse return null; 

        return .{ .vars = localVariables, .scope = localProg };
    }

    fn parseCase(self: *Parser) ?ast.Case {
        if (!self.expectCurToken(TokenType.Case)
            or !self.expectPeekToken(TokenType.Identifier)) 
            return null;

        self.nextToken();

        const caseVariable = self.parseVariable() orelse return null;

        if (!self.expectCurToken(TokenType.CaseOf)
            or !self.expectPeekToken(TokenType.LeftBracket))
            return null;

        self.nextToken();
        self.nextToken();

        const branches = self.parseList(
            ast.Branch,
            parseBranch,
            TokenType.Comma, 
            TokenType.RightBracket) orelse return null;

        if (!self.expectCurToken(TokenType.RightBracket))
            return null;

        return .{ .variable = caseVariable, .branches = branches };
    }

    fn parseWhile(self: *Parser) ?ast.While {
        if (!self.expectCurToken(TokenType.While)
            or !self.expectPeekToken(TokenType.Identifier)) 
            return null;

        self.nextToken();

        const whileVariable = self.parseVariable() orelse return null;

        if (!self.expectCurToken(TokenType.WhileIs)
            or !self.expectPeekToken(TokenType.LeftBracket))
            return null;

        self.nextToken();
        self.nextToken();

        const branches = self.parseList(
            ast.Branch,
            parseBranch,
            TokenType.Comma, 
            TokenType.RightBracket) orelse return null;

        return .{ .variable = whileVariable, .branches = branches };
    }

    fn parseDefineFunction(self: *Parser) ?ast.DefineFunction {
        if (!self.expectCurToken(TokenType.DefineFunction)
            or !self.expectPeekToken(TokenType.Identifier)) 
            return null;

        self.nextToken();

        if (!self.expectPeekToken(TokenType.LeftParen))
            return null;

        const functionName = self.curToken.literal;

        self.nextToken();

        // Skip (
        self.nextToken();

        const parameters = self.parseList(
            ast.Variable,
            parseVariable,
            TokenType.Comma, 
            TokenType.RightParen) orelse return null;

        if (!self.expectCurToken(TokenType.RightParen) 
            or !self.expectPeekToken(TokenType.FunctionReturns))
            return null;

        // Skip ') returns'
        self.nextToken();
        self.nextToken();

        const returns = self.parseVariable() orelse return null;

        if (!self.expectCurToken(TokenType.LeftCurlyBracket))
            return null;

        const program = self.parseProgram() orelse return null;

        return .{ 
            .name = functionName,
            .parameters = parameters,
            .returns = returns,
            .program = program,
        };
    }

    fn parseFunctionCall(self: *Parser) ?ast.CallFunction {
        if (!self.expectCurToken(TokenType.Identifier)
            or !self.expectPeekToken(TokenType.LeftParen)) 
            return null;

        const functionName = self.curToken.literal;

        self.nextToken();
        // Skip '('
        self.nextToken();

        const parameters = self.parseList(
            ast.Expression,
            parseExpression,
            TokenType.Comma, 
            TokenType.RightParen) orelse return null;

        if (!self.expectCurToken(TokenType.RightParen) 
            or !self.expectPeekToken(TokenType.CallOn))
            return null;

        // Skip ') on'
        self.nextToken();
        self.nextToken();

        const on = self.parseVariable() orelse return null;

        return .{ 
            .name = functionName,
            .parameters = parameters,
            .on = on,
        };
    }
};

test "assign three variables to other three variables" {
    const input = "x, y, z := a, b, c";

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    if (parser.parseProgram()) |program| {
        std.debug.print("{any}\n", .{ program });
        // _ = program;
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
    std.debug.print("{any}\n", .{ program });
    // _ = program;
}

test "assign difficult constructor to variable" {
    const input = "x := Node [ Node [ Leaf [], a ], Leaf [] ]";

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        parser.printErrors();
        return;
    };
    std.debug.print("{any}\n", .{ program });
    // _ = program;
}

test "assignation error, no right hand side" {
    const input = 
        \\ x :=;
    ;

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        std.debug.print("\nCould not parse program: \n", .{});
        parser.printErrors();
        return;
    };
    std.debug.print("{any}\n", .{ program });
    // _ = program;
}

test "assignation error, bad assign symbol" {
    const input = 
        \\ x = b;
    ;

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        std.debug.print("\nCould not parse program: \n", .{});
        parser.printErrors();
        return;
    };
    std.debug.print("{any}\n", .{ program });
    // _ = program;
}

test "assignation error, no assign symbol" {
    const input = 
        \\ x b;
    ;

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        std.debug.print("\nCould not parse program: \n", .{});
        parser.printErrors();
        return;
    };
    std.debug.print("{any}\n", .{ program });
    // _ = program;
}

test "local test" {
    const input = 
        \\ local [x] {
        \\   x := O [];
        \\ };
    ;

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        std.debug.print("\nCould not parse program: \n", .{});
        parser.printErrors();
        return;
    };
    std.debug.print("{any}\n", .{ program });
    // _ = program;
}

test "case test" {
    const input = 
        \\ case x of [
        \\   O [] -> {
        \\     y := x;
        \\   },
        \\   S [x'] -> {
        \\     y := x'; 
        \\   }
        \\ ];
    ;

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        std.debug.print("\nCould not parse program: \n", .{});
        parser.printErrors();
        return;
    };
    // std.debug.print("{s:>5}\n", .{ program });
    std.debug.print("{any}\n", .{ program });
    // _ = program;
}

test "while test" {
    const input = 
        \\ while x is [
        \\   O [] -> {
        \\     y := x;
        \\   },
        \\   S [x'] -> {
        \\     y := x'; 
        \\   }
        \\ ];
    ;

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        std.debug.print("\nCould not parse program: \n", .{});
        parser.printErrors();
        return;
    };
    std.debug.print("{any}\n", .{ program });
}

test "def test" {
    const input = 
        \\ def funcName(x, y, z) returns ret {
        \\   ret := x;
        \\ }
    ;

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        std.debug.print("\nCould not parse program: \n", .{});
        parser.printErrors();
        return;
    };
    std.debug.print("{any}\n", .{ program });
}

test "call function test" {
    const input = 
        \\ funcName(x, y, z) on a;
        ;

    var l = lexer.Lexer.init(input);
    var parser = Parser.init(&l);

    const program = parser.parseProgram() orelse {
        std.debug.print("\nCould not parse program: \n", .{});
        parser.printErrors();
        return;
    };
    std.debug.print("{any}\n", .{ program });
}
