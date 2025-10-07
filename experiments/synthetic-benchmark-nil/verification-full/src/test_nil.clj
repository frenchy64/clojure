(ns test-nil)

;; Macro 1: Simple conditional with syntax-quoted nil
(defmacro when-not-test [x & body]
  `(if ~x nil (do ~@body)))

;; Macro 2: Returns vector of nils
(defmacro returns-nils []
  `[nil nil nil])

;; Macro 3: Map with nil values
(defmacro nil-map []
  `{:a nil :b nil})

;; Functions using the macros
(defn use-when-not []
  (when-not-test false :success))

(defn use-nils []
  (returns-nils))

(defn use-nil-map []
  (nil-map))
