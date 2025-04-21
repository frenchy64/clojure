;   Copyright (c) Rich Hickey. All rights reserved.
;   The use and distribution terms for this software are covered by the
;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
;   which can be found in the file epl-v10.html at the root of this distribution.
;   By using this software in any fashion, you are agreeing to be bound by
;   the terms of this license.
;   You must not remove this notice, or any other, from this software.

; Author: Frantisek Sodomka


(ns clojure.test-clojure.parallel
  (:use clojure.test))

;; !! Tests for the parallel library will be in a separate file clojure_parallel.clj !!

; future-call
; future
; pmap
; pcalls
; pvalues


;; pmap
;;
(deftest pmap-does-its-thing
  ;; regression fixed in r1218; was OutOfMemoryError
  (is (= '(1) (pmap inc [0]))))


(def ^:dynamic *test-value* 1)

(deftest future-fn-properly-retains-conveyed-bindings
  (let [a (atom [])]
    (binding [*test-value* 2]
      @(future (dotimes [_ 3]
                 ;; we need some binding to trigger binding pop
                 (binding [*print-dup* false]
                   (swap! a conj *test-value*))))
      (is (= [2 2 2] @a)))))

;; improve likelihood of catching a Thread holding onto its thread bindings
;; before it's cleared by another job. note this only expands the pool for futures
;; and send-off, not send-via.
(let [pool-size 500
      d (delay (let [p (promise)]
                 (mapv deref (mapv #(future (if (= (dec pool-size) %) (deliver p true) @p)) (range pool-size)))))]
  (defn expand-thread-pool! [] @d nil))

(deftest sent-agent-does-not-leak-memory
  (expand-thread-pool!)
  (let [strong-ref (volatile! (agent nil))
        weak-ref (java.lang.ref.WeakReference. @strong-ref)]
    (send-off @strong-ref vector)
    (doseq [i (range 10)
            :while (not (vector? @@strong-ref))]
      (Thread/sleep 1000))
    (vreset! strong-ref nil)
    (System/gc)
    (doseq [i (range 10)
            :while (some? (.get weak-ref))]
      (Thread/sleep 1000)
      (System/gc))
    (is (nil? (.get weak-ref)))))

(deftest seque-does-not-leak-memory
  (expand-thread-pool!)
  (let [ready (promise)
        strong-ref (volatile! (Object.))
        weak-ref (java.lang.ref.WeakReference. @strong-ref)
        the-seque (volatile! (seque 1 (cons nil
                                            (lazy-seq
                                              (let [s (repeat @strong-ref)]
                                                (deliver ready true)
                                                s)))))]
    @ready
    (vreset! strong-ref nil)
    (vreset! the-seque nil)
    (System/gc)
    (doseq [i (range 10)
            :while (some? (.get weak-ref))]
      (Thread/sleep 1000)
      (System/gc))
    (is (nil? (.get weak-ref)))))
