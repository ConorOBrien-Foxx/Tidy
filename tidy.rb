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
            unless $VALID_FUNCTIONS.include? fn
                STDERR.puts "undeclared function #{fn.inspect}"
                exit
            end
            send fn, *args
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
