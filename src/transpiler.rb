require_relative 'ast.rb'
require_relative 'range.rb'

class TidyTranspiler
    include Enumerable
    HEADER = []
    def initialize(code)
        @trees = ast code
    end

    def code
        @code.dup
    end

    def transpile(tree)
        raise "no target"
    end

    def each(&block)
        self.class::HEADER.each { |header_line|
            block[header_line]
        }
        @trees.each { |tree|
            block[transpile tree]
        }
    end
end

class NoOperatorException < Exception
    #TODO: description
end

class Tidy2Ruby < TidyTranspiler
    RUBY_OPERATORS = ["*", "+", "/", "-", "%", "<", ">", "<=", ">="]
    RUBY_UNARY_OPERATORS = ["-", "~"]
    def compile_leaf(leaf)
        if leaf.type == :number
            # TODO: expand
            # parse suffixes
            raw = leaf.raw
            terminator = nil
            if TidyTokenizer.number_terminator? raw[-1]
                raw, terminator = raw[0..-2], raw[-1]
            end
            res = if raw.index "."
                rational = raw.to_r
                "(#{rational.numerator}r/#{rational.denominator})"
            else
                raw
            end
            case terminator
                when nil
                    #pass
                when "f"
                    res = "#{res}.to_f"
                when "r"
                    res += "r" unless rational
                when "i"
                    res = "(#{res}*1i)"
                else
                    raise "unhandled terminator #{terminator}"
            end
            res
        elsif leaf.type == :character
            "Character.new(#{leaf.raw[1].ord})"
        elsif leaf.type == :infinity
            Infinity
        elsif leaf.type == :word
            "get_var(#{leaf.raw.inspect})"
        elsif leaf.type == :string
            inner = leaf.raw
                .gsub(/""/, '"')[1..-2]
                .gsub(/\\[nt\\]/) { eval '"' + $& + '"' }
            "'#{inner}'"
        elsif leaf.type == :op_quote
            op = leaf.raw.match(/\((.+)\)/)[1].strip
            begin
                unary = transpile ASTNode.new(
                    TidyToken.new(op, :unary_operator),
                    [
                        TidyToken.new("x", :word)
                    ]
                )
            rescue NoOperatorException
                unary = nil
            end

            begin
                binary = transpile ASTNode.new(
                    TidyToken.new(op, :operator),
                    [
                        TidyToken.new("x", :word),
                        TidyToken.new("y", :word),
                    ]
                )
            rescue NoOperatorException
                binary = nil
            end
            if unary && binary && op != "*"
                "lambda { |x, y=:unpassed|
                    set_var_local(\"x\", x)
                    if y == :unpassed
                        #{unary}
                    else
                        set_var_local(\"y\", y)
                        #{binary}
                    end
                }"
            elsif binary
                "lambda { |x, y|
                    set_var_local(\"x\", x)
                    set_var_local(\"y\", y)
                    #{binary}
                }"
            elsif unary
                "lambda { |x|
                    set_var_local(\"x\", x)
                    #{unary}
                }"
            else
                raise "operator #{op} does not exist"
            end
        else
            STDERR.puts "unhandled leaf type #{leaf.type}"
        end
    end

    def transpile(tree)
        if ASTNode === tree
            head = tree.head
            if ASTNode === head
                comp = transpile(head)
                mapped = tree.children.map { |child|
                    "#{transpile child}"
                }
                "call_func(#{comp}, #{mapped.join ", "})"

            elsif head.type == :operator
                mapped = tree.children.map { |child|
                    "#{transpile child}"
                }
                case head.raw
                    when *RUBY_OPERATORS
                        mapped.join head.raw
                    when "//"
                        "op_slashslash(#{mapped.join ", "})"
                    when "@"
                        "op_get(#{mapped.join ", "})"
                    when "&"
                        "op_bind(#{mapped.join ", "})"
                    when "from"
                        "op_from(#{mapped.join ", "})"
                    when "over"
                        "op_over(#{mapped.join ", "})"
                    when "on"
                        "op_on(#{mapped.join ", "})"
                    when "^"
                        "op_caret(#{mapped.join ", "})"
                    when "if", "unless", "while", "until"
                        expr, cond = mapped
                        "#{expr} #{head.raw} truthy(#{cond})"
                    when "and"
                        mapped.join "&&"
                    when "or"
                        mapped.join "||"
                    when "="
                        mapped.join "=="
                    when "/="
                        mapped.join "!="
                    when "|"
                        "op_pipeline(#{mapped.join ", "})"
                    when "in"
                        "op_in(#{mapped.join ", "})"
                    when "."
                        "op_dot(#{mapped.join ", "})"
                    when ":="
                        name, val = tree.children
                        "set_var(#{name.raw.inspect}, #{transpile val})"
                    when ".="
                        name, val = tree.children
                        "set_var_local(#{name.raw.inspect}, #{transpile val})"
                    else
                        raise NoOperatorException.new("no such binary op #{head.raw.inspect}")
                end

            elsif head.type == :op_quote
                mapped = tree.children.map { |child|
                    "#{transpile child}"
                }
                fn = compile_leaf head
                "#{fn}[#{mapped.join ", "}]"

            elsif head.type == :unary_operator
                mapped = tree.children.map { |child|
                    "#{transpile child}"
                }
                case head.raw
                    when *RUBY_UNARY_OPERATORS
                        "#{head.raw}#{mapped.join}"
                    when "@"
                        "op_get(#{mapped.join ", "})"
                    when "~"
                        "op_tilde(#{mapped.join})"
                    when "."
                        "call_func(#{mapped.join ", "})"
                    when "*"
                        "*(#{mapped.join ", "})"
                    else
                        raise NoOperatorException.new("no such unary op #{head.raw.inspect}")
                end

            elsif head.type == :assign_range
                mapped = tree.children.map { |child|
                    "#{transpile child}"
                }
                exclude_lower = head.raw[0] == "]"
                exclude_upper = head.raw[1] == "["
                case mapped.size
                    when 1
                        raise "singleton ranges don't exist"
                    when 2
                        a, b = mapped
                        "tidy_range(#{a}, #{b}, 1, #{exclude_lower}, #{exclude_upper})"
                    when 3
                        a, s, b = mapped
                        "tidy_range(#{a}, #{b}, #{s}, #{exclude_lower}, #{exclude_upper})"
                    else
                        raise "no range case for #{mapped.size}"
                end

            elsif head.type == :word
                mapped = tree.children.map { |child|
                    "#{transpile child}"
                }
                name = head.raw
                case name
                    when "break"
                        "raise TidyStopIteration if #{mapped.map{|e|"(#{e})"}.join "&&"}"
                    when "q"
                        a, b, c = mapped.map { |e| "(#{e})" }
                        c ||= "nil"
                        "(#{a} ? #{b} : #{c})"
                    else
                        "call_func(#{head.raw.inspect}, #{mapped.join ", "})"
                end

            elsif head.type == :make_block
                params, body = tree.children
                params = params.children.map &:raw rescue []
                args = if params.empty?
                    "*discard"
                else
                    params.join(", ") + ", *discard"
                end
                res = "lambda { |#{args}|\n"
                res += "    local_descend\n"
                params.each { |param|
                    res += "    set_var_local(#{param.inspect}, #{param})\n"
                }
                body.each_with_index { |sub_tree, i|
                    res += "    "
                    res += "result = " if i + 1 == body.size
                    res += transpile sub_tree
                    res += "\n"
                }
                res += "    local_ascend\n"
                res += "    result\n"
                res += "}"

            else
                raise "unhandled head #{head}"
            end
        else
            compile_leaf tree
        end
    end
end

if $0 == __FILE__
    code = ARGV[0]
    tr = Tidy2Ruby.new code
    code = tr.to_a.join("\n")
    puts code
    eval code
end
