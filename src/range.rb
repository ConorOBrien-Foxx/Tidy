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

class TidyRange
    include Enumerable
    def initialize(lower, upper, step = 1, exclude_lower = false, exclude_upper = false)
        @lower = lower
        @upper = upper
        @step = step
        @exclude_lower = exclude_lower
        @exclude_upper = exclude_upper
    end

    def valid_outer_bound?(i)
        !(@exclude_lower && @lower == i) && !(@exclude_upper && @upper == i)
    end

    def each(&block)
        i = @lower
        until i > @upper
            block[i] if valid_outer_bound? i
            i += @step
        end
    end
end

def tidy_range(*args)
    range = TidyRange.new(*args)
    if block_given?
        range.map { |args| yield *args }
    else
        range.lazy
    end
end

if $0 == __FILE__
    require 'irb'
    IRB.start
end
