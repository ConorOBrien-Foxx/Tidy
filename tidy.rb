#!/usr/bin/ruby

require_relative 'src/transpiler.rb'
require 'readline'
require 'prime'

class TidyStopIteration < Exception

end

def print_enum(enum, separator=", ", &pr)
    copy = enum.to_enum

    pr = lambda { |x| print x } if pr.nil?

    queue = []

    loop {
        break if until queue.size >= 2
            begin
                queue << copy.next
            rescue StopIteration => e
                break true
            end
        end
        pr[queue.shift] unless queue.empty?
        print separator
    }
    pr[queue.pop] unless queue.empty?

end

$VALID_FUNCTIONS = ["exit"]
def tidy_func_def(name, &block)
    $VALID_FUNCTIONS << name.to_s
    define_method(name) { |*args| block[*args] }
end

tidy_func_def(:curry) { |fn, arity=fn.arity|
    arity = ~arity if arity.negative?
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

tidy_func_def(:put) { |*args|
    args.each { |arg|
        case arg
            when Enumerator
                print "["
                print_enum(arg) { |e|
                    put e
                }
                print "]"
            when File
                print "File(#{arg.path})"
            else
                print arg.inspect
        end
    }
}
tidy_func_def(:out) { |*args|
    args.each { |arg|
        put arg
        print " "
    }
    puts
}
tidy_func_def(:truthy) { |el|
    el != 0 && el
}
tidy_func_def(:readline) { |prompt, hist=true|
    Readline.readline(prompt, hist)
}
tidy_func_def(:write) { |*args|
    output = IO === args.first ? args.shift : STDOUT
    output.write *args.join
}
tidy_func_def(:writeln) { |*args|
    output = IO === args.first ? args.shift : STDOUT
    output.write *args.join, "\n"
}
tidy_func_def(:append) { |source, *vals|
    vals.each { |val| source << val }
    source
}
tidy_func_def(:open) { |file_name, *opts|
    File.open(file_name, *opts)
}
tidy_func_def(:gets) { |object=STDIN|
    object.gets
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
tidy_func_def(:prime) { |n|
    Prime.prime? n
}
$variables = {
    "N" => tidy_range(1, Infinity),
    "eval" => lambda(&method(:eval_tidy)),
    "range" => curry(lambda(&method(:tidy_range)), 2),
    "true" => true,
    "false" => false,
    "nil" => nil,
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
tidy_func_def(:enum) { |fn|
    Enumerator.new { |out|
        fn[out]
    }
}
[:sqrt, :sin, :cos, :tan].each { |k|
    tidy_func_def(k) { |arg| Math.send k, arg }
}
[:floor, :ceil, :round].each { |m|
    tidy_func_def(m) { |arg, prec=nil|
        arg.send m, *[prec].compact
    }
}
tidy_func_def(:c) { |*args| args }

def local_descend
    $locals << {}
end
def local_ascend
    $locals << {}
end

define_method(:op_get, &curry(lambda { |source, index|
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
}))

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
    source.select { |*args| truthy pred[*args] }
end
def op_on(pred, source)
    source.map(&pred)
end
def op_over(qual, source)
    source.inject(&qual)
end

def istype(*types)
    lambda { |arr|
        arr.zip(types).map { |el, type| type === el } .all?
    }
end

def op_caret(left, right)
    case [left, right]
        when istype(Numeric, Numeric)
            left ** right
        when istype(Numeric, Enumerator)
            right.take(left)
        when istype(Enumerator, Numeric)
            left.drop(right)
        when istype(Proc, Numeric)
            lambda { |n, *rest|
                unless right.positive?
                    it = left[n, *rest]
                    (right - 1).times {
                        it = left[it]
                    }
                else
                    n
                end
            }
        else
            raise "unhandled case #{left.class} and #{right.class}"
    end
end

$variables["primes"] = op_from(-> x { Prime.prime? x }, $variables["N"])

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
        opts.on("-r", "--repl", "Engages the repl") { |v|
            options[:repl] = v
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

    code = if options[:repl]
        location = File.join(File.dirname($0), "examples/repl.tidy")
        File.read(location)
    else
        options[:code] || File.read(ARGV[0], encoding: "utf-8")
    end
    tr = Tidy2Ruby.new code
    code = tr.to_a.join("\n")
    puts code if options[:show_code]
    eval code
end
