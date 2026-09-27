import 'dart:async';

import 'package:baraka_bozor/core/network/api_failure.dart';
import 'package:baraka_bozor/features/addresses/domain/addresses.dart';
import 'package:baraka_bozor/features/profile/domain/profile.dart';

/// The Customer's profile in memory.
class FakeProfileRepository implements ProfileRepository {
  CustomerProfile current = const CustomerProfile(
    id: 'c',
    phone: '+998901234567',
    fullName: null,
  );
  final List<String> renames = <String>[];
  ApiFailure? renameFailure;

  /// The next load answers this instead.
  ApiFailure? loadFailure;

  /// While set, a load or a rename answers only once it completes.
  Completer<void>? hold;

  @override
  Future<CustomerProfile> profile() async {
    await hold?.future;
    final ApiFailure? failure = loadFailure;
    if (failure != null) {
      loadFailure = null;
      throw failure;
    }
    return current;
  }

  @override
  Future<CustomerProfile> rename(
    CustomerProfile profile,
    String fullName,
  ) async {
    renames.add(fullName);
    await hold?.future;
    final ApiFailure? failure = renameFailure;
    if (failure != null) {
      renameFailure = null;
      throw failure;
    }
    current = CustomerProfile(
      id: current.id,
      phone: current.phone,
      fullName: fullName,
    );
    return current;
  }
}

Address address({
  String id = 'a-1',
  String? label = 'Uy',
  GeoPoint point = const GeoPoint(
    latitude: '41.311081',
    longitude: '69.240562',
  ),
  String street = 'Amir Temur',
  String house = '12',
}) => Address(
  id: id,
  label: label,
  point: point,
  street: street,
  house: house,
  apartment: null,
  landmark: null,
  deliveryNote: null,
);

/// The Customer's addresses in memory. A save answers with [saveFailure],
/// and a removal with [removeFailure], once when it is set; while [hold] is
/// set, both wait for it.
class FakeAddressesRepository implements AddressesRepository {
  FakeAddressesRepository({List<Address>? rows})
    : rows = rows ?? <Address>[address()];

  List<Address> rows;
  final List<(String?, AddressDraft)> saved = <(String?, AddressDraft)>[];
  final List<String> removed = <String>[];
  ApiFailure? saveFailure;
  ApiFailure? removeFailure;
  Completer<void>? hold;

  /// The next load answers this instead; while [loadHold] is set, a load
  /// answers only once it completes.
  ApiFailure? loadFailure;
  Completer<void>? loadHold;
  int _next = 1;

  @override
  Future<List<Address>> addresses() async {
    await loadHold?.future;
    final ApiFailure? failure = loadFailure;
    if (failure != null) {
      loadFailure = null;
      throw failure;
    }
    return rows;
  }

  @override
  Future<Address> create(AddressDraft draft) => _save(null, draft);

  @override
  Future<Address> update(Address address, AddressDraft draft) =>
      _save(address.id, draft);

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    await hold?.future;
    final ApiFailure? failure = removeFailure;
    if (failure != null) {
      removeFailure = null;
      throw failure;
    }
    rows = rows.where((Address a) => a.id != id).toList();
  }

  Future<Address> _save(String? id, AddressDraft draft) async {
    saved.add((id, draft));
    await hold?.future;
    final ApiFailure? failure = saveFailure;
    if (failure != null) {
      saveFailure = null;
      throw failure;
    }
    final Address stored = Address(
      id: id ?? 'a-new-${_next++}',
      label: draft.label,
      point: draft.point,
      street: draft.street,
      house: draft.house,
      apartment: draft.apartment,
      landmark: draft.landmark,
      deliveryNote: draft.deliveryNote,
    );
    rows = <Address>[
      for (final Address a in rows)
        if (a.id != stored.id) a,
      stored,
    ];
    return stored;
  }
}
