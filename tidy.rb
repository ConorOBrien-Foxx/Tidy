#!/usr/bin/ruby

require_relative 'src/transpiler.rb'
require 'readline'

class TidyStopIteration < Exception

end

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

def eval_tidy(code)
    inst = Tidy2Ruby.new code
    result = inst.to_a.join "\n"
    eval result
end

tidy_func_def(:out) { |*args|
    args.each { |arg|
        case arg
            when Enumerator
                print "["
                print_enum arg
                print "]"
            when File
                print "File(#{arg.path})"
            else
                print arg.inspect
        end
        puts
    }
}
tidy_func_def(:readline) { |prompt, hist=true|
    Readline.readline(prompt, hist)
}
tidy_func_def(:write) { |*args|
    output = IO === args.first ? args.shift : STDOUT
    output.write *args.join
}
tidy_func_def(:open) { |file_name, *opts|
    File.open(file_name, *opts)
}
tidy_func_def(:close) { |file_object|
    file_object.close
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
    result = []
    begin
        enum.each { |el|
            result << el
        }
    rescue TidyStopIteration => e
        result
    end
    result
}
tidy_func_def(:map) { |fn, enum|
    enum.map { |e| fn[e] }
}
$variables = {
    "N" => tidy_range(1, Infinity),
    "eval" => lambda(&method(:eval_tidy))
}
$locals = [{}]
tidy_func_def(:set_var) { |name, val|
    $variables[name] = val
}
tidy_func_def(:set_var_local) { |name, val|
    $locals.last[name] = val
}
tidy_func_def(:get_var) { |name|
    local = $locals.reverse.find { |local| local.has_key? name }
    if local
        local[name]
    elsif $variables.has_key? name
        $variables[name]
    elsif $VALID_FUNCTIONS.include? name
        lambda(&method(name))
    else
        raise "undefined variable/function #{name}"
    end
}
tidy_func_def(:count) { |a|
    case a
        when Enumerator
            a.force.size
        when Array, String
            a.size
        when Numeric
            a.abs.to_s.size
        else
            STDERR.puts "invalid argument passed to #{count}"
            raise
    end
}
tidy_func_def(:c) { |*args| args }

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

def op_from(pred, source)
    source.select(&pred)
end
def op_on(pred, source)
    source.map(&pred)
end

if $0 == __FILE__
    require 'optparse'
    FILE_NAME = File.basename $0
    options = {}
    opts = OptionParser.new { |opts|
        opts.banner = "Usage: #{FILE_NAME} [options]"

        opts.separator ""
        opts.separator "[options]"

        opts.on("-s", "--show-compiled", "Show the compiled code") { |v|
            options[:show_code] = v
        }
        opts.on("-e", "--execute CODE", "Executes CODE in Tidy") { |v|
            options[:code] = v
        }
        opts.on_tail("-h", "--help", "Show this help message") {
            puts opts
            exit
        }
    }

    opts.parse!

    if options.empty? && ARGV.empty?
        puts opts
        exit
    end

    code = options[:code] || File.read(ARGV[0], encoding: "utf-8")
    tr = Tidy2Ruby.new code
    code = tr.to_a.join("\n")
    puts code if options[:show_code]
    eval code
end
