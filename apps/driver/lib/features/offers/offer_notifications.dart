Set<String> findNewOfferIds(List<dynamic> previous, List<dynamic> next) {
  final previousIds = previous
      .map((item) => _offerId(item))
      .whereType<String>()
      .toSet();
  final nextIds = next
      .map((item) => _offerId(item))
      .whereType<String>()
      .toSet();

  return nextIds.difference(previousIds);
}

String? _offerId(dynamic item) {
  if (item is Map) {
    final raw = item['ride_order_id'] ?? item['id'];
    if (raw == null) return null;
    return raw.toString();
  }
  return null;
}
