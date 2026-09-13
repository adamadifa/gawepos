import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/features/master/data/master_repository.dart';
import 'package:posmobile/features/master/data/product_excel_service.dart';

void main() {
  late AppDatabase database;
  late MasterRepository masterRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    masterRepository = MasterRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('Pengujian Import Excel Multi-Sheet (Kategori, Merek, Produk)', () {
    test('Berhasil membaca Excel multi-sheet dan menyimpan ke database dengan relasi yang tepat', () async {
      final excel = Excel.createExcel();

      // 1. Sheet Kategori
      final catSheet = excel['Kategori'];
      catSheet.appendRow([TextCellValue('Nama Kategori*'), TextCellValue('Deskripsi')]);
      catSheet.appendRow([TextCellValue('Minuman'), TextCellValue('Aneka Minuman')]);
      catSheet.appendRow([TextCellValue('Makanan Ringan'), TextCellValue('Snack dan keripik')]);

      // 2. Sheet Merek
      final brandSheet = excel['Merek'];
      brandSheet.appendRow([TextCellValue('Nama Merek*')]);
      brandSheet.appendRow([TextCellValue('Nestle')]);
      brandSheet.appendRow([TextCellValue('Garuda Food')]);

      // 3. Sheet Produk
      final prodSheet = excel['Produk'];
      prodSheet.appendRow([
        TextCellValue('Nama Produk*'),
        TextCellValue('Barcode'),
        TextCellValue('SKU'),
        TextCellValue('Kategori'),
        TextCellValue('Merek'),
        TextCellValue('Satuan Dasar*'),
        TextCellValue('Harga Beli / Modal'),
        TextCellValue('Harga Jual*'),
        TextCellValue('Stok Awal'),
        TextCellValue('Min Stok Alert'),
        TextCellValue('Tipe Usaha (retail/fnb/general)'),
      ]);

      prodSheet.appendRow([
        TextCellValue('Milo Kaleng 240ml'),
        TextCellValue('8992345678901'),
        TextCellValue('MIL-001'),
        TextCellValue('Minuman'),
        TextCellValue('Nestle'),
        TextCellValue('Kaleng'),
        DoubleCellValue(8000),
        DoubleCellValue(10000),
        DoubleCellValue(50),
        IntCellValue(10),
        TextCellValue('retail'),
      ]);

      prodSheet.appendRow([
        TextCellValue('Kacang Garuda 100g'),
        TextCellValue('8991234567890'),
        TextCellValue('KCG-001'),
        TextCellValue('Makanan Ringan'),
        TextCellValue('Garuda Food'),
        TextCellValue('Bungkus'),
        DoubleCellValue(6500),
        DoubleCellValue(8500),
        DoubleCellValue(20),
        IntCellValue(5),
        TextCellValue('retail'),
      ]);

      // Produk dengan kategori & merek baru otomatis (tidak ada di sheet 1 & 2)
      prodSheet.appendRow([
        TextCellValue('Roti Bakar Coklat'),
        TextCellValue(''),
        TextCellValue('ROT-001'),
        TextCellValue('Menu Dapur'), // Kategori Baru Otomatis
        TextCellValue('Homemade'),   // Merek Baru Otomatis
        TextCellValue('Porsi'),
        DoubleCellValue(5000),
        DoubleCellValue(15000),
        DoubleCellValue(0),
        IntCellValue(0),
        TextCellValue('fnb'),
      ]);

      final bytes = Uint8List.fromList(excel.save()!);

      // 1. Parsing file excel
      final parseResult = ProductExcelService.parseExcelBytes(bytes);
      expect(parseResult.hasErrors, isFalse);
      expect(parseResult.categories.length, equals(2));
      expect(parseResult.brands.length, equals(2));
      expect(parseResult.products.length, equals(3));

      // 2. Simpan ke database
      final insertedCount = await masterRepository.importProductsFromExcelBatch(parseResult);
      expect(insertedCount, equals(3));

      // 3. Verifikasi Data Tersimpan
      final categories = await database.select(database.categories).get();
      // Harusnya ada 3 kategori: 'Minuman', 'Makanan Ringan', 'Menu Dapur'
      expect(categories.length, equals(3));
      expect(categories.any((c) => c.name == 'Menu Dapur'), isTrue);

      final brands = await database.select(database.brands).get();
      // Harusnya ada 3 merek: 'Nestle', 'Garuda Food', 'Homemade'
      expect(brands.length, equals(3));
      expect(brands.any((b) => b.name == 'Homemade'), isTrue);

      final products = await masterRepository.getProductsWithDetails();
      expect(products.length, equals(3));

      // Cek produk Milo dengan getProductComplete
      final milo = products.firstWhere((p) => (p['product'] as Product).name == 'Milo Kaleng 240ml');
      final miloProd = milo['product'] as Product;
      final miloComplete = await masterRepository.getProductComplete(miloProd.id);
      final miloUnits = miloComplete?['units'] as List<ProductUnit>;
      final miloCat = miloComplete?['category'] as Category?;
      final miloBrand = miloComplete?['brand'] as Brand?;

      expect(miloCat?.name, equals('Minuman'));
      expect(miloBrand?.name, equals('Nestle'));
      expect(miloUnits.first.name, equals('Kaleng'));
      expect(miloUnits.first.costPrice, equals(8000));

      final miloInv = await (database.select(database.inventory)..where((tbl) => tbl.productId.equals(miloProd.id))).getSingle();
      expect(miloInv.quantity, equals(50));
    });
  });
}
