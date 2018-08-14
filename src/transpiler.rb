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

class Tidy2Ruby < TidyTranspiler
    RUBY_OPERATORS = ["*", "+", "/", "-", "%", "<", ">", "<=", ">="]
    RUBY_UNARY_OPERATORS = ["-"]
    def compile_leaf(leaf)
        if leaf.type == :number
            # TODO: expand
            if leaf.raw.index "."
                rational = leaf.raw.to_r
                "(#{rational.numerator}r/#{rational.denominator})"
            else
                leaf.raw
            end
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
            op = leaf.raw.match(/\((.+)\)/)[1]
            transpile(
                ASTNode.new(
                    TidyToken.new("", :make_block),
                    [
                        ASTNode.new(
                            TidyToken.new(":", :block_split),
                            [
                                TidyToken.new("x", :word),
                                TidyToken.new("y", :word),
                            ],
                        ),
                        [
                            ASTNode.new(
                                TidyToken.new(op, :operator),
                                [
                                    TidyToken.new("x", :word),
                                    TidyToken.new("y", :word),
                                ]
                            )
                        ]
                    ]
                )
            )
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
                        "(#{mapped.join "/"}).to_i"
                    when "@"
                        "op_get(#{mapped.join ", "})"
                    when "&"
                        "op_bind(#{mapped.join ", "})"
                    when "from"
                        "op_from(#{mapped.join ", "})"
                    when "on"
                        "op_on(#{mapped.join ", "})"
                    when "="
                        mapped.join "=="
                    when "/="
                        mapped.join "!="
                    when ":="
                        name, val = tree.children
                        "set_var(#{name.raw.inspect}, #{transpile val})"
                    when ".="
                        name, val = tree.children
                        "set_var_local(#{name.raw.inspect}, #{transpile val})"
                    else
                        STDERR.puts "no such binary op #{head.raw.inspect}"
                end

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
                    else
                        STDERR.puts "no such unary op #{head.raw.inspect}"
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
                    else
                        "call_func(#{head.raw.inspect}, #{mapped.join ", "})"
                end

            elsif head.type == :make_block
                params, body = tree.children
                params = params.children.map &:raw
                res = "lambda { |#{params.join ", "}|\n"
                res += "    local_descend\n"
                params.each { |param|
                    res += "    set_var_local(#{param.inspect}, #{param})\n"
                }
                body.reverse_each.with_index { |sub_tree, i|
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
