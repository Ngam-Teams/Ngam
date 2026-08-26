import '../models/gig_model.dart';

class GigService {
  static Future<GigModel> fetchGigById(String id) async {
    return GigModel(id: id, title: 'Deleted Task', formattedBounty: 'RM0', status: 'completed');
  }
  static Future<List<GigModel>> fetchSharedGigs(String uid1, String uid2) async {
    return [];
  }
  static Future<int> getPostedCount(String uid) async {
    return 0;
  }
  static Future<int> getCompletedCount(String uid) async {
    return 0;
  }
  static Stream<int> streamCompletedCount(String uid) {
    return Stream.value(0);
  }
}
