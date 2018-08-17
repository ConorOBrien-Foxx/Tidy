#!/usr/bin/ruby

require_relative 'src/transpiler.rb'
require 'readline'
require 'prime'

class TidyStopIteration < Exception

end

def to_base(b, n)
    return [n] if n <= 1

    arr = []
    until n.zero?
        n, m = n.divmod b
        arr.unshift m
    end
    arr
end

def from_base(b, a)
    a.map.with_index { |e, i| e * b**(a.size - i - 1) }.sum
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
            when Enumerator, LazyEnumerator
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
    "W" => tidy_range(0, Infinity),
    "eval" => lambda(&method(:eval_tidy)),
    "range" => curry(lambda(&method(:tidy_range)), 2),
    "true" => true,
    "false" => false,
    "nil" => nil,
    "inf" => Infinity,
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
tidy_func_def(:count) { |a, e=:not_passed|
    if e == :not_passed
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
    else
        case e
            when Proc
                a.count(&e)
            else
                a.count(e)
        end
    end
}
tidy_func_def(:enum) { |fn|
    LazyEnumerator.new { |out|
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

def op_slashslash(a, b)
    case [a, b]
        when istype(Numeric, Numeric)
            (a / b).to_i
        when istype(Enumerable, Enumerable)
            chunk a, b
    end
end
def op_dot(a, b)
    raise "no such behaviour"
end

tidy_curry_def(:chunk) { |a, b|
    a, b = a.to_enum, b.to_enum
    LazyEnumerator.new { |out|
        loop {
            begin
                slice_count = a.next
            rescue StopIteration
                break
            end

            build = []
            begin
                slice_count.times {
                    build << b.next
                }
            rescue
                out << build
                break
            end
            out << build
        }
    }
}

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
            lambda { |*args|
                source[index[*args]]
            }
    end
}))

def call_func(fn, *args)
    case fn
        when String
            if $VALID_FUNCTIONS.include? fn
                send fn, *args
            elsif fn == "inf"
                tidy_range(args.first, Infinity)
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

def __
    Proc.new { true }
end

def istype(*types)
    lambda { |arr|
        if Array === arr
            arr.zip(types).map { |el, type| type === el } .all?
        else
            types.size == 1 && types[0] === arr
        end
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
                if right.positive?
                    it = left[n, *rest]
                    (right - 1).times {
                        it = left[it]
                    }
                    it
                else
                    n
                end
            }
        else
            raise "unhandled case #{left.class} and #{right.class}"
    end
end
def op_pipeline(a, b)
    case [a, b]
        when istype(__, Proc)
            b[a]
        when istype(Numeric, Numeric)
            b % a == 0
        else
            raise "invalid arguments for `|`: #{a} and #{fn}"
    end
end
def op_in(a, b)
    b.include? a
end

$variables["primes"] = op_from(-> x { Prime.prime? x }, $variables["N"])
$variables["odds"] = tidy_range(1, Infinity, 2)
$variables["evens"] = tidy_range(0, Infinity, 2)

tidy_func_def(:sum) { |arg|
    arg.inject(0, :+)
}
tidy_func_def(:prod) { |arg|
    arg.inject(1, :*)
}
tidy_curry_def(:base) { |base, n|
    to_base(base, n)
}
tidy_curry_def(:unbase) { |base, n|
    from_base(base, n)
}
tidy_func_def(:bin) { |n|
    to_base(2, n)
}
tidy_func_def(:unbin) { |n|
    from_base(2, n)
}
tidy_func_def(:even) { |n| n.even? }
tidy_func_def(:odd) { |n| n.odd? }
tidy_func_def(:splice) { |*seqs|
    SplicedSequence.new(*seqs)
}

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
