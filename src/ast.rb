require_relative 'parser.rb'
require_relative 'operators.rb'

def flush(source, destination, *search)
    until source.empty? || search.flatten.include?(source.last.type)
        destination << source.pop
    end
end

def shunt(code)
    initials = [:range_open, :paren_open, :block_open]
    enum = Enumerator.new { |output_queue|
        operator_stack = []
        arities = []
        paren_mask_stack = []

        previous_token = nil
        tokenize(code) { |token|
            if token.data?
                if previous_token&.data_like?
                    flush(operator_stack, output_queue, initials)
                end
            end

            if token.data?
                output_queue << token

            elsif token.type == :paren_open
                # determine if function call
                operator_stack << token
                paren_mask_stack << previous_token&.data_like?
                if paren_mask_stack.last
                    arities << 1
                end

            elsif token.type == :paren_close
                function_call = paren_mask_stack.pop
                # flush(operator_stack, output_queue, initials)
                loop {
                    break if operator_stack.last.type == :paren_open
                    output_queue << operator_stack.pop
                }

                if function_call
                    arity = arities.pop
                    arity = 0 if previous_token&.type == :paren_open
                    output_queue << TidyToken.new(arity, :call_func)
                else
                end
                operator_stack.pop

            elsif token.type == :block_open
                operator_stack << token
                output_queue << token
                arities << 1

            elsif token.type == :block_split
                output_queue << TidyToken.atom(arities.pop)
                output_queue << token

            elsif token.type == :block_close
                flush(operator_stack, output_queue, initials)
                operator_stack.pop
                # p "block close", operator_stack
                output_queue << token
                # output_queue << operator_stack.pop


            elsif token.type == :range_open
                operator_stack << token
                arities << 1

            elsif token.type == :range_close
                flush(operator_stack, output_queue, initials)
                range = operator_stack.pop
                range.raw += token.raw
                range.type = :assign_range
                output_queue << TidyToken.atom(arities.pop)
                output_queue << range

            elsif token.type == :comma
                arities[-1] += 1
                flush(operator_stack, output_queue, initials)

            elsif token.operator?
                if previous_token.nil? || previous_token.operator? || initials.include?(previous_token.type)
                    token.type = :unary_operator
                else
                    prec = Operators::get_precedence token.raw
                    loop {
                        break if operator_stack.empty?
                        break unless operator_stack.last.operator?

                        top_raw = operator_stack.last.raw
                        is_right = Operators::get_associativity(top_raw) == :right
                        top_prec = Operators::get_precedence(top_raw)

                        break unless is_right ? top_prec <= prec : top_prec < prec

                        output_queue << operator_stack.pop
                    }
                end
                operator_stack << token

            elsif token.blank?
                # pass

            else
                STDERR.puts "unhandled token #{token} in shunt"
            end

            if token.significant?
                previous_token = token
            end
        }

        operator_stack.reverse_each { |token|
            output_queue << token
        }
    }

    if block_given?
        enum.each { |token| yield token.dup }
    else
        enum
    end
end

ASTNode = Struct.new(:head, :children)

def ast(code)
    stack = []
    shunt(code) { |token|
        if token.data?
            stack << token
        elsif token.type == :block_open
            stack << token
        elsif token.operator?
            args = stack.pop(token.type == :unary_operator ? 1 : 2)
            stack << ASTNode.new(token, args)
        elsif token.type == :assign_range || token.type == :block_split
            count = stack.pop.raw
            args = stack.pop(count)
            stack << ASTNode.new(token, args)
        elsif token.type == :call_func
            args = stack.pop(token.raw)
            func = stack.pop
            stack << ASTNode.new(func, args)
        elsif token.type == :block_close
            body = []
            loop {
                if ASTNode === stack.last
                    if stack.last.head.type == :block_split
                        break
                    end
                else
                    if stack.last.type == :block_open
                        stack.pop
                        break
                    end
                end
                body.unshift stack.pop
            }
            params = stack.pop
            token.raw = ""
            token.type = :make_block
            stack << ASTNode.new(token, [params, body])
        else
            STDERR.puts "unhandled token #{token} in ast"
        end
    }
    stack
end

if $0 == __FILE__
    puts "]]] SHUNTING"
    shunt(ARGV[0]) { |e| p e }
    puts "]]] AST"
    puts ast(ARGV[0])
end
