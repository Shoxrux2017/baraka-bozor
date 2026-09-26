/// The business settings as `docs/09-api-contracts.md` section 44 returns
/// them, every value set.
Map<String, dynamic> businessJson() => <String, dynamic>{
  'markup_percent': '15.00',
  'service_fee_mode': 'fixed',
  'service_fee_fixed_uzs': 5000,
  'service_fee_percent': null,
  'delivery_fee_uzs': 15000,
  'minimum_order_uzs': 100000,
  'price_tolerance_percent': '10.00',
  'opens_at': '09:00',
  'closes_at': '21:00',
  'service_centre_latitude': '41.311081',
  'service_centre_longitude': '69.240562',
  'service_radius_km': '5.00',
  'delivery_delay_threshold_minutes': 30,
  'updated_at': '2026-09-26T05:00:00Z',
};

Map<String, dynamic> providerJson(String provider, {bool enabled = false}) =>
    <String, dynamic>{
      'provider': provider,
      'is_enabled': enabled,
      'updated_at': '2026-09-26T05:00:00Z',
    };
