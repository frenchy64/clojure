```clojure
Clojure 1.12.5
user=> (defn f ^long [^long a] a)
#'user/f
user=> (add-watch #'f ::undo-prim (fn [_ _ old new] (when (and (instance? clojure.lang.IFn$LL old) (not (instance? clojure.lang.IFn$LL new))) (println "WARNING: removed clojure.lang.IFn$LL from f"))))
#'user/f
user=> (defn f [a] a)
WARNING: removed clojure.lang.IFn$LL from f
#'user/f
```
