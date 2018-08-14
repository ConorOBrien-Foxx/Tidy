module Operators
    PRECEDENCE_ASSOCIATIVITY = {
        ":="        => [5, :right],
        "~"         => [7, :left],
        "-"         => [10, :left],
        "+"         => [10, :left],
        "*"         => [20, :left],
        "/"         => [20, :left],
        "//"        => [20, :left],
        "@"         => [60, :left],
        "&"         => [60, :left],
    }

    PRECEDENCE = PRECEDENCE_ASSOCIATIVITY.map { |k, v| [k, v.last] } .to_h
    ASSOCIATIVITY = PRECEDENCE_ASSOCIATIVITY.map { |k, v| [k, v.first] } .to_h
    OPERATORS = PRECEDENCE.keys.sort_by(&:size).reverse!

    def self.get_precedence(op)
        PRECEDENCE[op]
    end
    def self.get_associativity(op)
        ASSOCIATIVITY[op]
    end
end
