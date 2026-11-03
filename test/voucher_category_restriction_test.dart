import 'package:flutter_test/flutter_test.dart';
import 'package:ngam/services/voucher_service.dart';

void main() {
  group('Voucher Category Compatibility Tests', () {
    test('KOPINGAM is strictly forbidden for Barber', () {
      final kopingam = VoucherService.curatedPromos.firstWhere((p) => p['code'] == 'KOPINGAM');
      
      final barberRes = VoucherService.checkVoucherEligibility(
        kopingam,
        subtotal: 30.0,
        category: 'barber',
      );

      expect(barberRes['isEligible'], isFalse);
      expect(barberRes['discountAmount'], 0.0);
      expect(barberRes['reason'], contains('Hanya sah untuk Kafe & F&B'));
    });

    test('KOPINGAM is accepted for Cafe / F&B', () {
      final kopingam = VoucherService.curatedPromos.firstWhere((p) => p['code'] == 'KOPINGAM');
      
      final cafeRes = VoucherService.checkVoucherEligibility(
        kopingam,
        subtotal: 15.0,
        category: 'cafe',
      );

      expect(cafeRes['isEligible'], isTrue);
      expect(cafeRes['discountAmount'], 3.0);
    });

    test('STYLE10 is strictly forbidden for Cafe / Restaurant', () {
      final style10 = VoucherService.curatedPromos.firstWhere((p) => p['code'] == 'STYLE10');
      
      final cafeRes = VoucherService.checkVoucherEligibility(
        style10,
        subtotal: 50.0,
        category: 'food',
      );

      expect(cafeRes['isEligible'], isFalse);
      expect(cafeRes['discountAmount'], 0.0);
      expect(cafeRes['reason'], contains('Barber & Dandanan'));
    });

    test('STYLE10 is accepted for Barber / Salon', () {
      final style10 = VoucherService.curatedPromos.firstWhere((p) => p['code'] == 'STYLE10');
      
      final barberRes = VoucherService.checkVoucherEligibility(
        style10,
        subtotal: 30.0,
        category: 'barber',
      );

      expect(barberRes['isEligible'], isTrue);
      expect(barberRes['discountAmount'], 3.0); // 10% of 30.0
    });

    test('NGAMBARU is accepted for all categories', () {
      final ngambaru = VoucherService.curatedPromos.firstWhere((p) => p['code'] == 'NGAMBARU');
      
      final barberRes = VoucherService.checkVoucherEligibility(
        ngambaru,
        subtotal: 25.0,
        category: 'barber',
      );
      expect(barberRes['isEligible'], isTrue);

      final cafeRes = VoucherService.checkVoucherEligibility(
        ngambaru,
        subtotal: 25.0,
        category: 'cafe',
      );
      expect(cafeRes['isEligible'], isTrue);

      final carwashRes = VoucherService.checkVoucherEligibility(
        ngambaru,
        subtotal: 25.0,
        category: 'carwash',
      );
      expect(carwashRes['isEligible'], isTrue);
    });
  });
}
