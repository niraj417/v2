class DuplicateFilter {
  final Set<String> _seenIds = {};

  /// Returns true if this [id] has not been seen before in the current session.
  bool isNew(String id) {
    if (id.isEmpty) return true;
    if (_seenIds.contains(id)) return false;
    _seenIds.add(id);
    return true;
  }

  /// Clears the filter for a new search session.
  void clear() => _seenIds.clear();
}
