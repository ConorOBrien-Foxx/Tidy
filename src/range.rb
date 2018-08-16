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

  make_lazy *(Enumerable.public_instance_methods - [:lazy])
end

class TidyRange
    include LazyEnumerable
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
        range.map { |args| yield *args }
    else
        range
    end
end

if $0 == __FILE__
    require 'irb'
    IRB.start
end
