# Optimizing syntax quote

- basically constant folding
  - Q: doesn't that belong in the compiler?
  - A: it may be faster overall to optimize the output of syntax quote.
       e.g., there's less code to retraverse/optimize if you can directly
             generate more efficient code with little overhead.

## Benefits

- syntax quotes compile to fewer bytecode instructions
  - (premise: many defmacro's / macro helpers use syntax quote)
  - faster macroexpand-1
    - more computation done ahead-of-time
      - e.g., [] is immediate instead of (apply vector (seq (concat)))
    - improved code loading time
      - from bytecode:
      - from code:
  - lower loading time of syntax-quoted collections by preserving literals
    - better utilize existing code paths in compiler
      - e.g., more opportunities to use IPersistentMap/.mapUniqueKeys rather than IPersistentMap/.map
    - avoid redundant code paths
      - e.g., (syntax-quote nil) => (quote nil) => analyze => analyzeSeq => ConstantExpr/.parse => NIL_EXPR
              vs
              (syntax-quote nil) => nil => analyze => NIL_EXPR
      - e.g., (syntax-quote []) => (apply vector (seq (concat))) => analyze => analyzeSeq => ....=>....
              vs
              (syntax-quote []) => [] => analyze => EmptyExpr([])
      - e.g., (syntax-quote [{:keys [a]}]) => (apply vector (seq (concat [(apply hash-map ...)]))) => analyzeSeq => macroexpand-1 => ... => InvokeExpr
              vs
              (syntax-quote [{:keys [a]}]) => [{:keys ['a]]] => ... => VectorExpr<MapExpr>
  - faster loading of macros
    - fewer instructions to compile
    - tho maybe more work compiling constants
      - see previous point on why it might actually be faster overall
  - smaller AOT footprint for defmacro-heavy libs
    - e.g., clojure.jar 0.5% smaller
  - HotSpot prefers smaller code size
    - more flexibility for inlining (?)

## Risks

- increased minimum memory requirements
  - need to store these larger constants somewhere rather than compute them as needed
- it may indeed be much more effective to implement in compiler
- increased compilation time via elaborate static analysis
