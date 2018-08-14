#!/usr/bin/ruby

require_relative 'src/transpiler.rb'

def print_enum(enum, separator=", ")
    copy = enum.to_enum

    queue = []

    loop {
        break if until queue.size >= 2
            begin
                queue << copy.next
            rescue StopIteration => e
                break true
            end
        end
        print queue.shift, separator
    }
    print queue.pop

end

$VALID_FUNCTIONS = []
def tidy_func_def(name, &block)
    $VALID_FUNCTIONS << name.to_s
    define_method(name) { |*args| block[*args] }
end

tidy_func_def(:curry) { |fn, arity=fn.arity|
    rec = lambda { |*args|
        if args.size >= arity
            fn[*args]
        else
            lambda { |*more|
                rec[*args, *more]
            }
        end
    }
}

def tidy_curry_def(name, arity=nil, &block)
    $VALID_FUNCTIONS << name.to_s
    define_method name, &curry(block, arity || block.arity)
end

tidy_func_def(:out) { |*args|
    args.each { |arg|
        if Enumerator === arg
            print "["
            print_enum arg
            print "]"
        else
            print arg.inspect
        end
        puts
    }
}

tidy_curry_def(:tile) { |amount, enum|
    enum.tile(amount)
}
tidy_curry_def(:skip) { |count, enum|
    enum.skip(count)
}
tidy_curry_def(:take) { |count, enum|
    enum.take(count)
}
tidy_func_def(:force) { |enum|
    enum.force
}
tidy_func_def(:map) { |fn, enum|
    enum.map { |e| fn[e] }
}
$variables = {
    "N" => tidy_range(1, Infinity)
}
$locals = [{}]
tidy_func_def(:set_var) { |name, val|
    $variables[name] = val
}
tidy_func_def(:set_var_local) { |name, val|
    $locals.last[name] = val
}
tidy_func_def(:get_var) { |name|
    if $locals.last.has_key? name
        $locals.last[name]
    elsif $variables.has_key? name
        $variables[name]
    elsif $VALID_FUNCTIONS.include? name
        lambda(&method(name))
    else
        raise "undefined variable/function #{name}"
    end
}

def local_descend
    $locals << {}
end
def local_ascend
    $locals << {}
end

def op_get(source, index)
    case source
        when Array, String
            source[index]
        when Enumerable
            if index < 0
                source.force[index]
            else
                source.take(index + 1).force[index]
            end
        else
            raise "no such thing"
    end
end

def call_func(fn, *args)
    case fn
        when String
            if $VALID_FUNCTIONS.include? fn
                send fn, *args
            elsif fn = get_var(fn)
                fn[*args]
            else
                STDERR.puts "undeclared function #{fn.inspect}"
                exit
            end
        when Proc
            fn[*args]
        else
            raise 'idk'
    end
end

def op_tilde(arg)
    case arg
        when Proc
            lambda { |*args|
                arg[*args.reverse]
            }
        else
            STDERR.puts "#{arg.class} not supported for tilde"
            raise
    end
end

def op_bind(left, right)
    if Proc === left
        lambda { |*args|
            left[*args, right]
        }
    elsif Proc === right
        lambda { |*args|
            right[left, *args]
        }
    end
end

if $0 == __FILE__
    code = File.read(ARGV[0], encoding: "utf-8") rescue ARGV[0]
    tr = Tidy2Ruby.new code
    code = tr.to_a.join("\n")
    puts code
    eval code
end
