;   Copyright (c) Rich Hickey. All rights reserved.
;   The use and distribution terms for this software are covered by the
;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
;   which can be found in the file epl-v10.html at the root of this distribution.
;   By using this software in any fashion, you are agreeing to be bound by
;   the terms of this license.
;   You must not remove this notice, or any other, from this software.

(ns clojure.test-clojure.test-uncaught
  (:use clojure.test))

(def test-var-tests-prefix "test-var-exception-test-")

(defmacro deftests-for-test-var
  "Define unit tests for clojure.test/test-var functionality. See
  `test-ns-hook` in this namespace for special handling.

  Each test should throw an exception with {::expected true} ex-data,
  and the expected :error report :message should be attached via the ::expected-test-var-message
  key of the test name's metadata."
  [& ts]
  {:pre [(even? (count ts))]}
  `(do ~@(map (fn [[nme & body]]
                {:pre [(simple-symbol? nme)]}
                `(deftest ~(with-meta (symbol (str test-var-tests-prefix (name nme)))
                                      (meta nme))
                   ~@body))
              (partition 2 ts))))

(deftests-for-test-var
  ;; testing that an expected error under an empty testing context gives "Uncaught exception, not in assertion."
  ^{::expected-test-var-message "Uncaught exception, not in assertion."}
  thrown-from-empty-context-test
  (throw (ex-info "" {::expected true}))

  ;; testing that a rethrown expected error under an empty testing context gives "Uncaught exception, not in assertion."
  ^{::expected-test-var-message "Uncaught exception, not in assertion."}
  rethrown-between-empty-contexts-test
  (let [e (try (binding [*testing-contexts* (list)]
                 (throw (ex-info "" {::expected true})))
               (catch Exception e e))]
   (binding [*testing-contexts* (list)]
     (throw e)))

  ;; testing that an expected error under testing context "foo bar" gives "foo bar"
  ^{::expected-test-var-message "foo bar"}
  nested-exception-test
  (testing "foo"
    (testing "bar"
      (throw (ex-info "" {::expected true}))))

  ;; also works with longer testing contexts
  ^{::expected-test-var-message "foo bar 1 2 3 4 5"}
  long-nested-exception-test
  (testing "foo"
    (testing "bar"
      (testing "1"
        (testing "2"
          (testing "3"
            (testing "4"
              (testing "5"
                (throw (ex-info "" {::expected true})))))))))

  ;; testing that exceptions that occur inside testing context "foo bar" gives "foo bar"
  ;; when rethrown in the same testing context.
  ^{::expected-test-var-message "foo bar"}
  rethrown-nested-exception-test
  (let [the-e (atom nil)]
    (testing "foo"
      (try (testing "bar"
             (throw (reset! the-e (ex-info "" {::expected true}))))
           (catch Exception e
             (assert (identical? e @the-e))
             (throw e)))))

  ;; testing that exceptions that occur inside testing context "foo bar" gives "foo bar"
  ;; when rethrown in a different (empty) testing context.
  ^{::expected-test-var-message "foo bar"}
  rethrown-from-empty-context-test
  (let [the-e (atom nil)]
    (try
      (testing "foo"
        (testing "bar"
          (throw (reset! the-e (ex-info "" {::expected true})))))
      (catch Exception e
        (assert (identical? @the-e e))
        (throw e))))

  ;; crossing a `testing` context with exceptional control flow locks in the guess
  ;; for the final error message: "foo bar", not "adjacent". The rethrown context
  ;; is not reported.
  ^{::expected-test-var-message "foo bar"}
  rethrown-from-adjacent-context
  (let [the-e (atom nil)
        e (testing "foo"
            (try (testing "bar"
                   ;; throw through "bar" but catch before "foo"
                   (throw (reset! the-e (ex-info "" {::expected true}))))
                 (catch Exception e
                   (assert (identical? @the-e e))
                   e)))]
    (assert (identical? @the-e e))
    (testing "adjacent"
      (throw e)))

  ;; catching an exception before it crosses a `testing` scope "foo" allows rethrowing context
  ;; "adjacent" to be reported.
  ^{::expected-test-var-message "adjacent"}
  thrown-in-non-nested-context-rethrown-from-adjacent-context
  (let [the-e (atom nil)
        e (testing "foo"
            ;; don't cross `testing` scopes when throwing
            (try (throw (reset! the-e (ex-info "" {::expected true})))
                 (catch Exception e
                   (assert (identical? @the-e e))
                   e)))]
    (assert (identical? @the-e e))
    (testing "adjacent"
      ;; this is the first testing context we cross with exceptional control flow,
      ;; so "adjacent" is reported---not "foo"
      (throw e)))

  ;; binding conveyance can be used to track exceptional contexts
  ^{::expected-test-var-message "foo bar baz"}
  binding-conveyance-test
  (testing "foo"
    (testing "bar"
      @(future
         (testing "baz"
           (throw (ex-info "" {::expected true}))))))

  ^{::expected-test-var-message "foo bar3"}
  also-thrown-test
  (testing "foo"
    (try (testing "bar1"
           (throw (ex-info "asdf1" {::expected false})))
         (catch Exception _))
    (try (testing "bar2"
           (throw (ex-info "asdf2" {::expected false})))
         (catch Exception _))
    (testing "bar3"
      (throw (ex-info "asdf3" {::expected true})))))

;; Here, we create an alternate version of test/report, that
;; compares the event with the message, then calls the original
;; 'report' with modified arguments.

(declare ^:dynamic original-report)

(defn custom-report [data]
  (let [event (:type data)
        msg (:message data)
        expected (:expected data)
        actual (:actual data)
        passed (cond
                 (= event :fail) (= msg "Should fail")
                 (= event :pass) (= msg "Should pass")
                 (= event :error) (= msg "Should error")
                 :else true)]
    (if passed
      (original-report {:type :pass, :message msg,
                        :expected expected, :actual actual})
      (original-report {:type :fail, :message (str msg " but got " event)
                        :expected expected, :actual actual}))))

(def this-ns-name (ns-name *ns*))

;; test-ns-hook will be used by test/test-ns to run tests in this
;; namespace.
(defn test-ns-hook []
  (let [{test-var-test-vars true
         other-test-vars false
         :as all-groups} (group-by #(-> % symbol name (.startsWith test-var-tests-prefix))
                                   (sort-by symbol (vals (ns-interns this-ns-name))))]
    ;; extra paranoid checks of group-by usage
    (assert (= 2 (count all-groups)) (count all-groups))
    (assert (seq test-var-test-vars))
    (assert (seq other-test-vars))
    (binding [original-report report
              report custom-report]
      (test-vars other-test-vars))
    ;; testing clojure.test/test-var
    (doseq [v test-var-test-vars]
      ;; don't wrap in `testing` until _after_ test-var call
      (let [rs (atom [])
            actual (into []
                         (remove (comp #{:begin-test-var :end-test-var} :type))
                         (binding [report #(swap! rs conj %)]
                           (test-var v)))
            expected [{:type :error :message (-> v meta ::expected-test-var-message)}]]
        (testing (str `test-ns-hook "\n" (symbol v))
          ;; find ex-info
          (let [e (when (-> actual first :type #{:error})
                    (-> actual first :actual))]
            (is (::expected
                  (some
                    ex-data
                    (take-while some? (iterate #(some-> ^Exception % .getCause)
                                               e))))
                e))
          (is (= expected
                 (map #(select-keys % [:type :message]) actual))))))))
