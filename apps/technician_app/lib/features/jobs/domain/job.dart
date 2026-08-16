enum TechJobStatus {
  accepted,
  onTheWay,
  arrived,
  otpVerified,
  serviceStarted,
  forwardRequest,
  forwardApproved,
  resumed,
  completed
}

class TechJob {
  final String id;
  final String title;
  final double price;
  final String customerName;
  final String customerAddress;
  final TechJobStatus status;
  final String? otp;
  final List<AddOnWork> addOns;
  final ForwardDetails? forwardDetails;
  final double? customerLatitude;
  final double? customerLongitude;
  final double? techLatitude;
  final double? techLongitude;
  final int? currentPathIndex;

  TechJob({
    required this.id,
    required this.title,
    required this.price,
    required this.customerName,
    required this.customerAddress,
    required this.status,
    this.otp,
    this.addOns = const [],
    this.forwardDetails,
    this.customerLatitude,
    this.customerLongitude,
    this.techLatitude,
    this.techLongitude,
    this.currentPathIndex,
  });

  TechJob copyWith({
    String? id,
    String? title,
    double? price,
    String? customerName,
    String? customerAddress,
    TechJobStatus? status,
    String? otp,
    List<AddOnWork>? addOns,
    ForwardDetails? forwardDetails,
    double? customerLatitude,
    double? customerLongitude,
    double? techLatitude,
    double? techLongitude,
    int? currentPathIndex,
  }) {
    return TechJob(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      status: status ?? this.status,
      otp: otp ?? this.otp,
      addOns: addOns ?? this.addOns,
      forwardDetails: forwardDetails ?? this.forwardDetails,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      techLatitude: techLatitude ?? this.techLatitude,
      techLongitude: techLongitude ?? this.techLongitude,
      currentPathIndex: currentPathIndex ?? this.currentPathIndex,
    );
  }
}

class AddOnWork {
  final String id;
  final String name;
  final double price;
  final String reason;
  final bool isApproved;

  AddOnWork({
    required this.id,
    required this.name,
    required this.price,
    required this.reason,
    this.isApproved = false,
  });

  AddOnWork copyWith({
    String? id,
    String? name,
    double? price,
    String? reason,
    bool? isApproved,
  }) {
    return AddOnWork(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      reason: reason ?? this.reason,
      isApproved: isApproved ?? this.isApproved,
    );
  }
}

class ForwardDetails {
  final String reason;
  final String requestedDate;
  final String explanation;

  ForwardDetails({
    required this.reason,
    required this.requestedDate,
    required this.explanation,
  });
}
