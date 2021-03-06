require_relative 'operators.rb'

TidyToken = Struct.new(:raw, :type, :start, :line, :col) {
    def to_s
        "#{raw.inspect} (#{type} #{line}:#{col})"
    end
    alias :inspect :to_s

    def of_type?(*types)
        types.include? type
    end

    def data?
        of_type?(
            :number, :atom, :word, :infinity,
            :op_quote, :string, :character,
            :pattern_string
        )
    end

    def blank?
        of_type? :blank
    end

    def comment?
        of_type? :comment
    end

    def data_start?
        data? || of_type?(:range_open, :block_open)
    end

    def data_like?
        data? || of_type?(:paren_close, :range_close, :block_close)
    end

    def operator?
        type == :operator || type == :unary_operator
    end

    def significant?
        !(blank? || comment?)
    end

    def self.atom(atom)
        new(atom, :atom)
    end
}

class TidyTokenizer
    include Enumerable

    def initialize(code)
        @code = code
        if @code.nil?
            raise "`TidyTokenizer` @code cannot be nil"
        end
        @pos = 0
        @queue = []
        @line = 1
        @col = 1
        @in_range = false
    end

    def running?
        @pos < @code.size
    end

    def cur
        @code[@pos]
    end

    def advance(n = 1)
        n.times {
            if cur == "\n"
                @line += 1
                @col = 1
            else
                @col += 1
            end
            @pos += 1
        }
    end

    def number?(c = cur)
        /^\d$/ === c
    end
    def blank?(c = cur)
        /^\s$/ === c
    end
    def has_ahead?(re)
        result = @code.match(re, @pos).begin(0) == @pos rescue false
        @match = $&
        result
    end
    def number_terminator?(c = cur)
        TidyTokenizer.number_terminator? c
    end
    def number_separator?(c = cur)
        TidyTokenizer.number_separator? c
    end
    def self.number_separator?(c)
        ["b", "e", "."].include? c
    end
    def self.number_terminator?(c)
        ["r", "i", "f"].include? c
    end

    OPERATOR_REGEX = Regexp.new(Operators::OPERATORS.map { |e|
        case e
            when /^\w+$/
                e + '\b'
            else
                Regexp.escape e
        end
    } .join "|")
    def operator?
        has_ahead? OPERATOR_REGEX
    end

    OP_SPECIALS = {
        "⊕" => "+",
        "⊖" => "-",
        "⊗" => nil,     #times
        "⊘" => "/",
        "⊙" => ".",
        "⊚" => nil,     #ring
        "⊛" => "*",
        "⊜" => "==",
        "⊝" => nil,     #dash
    }
    OP_QUOTE_SPECIAL_REGEX = /[\u2295-\u229D]/
    OP_QUOTE_REGEX = /\((\s*(#{OPERATOR_REGEX})\s*)+\)|#{OP_QUOTE_SPECIAL_REGEX}/
    def op_quote?
        has_ahead? OP_QUOTE_REGEX
    end

    STRING_REGEX = /"([^"]|"")*"/
    def string?
        has_ahead? STRING_REGEX
    end

    PATTERN_STRING = /[A-Za-z]?`([^`]|``)*`/
    def pattern_string?
        has_ahead? PATTERN_STRING
    end

    SINGLE_COMMENT = /\?.*\r?(\n|$)/
    def single_comment?
        has_ahead? SINGLE_COMMENT
    end

    MULTI_COMMENT = /\?\?\?[\s\S]*\?\?\?/
    def multi_comment?
        has_ahead? MULTI_COMMENT
    end

    def read_token
        unless @queue.empty?
            return @queue.shift
        end

        res = TidyToken.new ""
        res.start = @pos
        res.line = @line
        res.col = @col

        if number?
            res.type = :number
            while number? || number_separator?
                res.raw += cur
                if cur == "e"
                    advance
                    if cur == "-"
                        res.raw += cur
                    end
                end
                advance
            end
            while number_terminator?
                res.raw += cur
                advance
            end
        elsif blank?
            res.type = :blank
            while blank?
                res.raw += cur
                advance
            end
        elsif op_quote?
            res.type = :op_quote
            res.raw = @match
            advance @match.size
        elsif multi_comment? || single_comment?
            res.type = :comment
            res.raw = @match
            advance @match.size
        elsif string?
            res.type = :string
            res.raw = @match
            advance @match.size
        elsif pattern_string?
            res.type = :pattern_string
            res.raw = @match
            advance @match.size
        elsif operator?
            res.type = :operator
            res.raw = @match
            advance @match.size
        elsif cur == ";"
            res.type = :separator
            res.raw = cur
            advance
        elsif cur == "'"
            res.type = :character
            res.raw = cur
            advance
            res.raw += cur
            advance
        elsif cur == "∞"
            res.type = :infinity
            res.raw = cur
            advance
        elsif cur == "{"
            res.type = :block_open
            res.raw = cur
            advance
        elsif cur == "}"
            res.type = :block_close
            res.raw = cur
            advance
        elsif cur == ":"
            res.type = :block_split
            res.raw = cur
            advance
        elsif has_ahead? /[\[\]]/
            res.type = @in_range ? :range_close : :range_open
            @in_range = !@in_range
            res.raw = cur
            advance
        elsif has_ahead? /\w+/
            res.type = :word
            res.raw = @match
            advance @match.size
        elsif has_ahead? /\(/
            res.type = :paren_open
            res.raw = cur
            advance
        elsif has_ahead? /\)/
            res.type = :paren_close
            res.raw = cur
            advance
        elsif has_ahead? ","
            res.type = :comma
            res.raw = cur
            advance
        else
            res.type = :unknown
            res.raw = cur
            STDERR.puts "Unknown token detected: #{res}"
            advance
        end

        res
    end

    def each(&block)
        while running?
            block[read_token]
        end
    end
end

def tokenize(*args)
    tokenizer = TidyTokenizer.new(*args)
    if block_given?
        tokenizer.map { |token| yield token }
    else
        tokenizer
    end
end

if $0 == __FILE__
    puts TidyTokenizer.new(ARGV[0]).to_a
end
