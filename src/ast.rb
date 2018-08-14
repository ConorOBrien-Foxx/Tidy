require_relative 'parser.rb'

$PRECEDENCE = {
    "+" => 5,
    "-" => 5,
    "*" => 10,
    "/" => 10,
}
def get_precedence(operator)
    $PRECEDENCE[operator]
end

def flush(source, destination, *search)
    until source.empty? || search.flatten.include?(source.last.type)
        destination << source.pop
    end
end

def shunt(code)
    initials = [:range_open, :paren_open]
    enum = Enumerator.new { |output_queue|
        operator_stack = []
        arities = []
        paren_mask_stack = []

        previous_token = nil
        tokenize(code) { |token|
            if token.data?
                if previous_token&.data?
                    flush(operator_stack, output_queue, initials)
                end
                output_queue << token

            elsif token.type == :paren_open
                # determine if function call
                operator_stack << token
                paren_mask_stack << previous_token.data_like?
                if paren_mask_stack.last
                    arities << 1
                end

            elsif token.type == :paren_close
                function_call = paren_mask_stack.pop
                flush(operator_stack, output_queue, initials)

                if function_call
                    output_queue << TidyToken.new(arities.pop, :call_func)
                else
                end
                operator_stack.pop

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
                if previous_token.nil? || previous_token.operator?
                    token.type = :unary_operator
                else
                    prec = get_precedence token.raw
                    loop {
                        break if operator_stack.empty?
                        break unless operator_stack.last.operator?
                        break if get_precedence(operator_stack.last.raw) < prec
                        output_queue << operator_stack.pop
                    }
                end
                operator_stack << token

            elsif token.blank?
                # pass

            else
                STDERR.puts "unhandled token #{token}"
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
        enum.each { |token| yield token }
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
        elsif token.operator?
            args = stack.pop(token.type == :unary_operator ? 1 : 2)
            stack << ASTNode.new(token, args)
        elsif token.type == :assign_range
            count = stack.pop.raw
            args = stack.pop(count)
            stack << ASTNode.new(token, args)
        elsif token.type == :call_func
            args = stack.pop(token.raw)
            func = stack.pop
            stack << ASTNode.new(func, args)
        else
            STDERR.puts "unhandled token #{token}"
        end
    }
    stack
end

if $0 == __FILE__
    puts ast(ARGV[0])
end
