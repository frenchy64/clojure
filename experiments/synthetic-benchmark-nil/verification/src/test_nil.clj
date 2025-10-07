(ns test-nil)

;; Macro that uses syntax-quoted nil
(defmacro when-not-test [x & body]
  `(if ~x nil (do ~@body)))

;; Another macro with multiple nils
(defmacro returns-nils []
  `[nil nil nil])

;; Function using the macros
(defn use-macros []
  [(when-not-test false :result)
   (returns-nils)])
