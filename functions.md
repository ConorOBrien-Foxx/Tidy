# `curry(fn, arity=fn.arity)`

Returns a function which takes `arity` curried parameters.

```
add := { x, y : x + y }
curriedAdd := curry(add)
add5 := curriedAdd(5)
out(add5(7))                ? 12
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

# `slices(count, enum)` (curries)

Divides `enum` into overlapping windows of size `count`.

```
showln(slices(2, N), 5)
? [[1, 2], [2, 3], [3, 4], [4, 5], [5, 6], ...]
```

# `fac(a)`

Factorial; product of all numbers from `1` to `a`.

```
out(fac(5))     ? 120
out(!5)         ? 120
```

# `sgn(a)`

Returns the sign of `a`; `0` if `a = 0`, `1` if `a > 0`, and `-1` if `a < 0`.

```
out(sgn(5))         ? 1
out(sgn(0))         ? 0
out(sgn(-32))       ? -1
out(sgn(3.1415f))   ? 1
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
