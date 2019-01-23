#!/usr/bin/ruby

require_relative 'src/transpiler.rb'
require 'readline'
require 'prime'
require 'set'

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

$variables = {
    "N" => tidy_range(1, Infinity),
    "W" => tidy_range(0, Infinity),
    "true" => true,
    "false" => false,
    "nil" => nil,
    "inf" => Infinity,
    "argv" => ARGV,
}

def print_enum(enum, separator=", ", max: Infinity, &pr)
    if Array === enum
        enum.each_with_index { |e, i|
            pr[e]
            print separator unless i + 1 == enum.size
        }
        return
    end
    copy = enum.to_enum

    pr = lambda { |x| print x } if pr.nil?

    queue = []

    count = max == Infinity ? -Infinity : 0
    loop {
        break if until queue.size >= 2
            begin
                queue << copy.next
            rescue StopIteration => e
                break true
            end
        end
        pr[queue.shift] unless queue.empty?
        count += 1
        print separator
        if count >= max
            print "..."
            queue.clear
            break
        end
    }
    pr[queue.pop] unless queue.empty?

end

$FUNCTION_ALIASES = {
    "exit" => "exit"
}
def tidy_func_def(name, global: true, &block)
    name = name.to_s
    key = global ? name : "tidy_#{name}"
    $FUNCTION_ALIASES[name] = key
    define_method(key) { |*args| block[*args] }
end

tidy_func_def(:curry, &lambda { |fn, arity=fn.arity|
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
})

$variables["range"] = curry(lambda(&method(:tidy_range)), 2)

def tidy_curry_def(name, arity=nil, global: true, &block)
    name = name.to_s
    key = global ? name : "tidy_#{name}"
    $FUNCTION_ALIASES[name] = key
    define_method key, &curry(block, arity || block.arity)
end

def eval_tidy(code)
    inst = Tidy2Ruby.new code
    result = inst.to_a.join "\n"
    eval result
end
$variables["eval"] = lambda(&method(:eval_tidy))

tidy_func_def(:show, &lambda { |enum, max=Infinity|
    print "["
    print_enum(enum, max: max) { |e| put e }
    print "]"
})
tidy_func_def(:showln, &lambda { |enum, max=Infinity|
    show enum, max
    puts
})

tidy_func_def(:recur, &lambda { |*args|
    slice = if Numeric === args.last
        args.pop
    else
        1
    end
    *seeds, fn = args
    recursive_enum seeds, fn, slice: slice
})
tidy_func_def(:recur2, &lambda { |*seeds, fn|
    recursive_enum seeds, fn, slice: 2
})
tidy_curry_def(:slices, &lambda { |count, enum|
    enum.each_cons(count)
})
tidy_func_def(:sgn, &lambda { |a| a <=> 0 })

tidy_func_def(:put, &lambda { |*args|
    args.each { |arg|
        case arg
            when enum_like
                show arg, 12
            when File
                print "File(#{arg.path})"
            else
                print arg.inspect
        end
    }
})

tidy_func_def(:out, &lambda { |*args|
    args.each { |arg|
        put arg
        print " "
    }
    puts
})

tidy_func_def(:truthy, &lambda { |el|
    el != 0 && el
})

tidy_func_def(:prompt, &lambda { |prompt, hist=true|
    Readline.readline(prompt, hist)
})

tidy_func_def(:write, &lambda { |*args|
    output = IO === args.first ? args.shift : STDOUT
    output.write *args.join
})

tidy_func_def(:readln, &lambda { |*args|
    input = IO === args.first ? args.shift : STDIN
    input.gets
})

tidy_func_def(:writeln, &lambda { |*args|
    output = IO === args.first ? args.shift : STDOUT
    output.write *args.join, "\n"
})

tidy_func_def(:append, &lambda { |source, *vals|
    vals.each { |val| source << val }
    source
})

tidy_func_def(:open, &lambda { |file_name, *opts|
    File.open(file_name, *opts)
})

tidy_func_def(:close, &lambda { |file_object|
    file_object.close
})

tidy_func_def(:gets, &lambda { |object=STDIN|
    object.gets
})

tidy_func_def(:close, &lambda { |file_object|
    file_object.close
})

tidy_func_def(:cycle, &lambda { |enum, amount=nil|
    enum.cycle(amount)
})

tidy_curry_def(:tile, &lambda { |amount, enum|
    enum.tile(amount)
})

tidy_curry_def(:skip, &lambda { |count, enum|
    enum.skip(count)
})

tidy_curry_def(:take, &lambda { |count, enum|
    enum.take(count)
})

tidy_func_def(:force, &lambda { |enum|
    result = []
    begin
        enum.each { |el|
            result << el
        }
    rescue TidyStopIteration => e
        result
    end
    result
})

tidy_curry_def(:map, &lambda { |fn, enum|
    enum.map { |e| fn[e] }
})

tidy_func_def(:prime, &lambda { |n|
    Prime.prime? n
})

tidy_func_def(:takewhile, &lambda { |cond, enum|
    enum.take_while { |e| truthy cond[e] }
})

tidy_func_def(:dropwhile, &lambda { |cond, enum|
    enum.drop_while { |e| truthy cond[e] }
})

tidy_func_def(:takeuntil, &lambda { |cond, enum|
    enum.take_while { |e| not truthy cond[e] }
})

tidy_func_def(:dropuntil, &lambda { |cond, enum|
    enum.drop_while { |e| not truthy cond[e] }
})

tidy_func_def(:tr, &lambda { |list, fill=nil|
    LazyEnumerator.new { |out|
        enums = list.map(&:to_enum)
        count = enums.size
        loop {
            stop_count = 0
            sublist = enums.map { |enum|
                begin
                    enum.next
                rescue StopIteration
                    stop_count += 1
                    fill
                end
            }
            break if stop_count == count
            out << sublist
        }
    }
})

tidy_func_def(:unite, &lambda { |*lists|
    LazyEnumerator.new { |out|
        tally = Set[]
        lists.each { |list|
            [*list].each { |el|
                next if tally.include? el
                tally << el
                out << el
            }
        }
    }
})

# apparently intersection with possibly-infinite lists is non-trivial
tidy_func_def(:intersect, &lambda { |*lists|
    LazyEnumerator.new { |out|
        candidates = Hash.new { |h, q|
            h[q] = Set[]
        }
        tally = Set[:none]
        size = lists.size

        iter = tr(lists, :none).to_enum

        ## candidate selection
        c = nil
        loop {
            c = iter.next

            c.each_with_index { |e, i|
                # ignore included entries
                next if tally.include? e

                # otherwise, append `i` to `e`s index list
                candidates[e] << i

                # if all indices are accounted for
                if candidates[e].size == size
                    # add it to the tally and update the candidate list
                    out << e
                    candidates.delete e
                    tally << e
                end
            }

            # if there are any :none values, we can begin redemption
            break if c.include? :none
        }

        ## candidate redemption
        # the indices to track
        invalid = (0...c.size).select { |e| c[e] != :none }
        # remove any members having invalid indices
        candidates.reject! { |e, inds|
            inds.any? { |i| invalid.include? i }
        }
        # remove defaulting behavior
        candidates.default_proc = nil

        until candidates.empty?
            c = iter.next
            # TODO: figure out if this next line is necessary
            break if c.all? :none

            c.each_with_index { |e, i|
                next if tally.include? e

                candidates[e] << i if candidates.include? e
                # if the candidate exists and is filled
                if candidates[e]&.size == size
                    out << e
                    candidates.delete e
                    tally << e
                end
            }
        end
    }
})

$locals = [{}]
tidy_func_def(:set_var, &lambda { |name, val|
    $variables[name] = val
})

tidy_func_def(:set_var_local, &lambda { |name, val|
    $locals.last[name] = val
})

tidy_func_def(:get_var, &lambda { |name|
    local = $locals.reverse.find { |local| local.has_key? name }
    # puts ">>>>>>>>>>>>>>"
    # puts $locals
    # puts
    # puts
    if local
        local[name]
    elsif $variables.has_key? name
        $variables[name]
    elsif $FUNCTION_ALIASES.has_key? name
        lambda(&method($FUNCTION_ALIASES[name]))
    else
        raise "undefined variable/function #{name}"
    end
})

$locals_list = []
def local_adopt(new_local)
    $locals_list << $locals
    $locals = new_local
end

def local_evict
    $locals = $locals_list.pop
end

def local_save
    $locals.map(&:dup)
end


def local_unfreeze
    $locals = $locals_list.pop
end

def local_descend
    $locals << {}
end

def local_ascend
    $locals.pop
end

tidy_func_def(:float, global: false, &lambda { |e|
    e.to_f
})
tidy_func_def(:int, global: false, &lambda { |e, *args|
    e.to_i *args
})

tidy_func_def(:count, global: false, &lambda { |a, e=:not_passed|
    if e == :not_passed
        case a
            when Array, String
                a.size
            when enum_like
                a.force.size
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
})

tidy_func_def(:enum, &lambda { |fn|
    LazyEnumerator.new { |out|
        fn[out]
    }
})

tidy_func_def(:I, global: false, &lambda { |es|
    LazyEnumerator.new { |o|
        es.each_with_index { |e, i|
            o << i
        }
    }
})

tidy_func_def(:prefixes, &lambda { |es|
    tidy_I(es).map { |i|
        op_get(es, tidy_range(0, i))
    }
})

tidy_func_def(:suffixes, &lambda { |es|
    tidy_I(es).map { |i|
        op_get(es, tidy_range(~i, -1))
    }
})

tidy_func_def(:stoa, &lambda { |str|
    str.chars.map { |c| Character.new c }
})

[:sqrt, :sin, :cos, :tan].each { |k|
    tidy_func_def(k, &lambda { |arg| Math.send k, arg })
}
[:floor, :ceil, :round].each { |m|
    tidy_func_def(m, &lambda { |arg, prec=nil|
        arg.send m, *[prec].compact
    })
}
tidy_func_def(:c, &lambda { |*args| args })
tidy_func_def(:int, &lambda { |n, base=10| n.to_i base rescue n.to_i })
tidy_func_def(:str, &lambda { |n, *args| n.to_s *args })
tidy_func_def(:chr, &lambda { |a| Character.new a })
tidy_func_def(:first, global: false, &lambda { |coll, n=:not_passed|
    if n == :not_passed
        coll.first
    else
        n.first coll
    end
})
tidy_func_def(:last, global: false, &lambda { |coll, n=:not_passed|
    if n == :not_passed
        coll.last
    else
        coll.last n
    end
})

def op_slashslash(a, b)
    case [a, b]
        when istype(Numeric, Numeric)
            (a / b).to_i
        when istype(Enumerable, Enumerable)
            chunk a, b
    end
end

def op_dot(a, b)
    "#{a}#{b}"
end

tidy_curry_def(:chunk, &lambda { |a, b|
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
})

tidy_func_def(:log, global: false, &lambda { |n, base=10|
    Math::log n, base
})

tidy_func_def(:fchunk, global: false, &lambda { |list, fn|
    list.chunk { |e|
        fn[e]
    }
})

tidy_curry_def(:index, global: false, &lambda { |a, needle, start=0|
    found = nil
    start ||= 0
    a.drop(start).each_with_index { |e, i|
        break found = i if e == needle
    }
    found
})

define_method(:op_get, &curry(lambda { |source, index|
    if enum_like[index] || Array === index
        index.map { |i|
            op_get(source, i)
        }
        
    else
        # function composition
        if Proc === source
            lambda { |*args|
                source[index[*args]]
            }
        
        # inbuilt indexing
        elsif source.respond_to? :[]
            source[index]
            
        # brute force indexing
        elsif enum_like[source]
            if index < 0
                if source.respond_to? :reverse
                    op_get(source.reverse, -index)
                else
                    source.force[index]
                end
            else
                source.take(index + 1).force[index]
                end
        
        # error
        else
            raise "idk"
        end
    end
}))

tidy_func_def(:same, &lambda { |*args|
    args = args.flatten
    args.all? { |e| e == args.first }
})
tidy_func_def(:join, global: false, &lambda { |a, b=""|
    a = a.force if not (a.respond_to? :join) && enum_like[a]
    a.join b
})
tidy_func_def(:split, global: false, &lambda { |a, b=/\s+/|
    a = a.force if enum_like[a]
    a.split b
})

def call_func(fn, *args)
    case fn
        when String
            if $FUNCTION_ALIASES.has_key? fn
                send $FUNCTION_ALIASES[fn], *args
            elsif fn == "inf"
                tidy_range(args.first, Infinity)
            elsif fn = get_var(fn)
                call_func(fn, *args)
            else
                STDERR.puts "undeclared function #{fn.inspect}"
                exit
            end
        when Proc
            fn[*args]
        when Array
            fn[*args]
        when enum_like
            # TODO: make more efficent (don't store results in array)
            if args.size > 3
                raise "unsupported arity for indexing #{args.size}"
            end
            if args.any? &:negative?
                fn = fn.to_a
                args.map! { |e|
                    e.negative? ? e + fn.size : e
                }
            end
            case args.size
                when 1
                    index = args[0]
                    fn.take(index + 1).to_a[index]
                when 2
                    start, finish = args
                    fn.take(start + finish + 1).to_a[start..finish]
                when 3
                    range = tidy_range(*args)

                    array = fn.take(range.min + range.max + 1).to_a
                    range.map { |i|
                        array[i]
                    }
            end
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
    if Proc === source
        lambda { |*args|
            op_on(pred, source[*args])
        }
    else
        source.map { |e|
            call_func pred, e
        }
    end
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
        when istype(Numeric, enum_like)
            right.first(left)
        when istype(enum_like, Numeric)
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
            raise "invalid arguments for `|`: #{a} and #{b}"
    end
end
def op_in(a, b)
    b.include? a
end

$variables["primes"] = op_from(-> x { Prime.prime? x }, $variables["N"])
$variables["odds"] = tidy_range(1, Infinity, 2)
$variables["evens"] = tidy_range(0, Infinity, 2)

tidy_func_def(:digits, &lambda { |e|
    e.digits.reverse
})
tidy_func_def(:min, &lambda { |*a|
    a = a.flatten.map { |e|
        if e.respond_to? :min
            e.min
        elsif enum_like[e]
            e.to_a.min
        else
            e
        end
    }

    a.empty? ? -Infinity : a.min
})
tidy_func_def(:max, &lambda { |*a|
    a = a.flatten.map { |e|
        if e.respond_to? :max
            e.max
        elsif enum_like[e]
            e.to_a.max
        else
            e
        end
    }

    a.empty? ? Infinity : a.max
})
tidy_func_def(:rev, &lambda { |arr|
    arr.reverse rescue arr.to_a.reverse
})
tidy_func_def(:sum, &lambda { |arg|
    arg.inject(0, :+)
})
tidy_func_def(:prod, &lambda { |arg|
    arg.inject(1, :*)
})
tidy_curry_def(:base, &lambda { |base, n|
    to_base(base, n)
})
tidy_curry_def(:unbase, &lambda { |base, n|
    from_base(base, n)
})
tidy_func_def(:bin, &lambda { |n|
    to_base(2, n)
})
tidy_func_def(:unbin, &lambda { |n|
    from_base(2, n)
})
tidy_func_def(:even, &lambda { |n| n.even? })
tidy_func_def(:odd, &lambda { |n| n.odd? })
tidy_func_def(:splice, &lambda { |*seqs|
    SplicedSequence.new(*seqs)
})
tidy_func_def(:load, global: false, &lambda { |file_name|
    content = File.read(file_name, encoding: "utf-8")
    t2r = Tidy2Ruby.new content
    eval t2r.to_a.join("\n")
})

# pattern string functions

tidy_func_def(:pt_w, &lambda { |str|
    str.split
})

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
        opts.on("-o", "--out-file FILE", "Generates a compiled output") { |v|
            options[:out_file] = v
        }
        opts.on("-r", "--repl", "Engages the repl") { |v|
            options[:repl] = v
        }
        opts.on("-t", "--tokenize", "Tokenizes the program") { |v|
            options[:tokenize] = v
        }
        opts.on("-a", "--ast", "Shunts and generates the AST for the program") { |v|
            options[:ast] = v
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

    if options[:tokenize]
        TidyTokenizer.new(code).each { |token|
            p token
        }
        exit
    elsif options[:ast]
        puts "]]] SHUNTING"
        shunt(code) { |e| p e }
        puts "]]] AST"
        puts ast(code)
        exit
    end
    tr = Tidy2Ruby.new code
    code = tr.to_a.join("\n")
    puts code if options[:show_code]
    if options[:out_file]
        out = File.open(options[:out_file], "w")
        out.write "require_relative 'tidy.rb'\n"
        out.write code
    else
        error_caught = nil

        eval <<~EOF
            begin
                #{code}
            rescue Exception => e
                error_caught = e
            end
        EOF

        raise error_caught unless error_caught.nil?
    end
end
