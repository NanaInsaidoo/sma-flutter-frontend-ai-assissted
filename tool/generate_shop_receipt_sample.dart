import 'dart:io';

import 'package:school_management_app/src/shop/presentation/shop_receipt_pdf.dart';

Future<void> main() async {
  final bytes = await buildShopReceiptPdf(
    schoolName: 'Sunrise Academy',
    receipt: {
      'reference': 'SHOP-20260904-000101',
      'status': 'PENDING_COLLECTION',
      'pickupToken': '482913',
      'issuedAt': '2026-09-04T14:41:00',
      'cashierName': 'Ama Cashier',
      'custodianName': 'Kofi Storekeeper',
      'sale': {
        'buyerName': 'Ama Customer',
        'paymentMethod': 'CASH',
        'totalAmount': 69,
        'lines': [
          {
            'itemName': 'Exercise Book - 80 pages',
            'quantity': 3,
            'unitPrice': 8,
            'lineTotal': 24,
          },
          {
            'itemName': 'School Polo Shirt - Size 10',
            'quantity': 1,
            'unitPrice': 45,
            'lineTotal': 45,
          },
        ],
      },
    },
  );
  final output = File('output/pdf/shop-receipt-sample.pdf');
  await output.parent.create(recursive: true);
  await output.writeAsBytes(bytes, flush: true);
}
