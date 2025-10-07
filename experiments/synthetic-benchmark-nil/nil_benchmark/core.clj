(ns nil-benchmark.core
  "Synthetic benchmark for nil syntax-quote optimization.
   
   This namespace contains macros that heavily use syntax-quoted nil
   to demonstrate the impact of the optimization.")

;; Macro 1: Simple conditional with nil default
(defmacro when-not [test & body]
  "Evaluates body when test is false, returns nil otherwise."
  `(if ~test nil (do ~@body)))

;; Macro 2: Optional argument with nil default
(defmacro defn-with-optional [name args & body]
  "Defines a function with optional second argument defaulting to nil."
  `(defn ~name
     ([x#] (~name x# nil))
     ([x# y#] ~@body)))

;; Macro 3: Multiple nil returns in case branches
(defmacro safe-get [map key & [default]]
  "Gets value from map, returns default or nil if not found."
  (if default
    `(get ~map ~key ~default)
    `(get ~map ~key nil)))

;; Macro 4: Nil-heavy cond-like macro
(defmacro when-let-or-nil [bindings & body]
  "Like when-let but explicitly returns nil on false."
  `(let ~bindings
     (if ~(first bindings)
       (do ~@body)
       nil)))

;; Macro 5: Factory with nil initialization
(defmacro defrecord-with-nil-defaults [name fields]
  "Defines a record with all fields defaulting to nil."
  `(do
     (defrecord ~name ~fields)
     (defn ~(symbol (str "make-" name))
       ([] (~(symbol (str "->" name))
            ~@(repeat (count fields) nil)))
       ([& args#] (apply ~(symbol (str "->" name)) args#)))))

;; Test functions using these macros
(defn test-when-not []
  (when-not false
    (println "This executes"))
  (when-not true
    (println "This doesn't")))

(defn-with-optional greet [x y]
  (if y
    (str "Hello " x " and " y)
    (str "Hello " x)))

(defn test-safe-get []
  (let [m {:a 1 :b 2}]
    [(safe-get m :a)
     (safe-get m :c)
     (safe-get m :d "default")]))

(defn test-when-let-or-nil []
  [(when-let-or-nil [x 42] x)
   (when-let-or-nil [x nil] x)])

(defrecord-with-nil-defaults Person [name age email])

(defn test-record []
  (make-Person))
