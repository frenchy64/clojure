;   Copyright (c) Rich Hickey. All rights reserved.
;   The use and distribution terms for this software are covered by the
;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
;   which can be found in the file epl-v10.html at the root of this distribution.
;   By using this software in any fashion, you are agreeing to be bound by
;   the terms of this license.
;   You must not remove this notice, or any other, from this software.

; Author: Ambrose Bonnaire-Sergeant

(ns clojure.test-clojure.fn
  (:use clojure.test)
  ;; for fails-with-cause?
  (:require clojure.test-helper))

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

(deftest fixed-arg-fn-infinite-args
  (doseq [i (range 1 40)]
    (testing i
      (is (thrown-with-msg? clojure.lang.ArityException
                            (re-pattern
                              (format "Wrong number of args \\(%s\\) passed to:.*"
                                      i))
                            (apply (fn []) (range i))))))
  (doseq [i (range 40 80)]
    (testing i
      (is (thrown-with-msg? clojure.lang.ArityException
                            #"Wrong number of args \(-1\) passed to:.*"
                            (apply (fn []) (range i))))))
  (is (thrown-with-msg? clojure.lang.ArityException
                        #"Wrong number of args \(-1\) passed to:.*"
                        (apply (fn []) (range))))
  (are [?f] (thrown-with-msg? clojure.lang.ArityException
                              #"Wrong number of args \(-1\) passed to:.*"
                              (apply ?f (range)))
       identity fnil (map identity) (keep identity)))
