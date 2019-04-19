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
    RUBY_OPERATOR_ALIASES = {
        "≥" => ">=",
        "≤" => "<=",
        "≠" => "!=",
    }
    RUBY_UNARY_OPERATORS = ["-", "~"]

    def initialize(code)
        super(code)
        @depth = 0
    end

    RESERVED = %w(case when break unless end until)
    def fix_varname(name)
        if RESERVED.include?(name) || name[0] == "_"
            "_#{name}"
        else
            name
        end
    end

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
            "get_var(#{fix_varname(leaf.raw).inspect})"

        elsif leaf.type == :string
            inner = leaf.raw
                .gsub(/""/, '"')[1..-2]
                .gsub(/\\[nt\\]/) { eval '"' + $& + '"' }
            "'#{inner}'"

        elsif leaf.type == :pattern_string
            head = leaf.raw[0]
            inner = leaf.raw
                .gsub(/``/, '`')[2..-2]
                .gsub(/\\[nt\\]/) { eval '"' + $& + '"' }
            res = "'#{inner}'"
            unless head == '`'
                res = "call_func(\"pt_#{head}\", #{res})"
            end
            res

        elsif leaf.type == :op_quote
            preindent = " " * 4 * @depth
            @depth += 1
            indent = " " * 4 * @depth
            sub = " " * 4 * (@depth + 1)

            # determine if abnormal
            raw = leaf.raw
            op = if TidyTokenizer::OP_QUOTE_SPECIAL_REGEX === raw
                TidyTokenizer::OP_SPECIALS[raw]
            else
                leaf.raw.match(/\((.+)\)/)[1].strip
            end
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

            res = ""
            if unary && binary && op != "*"
                res += preindent + "lambda { |x, y=:unpassed|\n"
                res += indent + "local_descend\n"
                res += indent + "set_var_local(\"x\", x)\n"
                res += indent + "result = if y == :unpassed\n"
                res += sub    + unary + "\n"
                res += indent + "else\n"
                res += sub    + "set_var_local(\"y\", y)\n"
                res += sub    + binary + "\n"
                res += indent + "end\n"
                res += indent + "local_ascend\n"
                res += indent + "result\n"
                res += preindent + "}"
            elsif binary
                res += preindent + "lambda { |x, y|\n"
                res += indent + "local_descend\n"
                res += indent + "set_var_local(\"x\", x)\n"
                res += indent + "set_var_local(\"y\", y)\n"
                res += indent + "result = #{binary}\n"
                res += indent + "local_ascend\n"
                res += indent + "result\n"
                res += preindent + "}"
            elsif unary
                res += preindent + "lambda { |x|\n"
                res += indent + "local_descend\n"
                res += indent + "set_var_local(\"x\", x)\n"
                res += indent + "result = #{unary}\n"
                res += indent + "local_ascend\n"
                res += indent + "result\n"
                res += preindent + "}"
            else
                raise "operator #{op} does not exist"
            end

            @depth -= 1

            res

        else
            STDERR.puts "unhandled leaf type #{leaf.type}"

        end
    end

    def transpile_astnode(tree)
        head = tree.head
        comp = transpile(head)
        mapped = tree.children.map { |child|
            "#{transpile child}"
        }
        "call_func(#{comp}, #{mapped.join ", "})"
    end

    def transpile_operator(tree)
        head = tree.head
        mapped = tree.children.map { |child|
            "(#{transpile child})"
        }
        joined = mapped.join ", "
        case head.raw
            when *RUBY_OPERATORS
                mapped.join head.raw
            when *RUBY_OPERATOR_ALIASES.keys
                mapped.join RUBY_OPERATOR_ALIASES[head.raw]
            when "//"
                "op_slashslash(#{joined})"
            when "@"
                "op_get(#{joined})"
            when "&"
                "op_bind(#{joined})"
            when "from", "↦"
                "op_from(#{joined})"
            when "over", "←"
                "op_over(#{joined})"
            when "on", "→"
                "op_on(#{joined})"
            when "onto", "⇴"
                "force(op_on(#{joined}))"
            when "^"
                "op_caret(#{joined})"
            # when "if", "unless", "while", "until"
            #     expr, cond = mapped
            #     "#{expr} #{head.raw} truthy(#{cond})"
            when "and", "∧"
                mapped.map { |e| "truthy(#{e})" }.join "&&"
            when "or", "∨"
                mapped.map { |e| "truthy(#{e})" }.join "||"
            when "not", "¬"
                mapped.map { |e| "truthy(#{e})" }.join "&& !"
            when "="
                mapped.join "=="
            when "/="
                mapped.join "!="
            when "<_", "≺"
                "precedes(#{joined})"
            when "_>", "≻"
                "succeeds(#{joined})"
            when "⊡"
                "tidy_join(#{mapped.reverse.join ", "})"
            when "⊞", "∑"
                "multisum(#{joined})"
            when "⊟"
                "multidiff(#{joined})"
            when "⊠", "∏"
                "multiprod(#{joined})"
            when "|"
                "op_pipeline(#{joined})"
            when "in", "∈"
                "op_in(#{joined})"
            when "!in", "∉"
                "!op_in(#{joined})"
            when "."
                "op_dot(#{joined})"
            when "=~", "≈"
                "approx(#{joined})"
            when "<<", "≪"
                "muchless(#{joined})"
            when "<<<", "⫷"
                "muchmuchless(#{joined})"
            when "<~", "≲"
                "approxmuchless(#{joined})"
            when ">>", "≫"
                "muchmore(#{joined})"
            when ">~", "≳"
                "approxmuchmore(#{joined})"
            when ">>>", "⫸"
                "muchmuchmore(#{joined})"
            when "↑"
                "get_var('UP')[#{joined}]"
            when "↓"
                "get_var('DOWN')[#{joined}]"
            when ":=", "≔"
                name, val = tree.children
                "set_var(#{fix_varname(name.raw).inspect}, #{transpile val})"
            when ".=", "⩴"
                name, val = tree.children
                "set_var_local(#{fix_varname(name.raw).inspect}, #{transpile val})"
            when "√", "./"
                "nroot(#{joined})"
            when "$"
                "shape(#{joined})"
            else
                raise NoOperatorException.new("no such binary op #{head.raw.inspect}")
        end
    end

    def transpile_opquote(tree)
        head = tree.head
        mapped = tree.children.map { |child|
            "#{transpile child}"
        }
        fn = compile_leaf head
        "#{fn}[#{mapped.join ", "}]"
    end

    def transpile_unaryoperator(tree)
        head = tree.head
        mapped = tree.children.map { |child|
            "#{transpile child}"
        }
        case head.raw
            when *RUBY_UNARY_OPERATORS
                "#{head.raw}#{mapped.join}"
            when "@"
                "op_get(#{mapped.join ", "})"
            when "√", "./"
                "tidy_sqrt(#{mapped.join ", "})"
            when "∛"
                "tidy_cbrt(#{mapped.join ", "})"
            when "↑"
                "get_var('UP')[#{mapped.join ", "}]"
            when "↓"
                "get_var('DOWN')[#{mapped.join ", "}]"
            when "~"
                "op_tilde(#{mapped.join})"
            when "."
                "call_func(#{mapped.join ", "})"
            when "!"
                "fac(#{mapped.join ", "})"
            when "*"
                "*(#{mapped.join ", "})"
            when "not", "¬"
                "!truthy(#{mapped.join ", "})"
            when "⊞", "∑"
                "sum(#{mapped.join ", "})"
            when "⊟"
                "diff(#{mapped.join ", "})"
            when "⊠", "∏"
                "prod(#{mapped.join ", "})"
            when "⊡"
                "tidy_join(#{mapped.join ", "})"
            else
                raise NoOperatorException.new("no such unary op #{head.raw.inspect}")
        end
    end

    def transpile_assignrange(tree)
        head = tree.head
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
    end

    def transpile_word(tree)
        head = tree.head
        mapped = tree.children.map { |child|
            "#{transpile child}"
        }
        name = head.raw
        sep = "; "
        case name
            when "break"
                "raise TidyStopIteration if #{mapped.map{|e|"(#{e})"}.join "&&"}"
            when "Q"
                a, b, c = mapped.map { |e| "(#{e})" }
                c ||= "nil"
                "(#{a} ? #{b} : #{c})"
            when "if"
                cond, iftrue, other = mapped
                res = "(if (#{cond})#{sep}#{iftrue}#{sep}"
                unless other.nil?
                    res += "else#{sep}#{other}#{sep}"
                end
                res += "end)#{sep}"
            when "while"
                cond, *body = mapped
                res = "(while (#{cond})#{sep}"
                res += body.join sep
                res += "#{sep}end)"
            else
                "call_func(#{head.raw.inspect}, #{mapped.join ", "})"
        end
    end

    def transpile_block(tree)
        head = tree.head
        params, body = tree.children
        params = params.children.map &:raw rescue []
        params.map! { |param|
            fix_varname param
        }
        args = if params.empty?
            "*discard"
        else
            params.join(", ") + ", *discard"
        end
        res = ""
        nested = !@depth.zero?

        if nested
            @depth += 1
            res += "(\n#{" " * 4 * @depth}"
            res += "mylocal = local_save;\n"
        end

        preindent = " " * 4 * @depth
        @depth += 1
        indent = " " * 4 * @depth

        res += "#{preindent}lambda { |#{args}|\n"
        res += "#{indent}local_adopt mylocal\n" if nested
        res += "#{indent}local_descend\n"
        params.each { |param|
            res += "#{indent}set_var_local(#{param.inspect}, #{param})\n"
        }

        body.each_with_index { |sub_tree, i|
            res += "#{indent}"
            res += "result = " if i + 1 == body.size
            res += transpile sub_tree
            res += "\n"
        }

        if nested
            @depth -= 2
        else
            @depth -= 1
        end
        res += "#{indent}local_ascend\n"
        res += "#{indent}local_evict\n" if nested
        res += "#{indent}result\n"
        res += "#{preindent}}"

        if nested
            res += ")"
        end

        res
    end

    def transpile(tree)
        if ASTNode === tree
            head = tree.head
            if ASTNode === head
                transpile_astnode tree

            elsif head.type == :operator
                transpile_operator tree

            elsif head.type == :op_quote
                transpile_opquote tree

            elsif head.type == :unary_operator
                transpile_unaryoperator tree

            elsif head.type == :assign_range
                transpile_assignrange tree

            elsif head.type == :word
                transpile_word tree

            elsif head.type == :make_block
                transpile_block tree

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
