# Optimizing syntax quote

Syntax quote is a reader macro, taking and returning code. It is primarily used
to construct syntax to return from other macros. A reader macro is expanded
once at read time, and the resulting expansion is then evaluated as code at runtime.

- expanding a syntax quote takes computation time and space
  - must construct lists, symbols, vectors
  - e.g., (LispReader/syntaxQuote []) => (list 'apply 'vector (cons 'concat (seq [])))
- The returned code must be compiled at compilation time.
  - analyzed (expanded, resolved), emitted
  - e.g., (syntax-quote []) => (apply vector (seq (concat))) => (resolve 'apply) / (resolve 'seq) ... => InvokeExpr/.emit => writeClassFile
- The compiled code is executed at runtime.
  - e.g., (syntax-quote []) => (eval '(apply vector (seq (concat)))) => []

The output of LispReader/syntaxQuote has an influence over the cost of later stages.
Inefficiencies in LispReader/syntaxQuote's output could contribute to higher development costs over time.
- a tools.namespace refresh usually triggers macroexpansions, which almost always evaluate syntax-quotes.
  - a single developer could refresh hundreds of times a day triggering thousands of syntax-quote evaluations, multiplied by the number of developers
  - end-to-end performance improvement via syntax-quote optimizations are worth investigating

For example when considering (syntax-quote []), [] is equivalent to (apply vector (seq (concat))) (1.12's output),
but [] is faster to both compile and run. Returning [] from LispReader/syntaxQuote also avoids allocations
by returning PersistentVector/EMPTY, and is cheap to compute via (zero? (count v)).

Each optimizations in LispReader/syntaxQuote also compound positively, similar to adding cases to a constant-folding compiler pass.

For example, consider the constant expression:
```clojure
`(let [{b# :c :keys [~'a]} foo] (+ b# (identity ~'a)))
```

By combining several optimizations around constant folding lists, vectors, maps, and symbols, we can compile this to a single constant:

```
'(clojure.core/let [{b__35__auto__ :c, :keys [a]} user/foo] (clojure.core/+ b__35__auto__ (clojure.core/identity a)))
```

Clojure 1.12 produces a large amount of equivalent code in comparison.

```
user=> '`(let [{b# :c :keys [~'a]} foo] (+ b# (identity ~'a)))
(clojure.core/seq (clojure.core/concat (clojure.core/list (quote clojure.core/let)) (clojure.core/list (clojure.core/apply clojure.core/vector (clojure.core/seq (clojure.core/concat (clojure.core/list (clojure.core/apply clojure.core/hash-map (clojure.core/seq (clojure.core/concat (clojure.core/list (quote b__175__auto__)) (clojure.core/list :c) (clojure.core/list :keys) (clojure.core/list (clojure.core/apply clojure.core/vector (clojure.core/seq (clojure.core/concat (clojure.core/list (quote a)))))))))) (clojure.core/list (quote user/foo)))))) (clojure.core/list (clojure.core/seq (clojure.core/concat (clojure.core/list (quote clojure.core/+)) (clojure.core/list (quote b__175__auto__)) (clojure.core/list (clojure.core/seq (clojure.core/concat (clojure.core/list (quote clojure.core/identity)) (clojure.core/list (quote a))))))))))
```

This highlights why the reader might overall be a better place than the compiler to optimize of the results of syntax-quote,
even though it doesn't really belong there: if syntax-quote were left as-is, the compiler first has to analyze this code, only to then optimize it away.
The output of syntax-quote in 1.12 grows linearly with respect to its input, but the constant factors can be larger than necessary.
If syntax-quote can (somewhat) directly return such constants, there is less code to analyze.

Some comparisons:

```
# clojure 1.12
user=> '`[[[]]]
(clojure.core/apply clojure.core/vector (clojure.core/seq (clojure.core/concat (clojure.core/list (clojure.core/apply clojure.core/vector (clojure.core/seq (clojure.core/concat (clojure.core/list (clojure.core/apply clojure.core/vector (clojure.core/seq (clojure.core/concat)))))))))))

# optimized
clojure.test-clojure.reader=> '`[[[]]]
(quote [[[]]])

# clojure 1.12
user=> '`[1 2 3 4 5]
(clojure.core/apply clojure.core/vector (clojure.core/seq (clojure.core/concat (clojure.core/list 1) (clojure.core/list 2) (clojure.core/list 3) (clojure.core/list 4) (clojure.core/list 5))))

# optimized
clojure.test-clojure.reader=> '`[1 2 3 4 5]
(quote [1 2 3 4 5])
```

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
