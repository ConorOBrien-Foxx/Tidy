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
    RUBY_OPERATORS = ["*", "+", "/", "-"]
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
        end
    end

    def transpile(tree)
        if ASTNode === tree
            head = tree.head
            if head.type == :operator
                mapped = tree.children.map { |child|
                    "#{transpile child}"
                }
                if RUBY_OPERATORS.include? head.raw
                    mapped.join head.raw
                else
                    "(#{mapped.join "/"}).to_i"
                end
            elsif head.type == :unary_operator
                mapped = tree.children.map { |child|
                    "#{transpile child}"
                }
                if RUBY_UNARY_OPERATORS.include? head.raw
                    "#{head.raw}#{mapped.join}"
                else
                    "(#{mapped.join "/"}).to_i"
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
                "#{head.raw}(#{mapped.join ", "})"

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
    p code
    eval code
end
