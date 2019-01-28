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
```
