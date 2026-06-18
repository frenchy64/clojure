(ns clojure.test-clojure.compilation.closure)

(let [a "a"
      b "b"
      c "c"
      d "d"]
  (defn closure [] [a b c d]))
