unit module AetherAST;

our class Program {
    has @.statements;
}

our class OutputStatement {
    has @.values;
}

our class InputStatement {
    has Str $.name;
}

our class AssignmentStatement {
    has Str $.name;
    has $.expression;

}
our class IfStatement {
    has $.condition;
    has @.thenBlock;
    has @.elseBlock;
}

our class WhileStatement {
    has $.condition;
    has @.body;
}