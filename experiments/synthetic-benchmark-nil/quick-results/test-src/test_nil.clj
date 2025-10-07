(ns test-nil)

;; Simple macro with nil
(defmacro when-not-test [x]
  `(if ~x nil :result))

;; Function using the macro
(defn use-when-not []
  (when-not-test false))

;; Macro with multiple nils
(defmacro return-nils []
  `[nil nil nil])

;; Function using multiple nils
(defn use-nils []
  (return-nils))
