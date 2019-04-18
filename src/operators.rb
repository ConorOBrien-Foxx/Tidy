module Operators
    PRECEDENCE_ASSOCIATIVITY = {
        "while"     => [2, :left],
        "until"     => [2, :left],

        "unless"    => [3, :left],
        "if"        => [3, :left],

        "!"         => [4, :left],

        ":="        => [5, :right],
        "≔"         => [5, :right],
        ".="        => [5, :right],
        "⩴"         => [5, :right],

        "|"         => [7, :left],

        "not"       => [10, :left],
        "¬"         => [10, :left],
        "and"       => [10, :left],
        "∧"         => [10, :left],
        "or"        => [10, :left],
        "∨"         => [10, :left],

        "in"        => [15, :left],
        "∈"         => [15, :left],
        "!in"       => [15, :left],
        "∉"         => [15, :left],
        "="         => [15, :left],
        "=~"        => [15, :left],
        "≈"         => [15, :left],
        "<"         => [15, :left],
        "<="        => [15, :left],
        "≤"         => [15, :left],
        "<<"        => [15, :left],
        "≪"         => [15, :left],
        "<~"        => [15, :left],
        "≲"         => [15, :left],
        "<<<"       => [15, :left],
        "⫷"         => [15, :left],
        ">"         => [15, :left],
        ">="        => [15, :left],
        "≥"         => [15, :left],
        ">~"        => [15, :left],
        "≳"         => [15, :left],
        ">>"        => [15, :left],
        "≫"         => [15, :left],
        ">>>"       => [15, :left],
        "⫸"         => [15, :left],
        "<_"        => [15, :left],
        "≺"         => [15, :left],
        "_>"        => [15, :left],
        "≻"         => [15, :left],
        "/="        => [15, :left],
        "≠"         => [15, :left],

        "~"         => [20, :left],
        "from"      => [20, :right],
        "↦"         => [20, :right],
        "over"      => [20, :right],
        "←"         => [20, :right],
        "on"        => [20, :right],
        "→"         => [20, :right],
        "onto"      => [20, :right],
        "⇴"         => [20, :right],

        "$"         => [25, :right],

        "."         => [30, :left],
        "⊡"         => [30, :left],

        "-"         => [40, :left],
        "⊟"         => [40, :left],
        "+"         => [40, :left],
        "⊞"         => [40, :left],
        "∑"         => [40, :left],

        "*"         => [60, :left],
        "∏"         => [60, :left],
        "⊠"         => [60, :left],
        "%"         => [60, :left],
        "/"         => [60, :left],
        "//"        => [60, :left],

        "^"         => [70, :right],
        "√"         => [70, :left],
        "./"        => [70, :left],
        "∛"         => [70, :left],

        "@"         => [80, :left],
        "&"         => [80, :left],

        "↑"         => [90, :left],
        "↓"         => [90, :left],
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
