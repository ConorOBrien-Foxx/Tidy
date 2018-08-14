module Operators
    PRECEDENCE_ASSOCIATIVITY = {
        ":="        => [10, :right],
        ".="        => [10, :right],
        "="         => [15, :left],
        "/="        => [15, :left],
        "~"         => [20, :left],
        "from"      => [20, :left],
        "on"        => [20, :left],
        "-"         => [40, :left],
        "+"         => [40, :left],
        "*"         => [60, :left],
        "%"         => [60, :left],
        "/"         => [60, :left],
        "//"        => [60, :left],
        "@"         => [80, :left],
        "&"         => [80, :left],
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
