class GigModel {
  final String id;
  final String title;
  final String formattedBounty;
  final String status;
  final String? gigWorkerId;

  GigModel({
    required this.id,
    required this.title,
    required this.formattedBounty,
    required this.status,
    this.gigWorkerId,
  });
}
