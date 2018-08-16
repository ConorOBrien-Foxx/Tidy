module Operators
    PRECEDENCE_ASSOCIATIVITY = {
        "|"         => [1, :left],
        "while"     => [3, :left],
        "until"     => [3, :left],
        "unless"    => [4, :left],
        "if"        => [4, :left],
        ":="        => [5, :right],
        ".="        => [5, :right],
        "and"       => [10, :left],
        "or"        => [10, :left],
        "in"        => [15, :left],
        "="         => [15, :left],
        "<"         => [15, :left],
        "<="        => [15, :left],
        ">"         => [15, :left],
        ">="        => [15, :left],
        "/="        => [15, :left],
        "~"         => [20, :left],
        "from"      => [20, :left],
        "over"      => [20, :left],
        "on"        => [20, :left],
        "-"         => [40, :left],
        "+"         => [40, :left],
        "*"         => [60, :left],
        "%"         => [60, :left],
        "/"         => [60, :left],
        "//"        => [60, :left],
        "^"         => [70, :right],
        "@"         => [80, :left],
        "&"         => [80, :left],
    }

    PRECEDENCE = PRECEDENCE_ASSOCIATIVITY.map { |k, v| [k, v.first] } .to_h
    ASSOCIATIVITY = PRECEDENCE_ASSOCIATIVITY.map { |k, v| [k, v.last] } .to_h
    OPERATORS = PRECEDENCE.keys.sort_by(&:size).reverse!

    def self.get_precedence(op)
        PRECEDENCE[op]
    end
    def self.get_associativity(op)
        ASSOCIATIVITY[op]
    end
end
