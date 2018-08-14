# Tidy

Tidy is a language made for the ["**Range**" Language Design Challenge](https://chat.stackexchange.com/transcript/message/46169592#46169592).

## What is a range?

I define a range as an iterable, possibly infinite sequence of numbers, with some sort of start and end point. I will use the following notation to talk about ranges:

```
[a, b] = all integers between a and b inclusive
[a, b[ = all integers between a and b, excluding b
]a, b] = all integers between a and b, excluding a
]a, b[ = all integers between a and b, excluding a and b
```

The bounds can be infinite. For example, `[1, ∞)` is the range starting at one and continuing infinitely.

## How does the language operate?

Tidy operates on many data types, particularly, through transforming ranges. Let's frame a few problems with these types of ranges.

Suppose we want to check if a number `n` is prime. We know that `n` cannot be prime if it has any divisors. We know all divisors of `n` lie in the range `[2, n)`. Consider the following code:

```
divisors := { x, n : n mod x = 0 } from [2, n[

[2, n[.tile 2
```

Let's decompose this. `[2, n[`.
