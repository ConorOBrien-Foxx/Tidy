module Operators
    PRECEDENCE = {
        "-" => 10,
        "+" => 10,
        "*" => 20,
        "/" => 20,
        "//" => 20,
        "@" => 60,
    }
    OPERATORS = PRECEDENCE.keys.sort_by(&:size).reverse!

    def self.get_precedence(op)
        PRECEDENCE[op]
    end
end
