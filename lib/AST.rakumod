unit module AST;

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