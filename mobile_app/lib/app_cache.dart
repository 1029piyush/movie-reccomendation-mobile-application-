class AppCache {
  static final Map<String, dynamic> _cache = {};

  static dynamic get(String key) => _cache[key];

  static void set(String key, dynamic value) {
    _cache[key] = value;
  }

  static bool has(String key) => _cache.containsKey(key);

  static void clear() => _cache.clear();
}
