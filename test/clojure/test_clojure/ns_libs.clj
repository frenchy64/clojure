;   Copyright (c) Rich Hickey. All rights reserved.
;   The use and distribution terms for this software are covered by the
;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
;   which can be found in the file epl-v10.html at the root of this distribution.
;   By using this software in any fashion, you are agreeing to be bound by
;   the terms of this license.
;   You must not remove this notice, or any other, from this software.

; Authors: Frantisek Sodomka, Stuart Halloway

(ns clojure.test-clojure.ns-libs
  (:use clojure.test)
  (:require clojure.test-helper))

; http://clojure.org/namespaces

; in-ns ns create-ns
; alias import intern refer
; all-ns find-ns
; ns-name ns-aliases ns-imports ns-interns ns-map ns-publics ns-refers
; resolve ns-resolve namespace
; ns-unalias ns-unmap remove-ns


; http://clojure.org/libs

; require use
; loaded-libs

(deftest test-alias
	(is (thrown-with-msg? Exception #"No namespace: epicfail found" (alias 'bogus 'epicfail))))
	
(deftest test-require
         (is (thrown? Exception (require :foo)))
         (is (thrown? Exception (require))))

(deftest test-use
         (is (thrown? Exception (use :foo)))
         (is (thrown? Exception (use))))

(deftest reimporting-deftypes
  (let [inst1 (binding [*ns* *ns*]
                (eval '(do (ns exporter)
                           (defrecord ReimportMe [a])
                           (ns importer)
                           (import exporter.ReimportMe)
                           (ReimportMe. 1))))
        inst2 (binding [*ns* *ns*]
                (eval '(do (ns exporter)
                           (defrecord ReimportMe [a b])
                           (ns importer)
                           (import exporter.ReimportMe)
                           (ReimportMe. 1 2))))]
    (testing "you can reimport a changed class and see the changes"
      (is (= [:a] (keys inst1)))
      (is (= [:a :b] (keys inst2))))
    ;fragile tests, please fix
    #_(testing "you cannot import same local name from a different namespace"
      (is (thrown? clojure.lang.Compiler$CompilerException
                  #"ReimportMe already refers to: class exporter.ReimportMe in namespace: importer"
                  (binding [*ns* *ns*]
                    (eval '(do (ns exporter-2)
                               (defrecord ReimportMe [a b])
                               (ns importer)
                               (import exporter-2.ReimportMe)
                               (ReimportMe. 1 2)))))))))

(deftest naming-types
  (testing "you cannot use a name already referred from another namespace"
    (is (thrown-with-msg? IllegalStateException
                          #"String already refers to: class java.lang.String"
                          (definterface String)))
    (is (thrown-with-msg? IllegalStateException
                          #"StringBuffer already refers to: class java.lang.StringBuffer"
                          (deftype StringBuffer [])))
    (is (thrown-with-msg? IllegalStateException
                          #"Integer already refers to: class java.lang.Integer"
                          (defrecord Integer [])))))

(deftest resolution
  (let [s (gensym)]
    (are [result expr] (= result expr)
         #'clojure.core/first (ns-resolve 'clojure.core 'first)
         nil (ns-resolve 'clojure.core s)
         nil (ns-resolve 'clojure.core {'first :local-first} 'first)
         nil (ns-resolve 'clojure.core {'first :local-first} s))))
  
(deftest refer-error-messages
  (let [temp-ns (gensym)]
    (binding [*ns* *ns*]
      (in-ns temp-ns)
      (eval '(def ^{:private true} hidden-var)))
    (testing "referring to something that does not exist"
      (is (thrown-with-msg? IllegalAccessError #"nonexistent-var does not exist"
            (refer temp-ns :only '(nonexistent-var)))))
    (testing "referring to something non-public"
      (is (thrown-with-msg? IllegalAccessError #"hidden-var is not public"
            (refer temp-ns :only '(hidden-var)))))))

(deftest test-defrecord-deftype-err-msg
  (is (thrown-with-cause-msg? clojure.lang.Compiler$CompilerException
                        #"defrecord and deftype fields must be symbols, user\.MyRecord had: :shutdown-fn"
                        (eval '(defrecord MyRecord [:shutdown-fn]))))
  (is (thrown-with-cause-msg? clojure.lang.Compiler$CompilerException
                        #"defrecord and deftype fields must be symbols, user\.MyType had: :key1"
                        (eval '(deftype MyType [:key1])))))

(deftest require-as-alias
  ;; :as-alias does not load
  (require '[not.a.real.ns [foo :as-alias foo]
                           [bar :as-alias bar]])
  (let [aliases (ns-aliases *ns*)
        foo-ns (get aliases 'foo)
        bar-ns (get aliases 'bar)]
    (is (= 'not.a.real.ns.foo (ns-name foo-ns)))
    (is (= 'not.a.real.ns.bar (ns-name bar-ns))))

  (is (= :not.a.real.ns.foo/baz (read-string "::foo/baz")))

  ;; can use :as-alias in use, but load will occur
  (use '[clojure.walk :as-alias e1])
  (is (= 'clojure.walk (ns-name (get (ns-aliases *ns*) 'e1))))
  (is (= :clojure.walk/walk (read-string "::e1/walk")))

  ;; can use both :as and :as-alias
  (require '[clojure.set :as n1 :as-alias n2])
  (let [aliases (ns-aliases *ns*)]
    (is (= 'clojure.set (ns-name (get aliases 'n1))))
    (is (= 'clojure.set (ns-name (get aliases 'n2))))
    (is (= (resolve 'n1/union) #'clojure.set/union))
    (is (= (resolve 'n2/union) #'clojure.set/union))))

(deftest require-as-alias-then-load-later
  ;; alias but don't load
  (require '[clojure.test-clojure.ns-libs-load-later :as-alias alias-now])
  (is (contains? (ns-aliases *ns*) 'alias-now))
  (is (not (nil? (find-ns 'clojure.test-clojure.ns-libs-load-later))))

  ;; not loaded!
  (is (nil? (resolve 'alias-now/example)))

  ;; load
  (require 'clojure.test-clojure.ns-libs-load-later)

  ;; now loaded!
  (is (not (nil? (resolve 'alias-now/example)))))

(def ^:dynamic *coord* nil)

(deftest requiring-resolve-atomic-load-test
  (remove-ns 'clojure.test-clojure.ns-libs-requiring-resolve-atomic)
  (dosync (alter @#'clojure.core/*loaded-libs* disj 'clojure.test-clojure.ns-libs-requiring-resolve-atomic))
  (let [start-right (promise)
        right-started (promise)
        finish-loading (promise)
        right-load (atom false)
        _ (is (not (find-ns 'clojure.test-clojure.ns-libs-requiring-resolve-atomic)))
        _ (is (not (contains? @@#'clojure.core/*loaded-libs* 'clojure.test-clojure.ns-libs-requiring-resolve-atomic)))
        left (future
               (with-bindings {;#'*loading-verbosely* true
                               #'*coord* (fn []
                                           (deliver start-right true)
                                           @finish-loading)}
                 @(requiring-resolve 'clojure.test-clojure.ns-libs-requiring-resolve-atomic/a)))
        right (future
                @start-right
                (with-bindings {;#'*loading-verbosely* true
                                #'*coord* (fn [] (reset! right-load true))}
                  (deliver right-started true)
                  @(requiring-resolve 'clojure.test-clojure.ns-libs-requiring-resolve-atomic/a)))]
    (try (is (= true (deref start-right 5000 ::blocked)))
         (is (= true (deref right-started 5000 ::blocked)))
         (is (= ::blocked (deref left 2000 ::blocked)))
         (is (= ::blocked (deref right 2000 ::blocked)))
         (is (= ::blocked (deref finish-loading 2000 ::blocked)))
         (is (not @right-load))
         (is (find-ns 'clojure.test-clojure.ns-libs-requiring-resolve-atomic))
         (is (not (contains? @@#'clojure.core/*loaded-libs* 'clojure.test-clojure.ns-libs-requiring-resolve-atomic)))
         (deliver finish-loading true)
         (is (= 2 (deref left 1000 ::left-blocked)))
         (is (= 2 (deref right 1000 ::right-blocked)))
         (is (not @right-load))
         (is (find-ns 'clojure.test-clojure.ns-libs-requiring-resolve-atomic))
         (is (contains? @@#'clojure.core/*loaded-libs* 'clojure.test-clojure.ns-libs-requiring-resolve-atomic))
         (finally
           (run! #(deliver % true) [start-right right-started finish-loading])))))

(deftest self-requiring-resolve-test
  (remove-ns 'clojure.test-clojure.ns-libs-requiring-resolve-self)
  (dosync (alter @#'clojure.core/*loaded-libs* disj 'clojure.test-clojure.ns-libs-requiring-resolve-self))
  (is (nil? (resolve 'clojure.test-clojure.ns-libs-requiring-resolve-self/a)))
  (require 'clojure.test-clojure.ns-libs-requiring-resolve-self)
  (is (= 1 @(resolve 'clojure.test-clojure.ns-libs-requiring-resolve-self/a))))

(deftest repl-requiring-resolve-test
  (let [temp-ns (gensym)]
    (binding [*ns* *ns*]
      (eval (list `ns temp-ns))
      (is (nil? (requiring-resolve (symbol (str temp-ns) "missing"))))
      (eval (list 'def 'missing 1))
      (is (= 1 @(requiring-resolve (symbol (str temp-ns) "missing")))))))
