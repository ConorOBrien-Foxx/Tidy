#!/usr/bin/ruby

require_relative 'src/transpiler.rb'

def out(*args)
    p *args.map { |e|
        if Enumerator === e
            e.force
        else
            e
        end
    }
end

def op_get(source, index)
    case source
        when Array, String
            source[index]
        when Enumerable
            if index < 0
                source.force[index]
            else
                source.take(index + 1).force[i]
            end
        else
            raise "no such thing"
    end
end

$VALID_FUNCTIONS = ["out"]
def call_func(fn, *args)
    case fn
        when String
            raise unless $VALID_FUNCTIONS.include? fn
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
