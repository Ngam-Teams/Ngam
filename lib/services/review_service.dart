import 'package:uuid/uuid.dart';
import '../models/review_model.dart';
import '../utils/constants.dart';
import 'supabase_service.dart';

// ============================================================
// Ngam App — Servis Review
// Handle hal ehwal hantar & ambil rating/review
// ============================================================

class ReviewService {
  static final _client = SupabaseService.client;
  static const _uuid = Uuid();

  /// Submit a review for a store or service booking
  static Future<ReviewModel> submitReview({
    String? gigId,
    String? businessId,
    String? shopId,
    String? serviceName,
    required String reviewerId,
    required int rating,
    required String comment,
  }) async {
    final targetBusinessId = businessId ?? shopId;
    final reviewData = {
      'id': _uuid.v4(),
      if (targetBusinessId != null) 'business_id': targetBusinessId,
      if (gigId != null) 'gig_id': gigId,
      if (serviceName != null) 'service_name': serviceName,
      'reviewer_id': reviewerId,
      'rating': rating,
      'comment': comment,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _client.from(DbTable.reviews).insert(reviewData);

    return ReviewModel.fromJson(reviewData);
  }

  /// Fetch all reviews for a specific business/store
  static Future<List<ReviewModel>> fetchBusinessReviews(String businessId) async {
    try {
      final response = await _client
          .from(DbTable.reviews)
          .select()
          .eq('business_id', businessId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ReviewModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch all reviews for gigs completed by a specific runner
  static Future<List<ReviewModel>> fetchRunnerReviews(String runnerId) async {
    // Dapatkan semua gig ID yang runner ni dah berjaya setelkan
    final gigsResponse = await _client
        .from(DbTable.gigs)
        .select('id')
        .eq('gig_worker_id', runnerId)
        .eq('status', 'COMPLETED');

    final gigIds = (gigsResponse as List).map((g) => g['id'] as String).toList();

    if (gigIds.isEmpty) return [];

    final response = await _client
        .from(DbTable.reviews)
        .select()
        .inFilter('gig_id', gigIds)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ReviewModel.fromJson(json))
        .toList();
  }

  /// Get the average rating for a runner
  static Future<double> getAverageRating(String runnerId) async {
    final reviews = await fetchRunnerReviews(runnerId);
    if (reviews.isEmpty) return 0.0;

    final total = reviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / reviews.length;
  }

  /// Check if a review already exists for a gig
  static Future<bool> hasReview(String gigId) async {
    final response = await _client
        .from(DbTable.reviews)
        .select('id')
        .eq('gig_id', gigId);

    return (response as List).isNotEmpty;
  }
}
