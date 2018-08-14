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

tidy_func_def(:tile) { |enum, *args|
    enum.tile(*args)
}
tidy_func_def(:skip) { |enum, *args|
    enum.skip(*args)
}
tidy_func_def(:take) { |enum, *args|
    enum.take(*args)
}
tidy_func_def(:force) { |enum|
    enum.force
}
tidy_func_def(:map) { |fn, enum|
    enum.map { |e| fn[e] }
}
$variables = {}
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
    end
}
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

if $0 == __FILE__
    code = File.read(ARGV[0], encoding: "utf-8") rescue ARGV[0]
    tr = Tidy2Ruby.new code
    code = tr.to_a.join("\n")
    eval code
end
