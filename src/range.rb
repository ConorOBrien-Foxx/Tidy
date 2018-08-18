Infinity = Float::INFINITY

module Enumerable
    def tile(n)
        unless block_given?
            return to_enum(__method__, n) {
                sz = size
                sz * n if sz
            }
        end
        each { |*args|
            n.times { yield *args }
        }
    end

    def skip(n)
        unless block_given?
            return to_enum(__method__, n) {
                sz = size
                sz * n if sz
            }
        end
        count = (1..n).cycle
        each { |*args|
            yield *args if count.next == 1
        }
    end

    alias :* :tile
    alias :/ :skip
end

# https://stackoverflow.com/a/16052401/4119004
module LazyEnumerable
  include Enumerable

  def self.make_lazy(*methods)
    methods.each do |method|
      define_method method do |*args, &block|
        lazy.public_send(method, *args, &block)
      end
    end
  end

  def force
      to_a
  end

  make_lazy *(Enumerable.public_instance_methods - [:lazy])
end

class LazyEnumerator
    include LazyEnumerable

    def initialize(&block)
        @enum = Enumerator.new(&block)
    end

    def each(&block)
        @enum.each(&block)
    end
end

def enum_like
    lambda { |x|
        Enumerator === x || LazyEnumerator === x
    }
end

class TidyRange < LazyEnumerator
    def initialize(lower, upper, step = 1, exclude_lower = false, exclude_upper = false)
        @lower = lower
        @upper = upper
        @step = step
        @exclude_lower = exclude_lower
        @exclude_upper = exclude_upper
        @sign = @step <=> 0
    end

    def valid_outer_bound?(i)
        !(@exclude_lower && @lower == i) && !(@exclude_upper && @upper == i)
    end

    def each(&block)
        i = @lower
        until (i <=> @upper) == @sign
            block[i] if valid_outer_bound? i
            i += @step
        end
    end

    def include?(n)
        [
            (n - @lower) % @step == 0,
            n >= @lower,
            n <= @upper,
            valid_outer_bound?(n)
        ].all?
    end
end

def tidy_range(*args)
    range = TidyRange.new(*args)
    if block_given?
        range.map { |args| yield *args }.force
    else
        range
    end
end

class SplicedSequence < LazyEnumerator
    def initialize(*sequences, fill: :none)
        @sequences = sequences
        @fill = fill
    end

    def each(&block)
        copies = @sequences.map(&:to_enum)
        until copies.empty?
            copies.keep_if { |seq|
                begin
                    block[seq.next]
                    true
                rescue StopIteration
                    false
                end
            }
        end
    end
end

def spliced_sequence(*args)
    range = SplicedSequence.new(*args)
    if block_given?
        range.map { |args| yield *args }
    else
        range
    end
end

def recursive_enum(seeds, fn, slice: 1)
    seeds = seeds.to_enum
    LazyEnumerator.new { |out|
        cache = []
        seeds.each { |seed|
            cache << seed
            if cache.size > slice
                cache.shift
            end
            out << seed
        }
        loop {
            val = fn[*cache]
            cache.shift
            cache << val
            out << val
        }
    }
end

if $0 == __FILE__
    require 'irb'
    IRB.start
end
