// ============================================================
// Ngam App — Model Review
// ============================================================

class ReviewModel {
  final String id;
  final String? gigId;
  final String? businessId;
  final String? serviceName;
  final String reviewerId;
  final int rating;
  final String comment;
  final DateTime createdAt;

  // Field yang di-join
  final String? reviewerName;

  ReviewModel({
    required this.id,
    this.gigId,
    this.businessId,
    this.serviceName,
    required this.reviewerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.reviewerName,
  });

  /// Create from Supabase JSON row
  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      gigId: json['gig_id'] as String?,
      businessId: json['business_id'] as String?,
      serviceName: json['service_name'] as String?,
      reviewerId: json['reviewer_id'] as String? ?? '',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      reviewerName: json['reviewer_name'] as String?,
    );
  }

  /// Convert to JSON for Supabase insert
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (gigId != null) 'gig_id': gigId,
      if (businessId != null) 'business_id': businessId,
      if (serviceName != null) 'service_name': serviceName,
      'reviewer_id': reviewerId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
