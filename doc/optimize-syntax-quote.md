# Optimizing syntax quote

Syntax quote takes and returns code.

- expanding a syntax quote takes computation time and space
  - e.g., (LispReader/syntaxQuote []) => (list 'apply 'vector (cons 'concat (seq [])))
- The returned code must be compiled at compilation time.
  - analyzed, expanded, emitted
  - e.g., (syntax-quote []) => (apply vector (seq (concat))) => (resolve 'apply) / (resolve 'seq) ... => InvokeExpr/.emit => writeClassFile
- The code is executed at runtime.
  - e.g., (syntax-quote []) => (eval '(apply vector (seq (concat)))) => []

The output of LispReader/syntaxQuote has an influence over the cost of later stages.
As long as returns code that evaluates to the correct result, this algorithm can be
improved to return code that is faster to compile and run.

For example when considering (syntax-quote []), [] is equivalent to (apply vector (seq (concat))) (1.12's output),
but [] is faster to both compile and run. Returning [] from LispReader/syntaxQuote also avoids allocations
by returning PersistentVector/EMPTY, and is cheap to compute via (zero? (count v)).

- basically constant folding
  - Q: doesn't that belong in the compiler?
  - A: it may be faster overall to optimize the output of syntax quote.
       e.g., there's less code to retraverse/optimize if you can directly
             generate more efficient code with little overhead.

## Benefits

- syntax quotes compile to fewer bytecode instructions
  - faster macroexpand-1
    - assumption: many defmacro's / macro helpers use syntax quote
    - more computation done ahead-of-time
      - e.g., [] is immediate instead of (apply vector (seq (concat)))
    - improved code loading time
      - from bytecode:
      - from code:
  - lower loading time of syntax-quoted collections by preserving literals
    - better utilize existing code paths in compiler
      - e.g., more opportunities to use IPersistentMap/.mapUniqueKeys rather than IPersistentMap/.map
    - avoid redundant code paths
      - e.g., (syntax-quote nil) => (quote nil) => analyze => analyzeSeq => ConstantExpr/.parse => NilExpr
              vs
              (syntax-quote nil) => nil => analyze => NilExpr
      - e.g., (syntax-quote []) => (apply vector (seq (concat))) => analyze => analyzeSeq => ... => InvokeExpr
              vs
              (syntax-quote []) => [] => analyze => EmptyExpr
      - e.g., (syntax-quote [{:keys [a]}]) => (apply vector (seq (concat [(apply hash-map ...)]))) => analyzeSeq => macroexpand-1 => ... => InvokeExpr<VarExpr,InvokeExpr>
              vs
              (syntax-quote [{:keys [a]}]) => [{:keys ['a]]] => analyze => ... => VectorExpr<MapExpr>
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
- increased compilation time via (excessively) elaborate static analysis
