;   Copyright (c) Rich Hickey. All rights reserved.
;   The use and distribution terms for this software are covered by the
;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
;   which can be found in the file epl-v10.html at the root of this distribution.
;   By using this software in any fashion, you are agreeing to be bound by
;   the terms of this license.
;   You must not remove this notice, or any other, from this software.

; Author: Ambrose Bonnaire-Sergeant

(ns clojure.test-clojure.fn
  (:use clojure.test))

(deftest fn-error-checking
  (testing "bad arglist"
    (is (fails-with-cause? clojure.lang.ExceptionInfo
          #"Call to clojure.core/fn did not conform to spec"
          (eval '(fn "a" a)))))

  (testing "treat first param as args"
    (is (fails-with-cause? clojure.lang.ExceptionInfo
          #"Call to clojure.core/fn did not conform to spec"
          (eval '(fn "a" [])))))

  (testing "looks like listy signature, but malformed declaration"
    (is (fails-with-cause? clojure.lang.ExceptionInfo
          #"Call to clojure.core/fn did not conform to spec"
          (eval '(fn (1))))))

  (testing "checks each signature"
    (is (fails-with-cause? clojure.lang.ExceptionInfo
          #"Call to clojure.core/fn did not conform to spec"
          (eval '(fn
                   ([a] 1)
                   ("a" 2))))))

  (testing "correct name but invalid args"
    (is (fails-with-cause? clojure.lang.ExceptionInfo
          #"Call to clojure.core/fn did not conform to spec"
          (eval '(fn a "a")))))

  (testing "first sig looks multiarity, rest of sigs should be lists"
    (is (fails-with-cause? clojure.lang.ExceptionInfo
          #"Call to clojure.core/fn did not conform to spec"
          (eval '(fn a
                   ([a] 1)
                   [a b])))))
  
  (testing "missing parameter declaration"
    (is (fails-with-cause? clojure.lang.ExceptionInfo
          #"Call to clojure.core/fn did not conform to spec"
          (eval '(fn a))))
    (is (fails-with-cause? clojure.lang.ExceptionInfo
          #"Call to clojure.core/fn did not conform to spec"
          (eval '(fn))))))

; this case is unreachable via Compiler.java since only up to 20 fixed arguments
; are allowed. tests a bug in the invoke() method for RestFn with 21 arguments.
(deftest restfn-arity-exception-test
  ;; example 30 param function given 25 args
  (is (thrown-with-msg? clojure.lang.ArityException
                        #"Wrong number of args \(25\) passed to:.*"
                        (apply (proxy [clojure.lang.RestFn] []
                                 (getRequiredArity [] 30))
                               (range 25))))
  ;; test 21-30 args
  (let [f (proxy [clojure.lang.RestFn] []
            (getRequiredArity [] 30))]
    (doseq [i (range 22 31)
            :let [re (re-pattern (format "Wrong number of args \\(%s\\) passed to:.*" i))]]
      (testing (pr-str re)
        (is (thrown-with-msg? clojure.lang.ArityException
                              re
                              (apply f (range i))))))))
