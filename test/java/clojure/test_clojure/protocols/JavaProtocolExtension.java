package clojure.test_clojure.protocols;

import clojure.java.api.Clojure;
import clojure.lang.*;

public class JavaProtocolExtension {
  public static interface JInterface1 {}
  public static interface JInterface2 {}
  public static interface JInterfaceExtends1 extends JInterface1 {}
  public static interface JInterfaceExtends2 extends JInterface2 {}
  public static interface JInterfaceExtendsUnimplemented1 extends JInterfaceExtends1 {}
  public static class JExtension1 implements JInterface1, JInterface2 {}
  public static class JExtension2 implements JInterface2, JInterface1 {}
  public static class JExtension3 implements JInterfaceExtends1, JInterface1 {}
  public static class JExtension4 implements JInterface1, JInterfaceExtends1 {}
  public static class JExtension5 implements JInterfaceExtends1, JInterfaceExtends2 {}
  public static class JExtension6 implements JInterfaceExtends2, JInterfaceExtends1 {}
  public static class JExtension7 implements JInterface2, JInterfaceExtends2 {}
  public static class JExtension8 implements JInterfaceExtends2, JInterface2 {}
  public static class JExtension9 implements JInterface1, JInterfaceExtends1, JInterface2, JInterfaceExtends2 {}
  public static class JExtension10 implements JInterface2, JInterfaceExtends2, JInterface1, JInterfaceExtends1 {}
  public static class JExtension11 implements JInterface2, JInterfaceExtends1, JInterface1, JInterfaceExtends2 {}
  public static class JExtension12 implements JInterfaceExtends1, JInterface1, JInterfaceExtends2, JInterface2 {}
  public static class JSubExtension1 extends JExtension1 {}
  public static class JSubExtension2 extends JExtension2 {}
  public static class JSubExtension3 extends JExtension1 implements JInterface2 {}
  public static class JSubExtension4 extends JExtension10 implements JInterface1 {}
}
