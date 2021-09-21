package compilation;

public interface InterfaceWithDefaultMethods {
  Object bar(Object o);
  default Object bar(Object o, Object p) {
    return bar(o);
  }
  default Object baz(Object o) {
    return o;
  }
}
