# `append(source, *vals)`

Modifies the value of `source` such that each value in `vals` is appended to the end sequentially.

```
thing := c(4, 9, 2)
out(thing)                      ? [4, 9, 2]

append(thing, "foo")
out(thing)                      ? [4, 9, 2, "foo"]

append(thing, 3, 9, "bar")
out(thing)                      ? [4, 9, 2, "foo", 3, 9, "bar"]
```

# `approx(a, b)`

Returns if `a` is approximately equal to `b`; `abs(a - b) < eps`.

```
p3 := 3 * 0.1f
out(p3)                 ? 0.30000000000000004
out(approx(p3, 0.3))    ? true
out(p3 =~ 0.3)          ? true
out(p3 ≈ 0.3)           ? true
eps := 1e-20
out(approx(p3, 0.3))    ? false
eps := 2
out(approx(3, 4))       ? true
out(approx(3, 5))       ? false
```

# `approxmuchless(a, b)`

Returns if a is much less than b, or approximately there. `a <= rfac * b || approx(a, rfac * b)`.

```
p := 3 * 0.1f
muchless(p, 3)          ? false
approxmuchless(p, 3)    ? true
p <~ 3                  ? true
p ≲ 3                   ? true
```


# `approxmuchmore(a, b)`

Returns if a is much more than b, or approximately there. `a * rfac >= b || approx(a * rfac, b)`.

```
p := 3 * 0.1f
muchmore(3, p)          ? false
approxmuchmore(3, p)    ? true
3 >~ p                  ? true
3 ≳ p                   ? true
```

# `curry(fn, arity=fn.arity)`

Returns a function which takes `arity` curried parameters.

```
add := { x, y : x + y }
curriedAdd := curry(add)
add5 := curriedAdd(5)
out(add5(7))                ? 12
```

# `fac(a)`

Factorial; product of all numbers from `1` to `a`.

```
out(fac(5))     ? 120
out(!5)         ? 120
```

# `muchless(a, b)`

Tests whether or not a is much less than b (a ≪ b); `a <= rfac * b`. `rfac` is `0.1` by default.

```
muchless(1, 10)         ? true
1 << 10                 ? true
1 ≪ 10                  ? true
muchless(1, 9)          ? false
rfac := 0.5
muchless(1, 9)          ? true
1 <= 9 * rfac           ? true
```

# `muchmore(a, b)`

Tests whether or not a is much more than b (a ≫ b); `a * rfac >= b`. `rfac` is `0.1` by default.

```
muchmore(10, 1)         ? true
10 >> 1                 ? true
1 ≫ 10                  ? true
muchmore(9, 1)          ? false
rfac := 0.5
muchmore(9, 1)          ? true
9 * rfac >= 1           ? true
```

# `muchmuchless(a, b)`

Tests whether or not a is much, _much_ less than b (a ⫷ b); `a <= rfac2 * b`. `rfac2` is `0.01` by defualt.

```
muchmuchless(1, 100)    ? true
1 <<< 100               ? true
1 ⫷ 100                 ? true
muchmuchless(1, 50)     ? false
rfac2 := 0.02
muchmuchless(1, 50)     ? true
```


# `muchmuchmore(a, b)`

Tests whether or not a is much, _much_ less than b (a ⫸ b); `a * rfac2 >= b`. `rfac2` is `0.01` by defualt.

```
muchmuchless(100, 1)    ? true
100 >>> 1               ? true
100 ⫸ 1                 ? true
muchmuchless(50, 1)     ? false
rfac2 := 0.02
muchmuchless(50, 1)     ? true
```

# `out(*args)`

Calls `put(arg)` for each `arg` in `args`, separated by spaces, and followed by a trailing newline.

# `prompt(display, hist=true)`

Prompts the user for keyboard input, displaying the string `display`. `hist` determines whether or not the user's past inputs are allowed to be accessed.

# `put(*args)`

Outputs each element `arg` in `args`, depending on the type:

 - `enum_like` - `show(arg, 12)`
 - `File` - `File(arg's path)`
 - `other` - the default representation of `arg`

# `readln([input])`

Reads a line of input from `input`, or `STDIN` if not provided.

# `recur(*seeds, fn, slice=1)`

Yields a recursively-generated list by using successive windows of size `slice`. The resulting list starts out with each element in `seeds`, then with successive iterations of `fn` over the previous `slice` members. Here are some symbolic examples:

```
recur(x, y, f, 1) =
[x, y, f(y), f(f(y)), f(f(f(y))), ...]

recur(x, y, f, 2) =
[x, y, f(x, y), f(y, f(x, y)), f(f(x, y), f(y, f(x, y))), ...]
```

Or, with actual functions:

```
fibonacci := recur(0, 1, (+), 2)
out(fibonacci)
? [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, ...]

? tribonacci
out(recur(0, 0, 1, sum@c, 3))
? [0, 0, 1, 1, 2, 4, 7, 13, 24, 44, 81, 149, ...]
```

# `recur2(*seeds, fn)`

Same as `recur(*seeds, fn, 2)`.

```
fibonacci := recur2(0, 1, (+))
out(fibonacci)
? [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, ...]
```

# `sgn(a)`

Returns the sign of `a`; `0` if `a = 0`, `1` if `a > 0`, and `-1` if `a < 0`.

```
out(sgn(5))         ? 1
out(sgn(0))         ? 0
out(sgn(-32))       ? -1
out(sgn(3.1415f))   ? 1
```

# `show(enum, limit=Infinity)`

Displays the entries in `enum`, up to `limit` entries.

```
show([1, 5])    ? [1, 2, 3, 4, 5]
show(N, 5)      ? [1, 2, 3, 4, 5, ...]
show(N)         ? outputs [1, 2, 3, 4, 5, 6, 7, 8, 9, etc.
```

# `showln(enum, limit=Infinity)`

Equivalent to `show(enum, limit); out()`. That is, `show` followed by a newline.

# `slices(count, enum)` (curries)

Divides `enum` into overlapping windows of size `count`.

```
showln(slices(2, N), 5)
? [[1, 2], [2, 3], [3, 4], [4, 5], [5, 6], ...]
```

# `truthy(el)`

Returns `true` if `el` is not `false`, `0` or `chr(0)`, `false` otherwise.

```
? all of the following return `true`
truthy(1)
truthy(2)
truthy("0")
truthy(chr(1))
truthy('0)
truthy(0.1)
truthy(true)

? ...and all of the following return `false`
truthy(0)
truthy(0.0)
truthy(chr(0))
truthy(false)
```

# `repr(el)`

Returns the representation of `el`, usually in terms of how to programmatically generate the argument.

# `write([output, ]*args)`

Writes `args` joined by an empty string to `output`, or, if the first argument is not an IO object, to `STDOUT`.

# `writeln(*args)`

Equivalent to `write(args); out()`.
