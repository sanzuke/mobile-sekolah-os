// Mirrors `/api/v1/teacher/vehicle-requests*` and `/vehicles/availability`
// (`VehicleRequestController` in admin-siakad).

const vehicleStatuses = <(String?, String)>[
  (null, 'Semua'),
  ('pending', 'Menunggu'),
  ('approved', 'Disetujui'),
  ('rejected', 'Ditolak'),
  ('cancelled', 'Dibatalkan'),
  ('completed', 'Selesai'),
];

/// A school vehicle and whether it is free in the range that was asked about.
class VehicleOption {
  const VehicleOption({
    required this.id,
    required this.name,
    required this.plateNumber,
    required this.capacity,
    required this.available,
    this.type,
  });

  final int id;
  final String name;
  final String plateNumber;
  final int capacity;
  final bool available;
  final String? type;

  factory VehicleOption.fromJson(Map<String, dynamic> j) => VehicleOption(
    id: j['id'] as int,
    name: j['name'] as String? ?? '',
    plateNumber: j['plate_number'] as String? ?? '',
    capacity: j['capacity'] as int? ?? 0,
    available: j['available'] as bool? ?? false,
    type: j['type'] as String?,
  );
}

class VehicleRequest {
  const VehicleRequest({
    required this.id,
    required this.purpose,
    required this.destination,
    required this.startAt,
    required this.endAt,
    required this.passengerCount,
    required this.status,
    required this.statusLabel,
    required this.canEdit,
    required this.canCancel,
    this.vehicleName,
    this.vehiclePlate,
    this.driverName,
    this.publicNote,
  });

  final int id;
  final String purpose;
  final String destination;

  /// `YYYY-MM-DD HH:mm` (WIB).
  final String startAt;
  final String endAt;
  final int passengerCount;

  /// `pending`, `approved`, `rejected`, `cancelled` or `completed`.
  final String status;
  final String statusLabel;
  final bool canEdit;
  final bool canCancel;

  /// Only once approved.
  final String? vehicleName;
  final String? vehiclePlate;
  final String? driverName;

  /// What the manager wrote for the requester; never the internal note.
  final String? publicNote;

  bool get isApproved => status == 'approved' || status == 'completed';

  factory VehicleRequest.fromJson(Map<String, dynamic> j) {
    final vehicle = j['vehicle'] as Map<String, dynamic>?;
    return VehicleRequest(
      id: j['id'] as int,
      purpose: j['purpose'] as String? ?? '',
      destination: j['destination'] as String? ?? '',
      startAt: j['start_at'] as String? ?? '',
      endAt: j['end_at'] as String? ?? '',
      passengerCount: j['passenger_count'] as int? ?? 0,
      status: j['status'] as String? ?? 'pending',
      statusLabel: j['status_label'] as String? ?? '',
      canEdit: j['can_edit'] as bool? ?? false,
      canCancel: j['can_cancel'] as bool? ?? false,
      vehicleName: vehicle?['name'] as String?,
      vehiclePlate: vehicle?['plate_number'] as String?,
      driverName: j['driver_name'] as String?,
      publicNote: j['public_note'] as String?,
    );
  }
}

class VehicleRequestPage {
  const VehicleRequestPage({required this.items, required this.lastPage});

  final List<VehicleRequest> items;
  final int lastPage;
}
