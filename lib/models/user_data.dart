import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserData {
  static final ValueNotifier<String> userName = ValueNotifier<String>('');
  static final ValueNotifier<String> userEmail = ValueNotifier<String>('');
  static final ValueNotifier<String> userPhone = ValueNotifier<String>('');
  static final ValueNotifier<String> userProfilePic = ValueNotifier<String>('');
  static final ValueNotifier<String> userLocation = ValueNotifier<String>('');
  static final ValueNotifier<String> userDob = ValueNotifier<String>('');

  static final ValueNotifier<bool> appLockEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<int> appLockTimeout = ValueNotifier<int>(0);
  static final ValueNotifier<bool> hideContentEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> locationEnabled = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> twoFactorEnabled = ValueNotifier<bool>(false);

  static final ValueNotifier<List<Map<String, dynamic>>> savedPaymentMethods =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static Future<void> updateProfile({String? name, String? email, String? phone, String? profilePic, String? dob, String? address}) async {
    if (name != null) userName.value = name;
    if (email != null) userEmail.value = email;
    if (phone != null) userPhone.value = phone;
    if (profilePic != null) userProfilePic.value = profilePic;
    if (dob != null) userDob.value = dob;
    if (address != null) userLocation.value = address;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('profiles').upsert({'id': user.id, 'name': userName.value, 'phone_number': userPhone.value});
      } catch (e) { debugPrint('Error updating profile: $e'); }
    }
  }

  static void addPaymentMethod(Map<String, dynamic> method) {
    final List<Map<String, dynamic>> currentList = List.from(savedPaymentMethods.value);
    currentList.add(method);
    savedPaymentMethods.value = currentList;
  }

  static void setPrimaryPaymentMethod(String id) {
    final List<Map<String, dynamic>> currentList = List.from(savedPaymentMethods.value);
    for (var i = 0; i < currentList.length; i++) { currentList[i]["isPrimary"] = (currentList[i]["id"] == id); }
    savedPaymentMethods.value = currentList;
  }

  static void removePaymentMethod(String id) {
    final List<Map<String, dynamic>> currentList = List.from(savedPaymentMethods.value);
    currentList.removeWhere((method) => method["id"] == id);
    savedPaymentMethods.value = currentList;
  }

  static void clearAll() {
    userName.value = ''; userEmail.value = ''; userPhone.value = '';
    userProfilePic.value = ''; userLocation.value = ''; userDob.value = '';
    savedPaymentMethods.value = [];
  }
}