# `curry(fn, arity=fn.arity)`

Returns a function which takes `arity` curried parameters.

```
add := { x, y : x + y }
curriedAdd := curry(add)
add5 := curriedAdd(5)
out(add5(7))    ? 12
```
