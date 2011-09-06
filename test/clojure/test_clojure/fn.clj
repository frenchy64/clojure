;   Copyright (c) Rich Hickey. All rights reserved.
;   The use and distribution terms for this software are covered by the
;   Eclipse Public License 1.0 (http://opensource.org/licenses/eclipse-1.0.php)
;   which can be found in the file epl-v10.html at the root of this distribution.
;   By using this software in any fashion, you are agreeing to be bound by
;   the terms of this license.
;   You must not remove this notice, or any other, from this software.

; Author: Ambrose Bonnaire-Sergeant

(ns clojure.test-clojure.fn
  (:import clojure.lang.Compiler)
  (:use clojure.test clojure.test-helper))

(deftest fn-error-checking
  (is (thrown-with-msg? 
        clojure.lang.Compiler$CompilerException 
        #"java.lang.IllegalArgumentException: Parameter list for fn must be a vector. Found: class java.lang.Character"
        (eval `(fn "a" a))))
  (is (thrown-with-msg? 
        clojure.lang.Compiler$CompilerException 
        #"java.lang.IllegalArgumentException: Parameter list for fn must be a vector. Found: class java.lang.Character"
        (eval `(fn "a" []))))
  (is (thrown-with-msg? 
        clojure.lang.Compiler$CompilerException 
        #"java.lang.IllegalArgumentException: Parameter list for fn must be a vector. Found: class java.lang.Long"
        (eval `(fn (1)))))
  (is (thrown-with-msg? 
        clojure.lang.Compiler$CompilerException 
        #"java.lang.IllegalArgumentException: Parameter list for fn must be a vector. Found: class java.lang.String"
        (eval `(fn
                 ([a] 1)
                 ("a" 2)))))
  (is (thrown-with-msg? 
        clojure.lang.Compiler$CompilerException 
        #"java.lang.IllegalArgumentException: Parameter list for fn must be a vector. Found: class java.lang.Character"
        (eval `(fn a "a")))))

(
