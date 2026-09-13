import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/app_database.dart';
import 'dummy_products_data.dart';
import 'dummy_coffee_raw_materials.dart';

class ParsedCategoryRow {
  final String name;
  final String? description;

  ParsedCategoryRow({required this.name, this.description});
}

class ParsedBrandRow {
  final String name;

  ParsedBrandRow({required this.name});
}

class ParsedProductRow {
  final String name;
  final String? barcode;
  final String? sku;
  final String? categoryName;
  final String? brandName;
  final String unitName;
  final double costPrice;
  final double sellPrice;
  final double initialStock;
  final int minStockAlert;
  final String businessSegment; // 'retail' / 'fnb' / 'general'

  ParsedProductRow({
    required this.name,
    this.barcode,
    this.sku,
    this.categoryName,
    this.brandName,
    required this.unitName,
    required this.costPrice,
    required this.sellPrice,
    required this.initialStock,
    required this.minStockAlert,
    required this.businessSegment,
  });
}

class ExcelParseResult {
  final List<ParsedCategoryRow> categories;
  final List<ParsedBrandRow> brands;
  final List<ParsedProductRow> products;
  final List<String> warnings;
  final List<String> errors;

  ExcelParseResult({
    required this.categories,
    required this.brands,
    required this.products,
    required this.warnings,
    required this.errors,
  });

  bool get hasProducts => products.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

class ProductExcelService {
  /// Generate template Excel Multi-Sheet (Kategori, Merek, Produk) dan share/unduh
  static Future<void> exportTemplateAndShare({
    List<Category> existingCategories = const [],
    List<Brand> existingBrands = const [],
  }) async {
    final excel = Excel.createExcel();

    // Kumpulkan semua kategori unik dari existing + dummy data
    final categorySet = <String, String>{}; // name -> description
    for (final c in existingCategories) {
      categorySet[c.name] = c.description ?? '';
    }
    for (final p in DummyDataGenerator.raw100Products) {
      categorySet.putIfAbsent(p.category, () => 'Kategori ${p.category}');
    }
    for (final p in CoffeeShopDummyData.menuProducts) {
      categorySet.putIfAbsent(p.category, () => 'Menu ${p.category} F&B');
    }

    // 1. Sheet Kategori
    final catSheet = excel['Kategori'];
    excel.setDefaultSheet('Kategori');

    // Header Kategori
    catSheet.appendRow([
      TextCellValue('Nama Kategori*'),
      TextCellValue('Deskripsi'),
    ]);
    _applyHeaderStyle(catSheet, 0, 2);

    for (final entry in categorySet.entries) {
      catSheet.appendRow([
        TextCellValue(entry.key),
        TextCellValue(entry.value),
      ]);
    }

    // Kumpulkan semua brand unik dari existing + dummy data
    final brandSet = <String>{};
    for (final b in existingBrands) {
      brandSet.add(b.name);
    }
    for (final p in DummyDataGenerator.raw100Products) {
      if (p.brand.isNotEmpty) brandSet.add(p.brand);
    }
    for (final p in CoffeeShopDummyData.menuProducts) {
      if (p.brand.isNotEmpty) brandSet.add(p.brand);
    }

    // 2. Sheet Merek
    final brandSheet = excel['Merek'];
    brandSheet.appendRow([
      TextCellValue('Nama Merek*'),
    ]);
    _applyHeaderStyle(brandSheet, 0, 1);

    for (final b in brandSet) {
      brandSheet.appendRow([
        TextCellValue(b),
      ]);
    }

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
    _applyHeaderStyle(prodSheet, 0, 11);

    // Masukkan 100 Produk Dummy Retail
    for (final p in DummyDataGenerator.raw100Products) {
      prodSheet.appendRow([
        TextCellValue(p.name),
        TextCellValue(p.barcode),
        TextCellValue(p.sku),
        TextCellValue(p.category),
        TextCellValue(p.brand),
        TextCellValue(p.unitBase),
        DoubleCellValue(p.buyPrice),
        DoubleCellValue(p.sellPrice),
        DoubleCellValue(50), // Stok awal default 50
        IntCellValue(p.minStock),
        TextCellValue('retail'),
      ]);
    }

    // Masukkan Menu F&B Coffee
    for (final p in CoffeeShopDummyData.menuProducts) {
      prodSheet.appendRow([
        TextCellValue(p.name),
        TextCellValue(p.barcode),
        TextCellValue(p.sku),
        TextCellValue(p.category),
        TextCellValue(p.brand),
        TextCellValue(p.unitName),
        DoubleCellValue(p.sellPrice * 0.4), // Perkiraan HPP modal
        DoubleCellValue(p.sellPrice),
        DoubleCellValue(0), // F&B berbasis racikan resep
        IntCellValue(5),
        TextCellValue('fnb'),
      ]);
    }

    // Hapus sheet default "Sheet1" jika terbuat otomatis
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Jadikan sheet Produk sebagai default saat dibuka pertama kali
    excel.setDefaultSheet('Produk');

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/Template_Import_Produk_GawePOS.xlsx';
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Template Import Data Produk Excel - GawePOS',
      subject: 'Template Import Produk Excel',
    );
  }

  static void _applyHeaderStyle(Sheet sheet, int rowIndex, int colCount) {
    for (var col = 0; col < colCount; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.blueGrey100,
        fontFamily: getFontFamily(FontFamily.Arial),
      );
    }
  }

  /// Membaca dan memvalidasi file Excel
  static ExcelParseResult parseExcelBytes(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);

    final List<ParsedCategoryRow> parsedCategories = [];
    final List<ParsedBrandRow> parsedBrands = [];
    final List<ParsedProductRow> parsedProducts = [];
    final List<String> warnings = [];
    final List<String> errors = [];

    // Cari Sheet Kategori
    final catSheet = _findSheet(excel, ['kategori', 'category', 'categories']);
    if (catSheet != null && catSheet.maxRows > 1) {
      for (var r = 1; r < catSheet.maxRows; r++) {
        final row = catSheet.row(r);
        if (row.isEmpty) continue;
        final name = _getCellValueString(row, 0)?.trim();
        if (name != null && name.isNotEmpty) {
          final desc = _getCellValueString(row, 1)?.trim();
          parsedCategories.add(ParsedCategoryRow(name: name, description: desc));
        }
      }
    }

    // Cari Sheet Merek
    final brandSheet = _findSheet(excel, ['merek', 'brand', 'brands', 'merk']);
    if (brandSheet != null && brandSheet.maxRows > 1) {
      for (var r = 1; r < brandSheet.maxRows; r++) {
        final row = brandSheet.row(r);
        if (row.isEmpty) continue;
        final name = _getCellValueString(row, 0)?.trim();
        if (name != null && name.isNotEmpty) {
          parsedBrands.add(ParsedBrandRow(name: name));
        }
      }
    }

    // Cari Sheet Produk
    final prodSheet = _findSheet(excel, ['produk', 'product', 'products', 'barang', 'item']) ??
        (excel.sheets.isNotEmpty ? excel.sheets.values.first : null);

    if (prodSheet == null || prodSheet.maxRows <= 1) {
      errors.add('Sheet "Produk" tidak ditemukan atau tidak memiliki baris data.');
      return ExcelParseResult(
        categories: parsedCategories,
        brands: parsedBrands,
        products: parsedProducts,
        warnings: warnings,
        errors: errors,
      );
    }

    // Header index mapping berdasarkan nama header
    final headerMap = <String, int>{};
    final headerRow = prodSheet.row(0);
    for (var i = 0; i < headerRow.length; i++) {
      final val = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
      if (val.contains('nama') || val.contains('name') || val.contains('produk')) {
        headerMap.putIfAbsent('name', () => i);
      } else if (val.contains('barcode')) {
        headerMap.putIfAbsent('barcode', () => i);
      } else if (val.contains('sku') || val.contains('kode')) {
        headerMap.putIfAbsent('sku', () => i);
      } else if (val.contains('kategori') || val.contains('category')) {
        headerMap.putIfAbsent('category', () => i);
      } else if (val.contains('merek') || val.contains('brand') || val.contains('merk')) {
        headerMap.putIfAbsent('brand', () => i);
      } else if (val.contains('satuan') || val.contains('unit')) {
        headerMap.putIfAbsent('unit', () => i);
      } else if (val.contains('modal') || val.contains('beli') || val.contains('cost') || val.contains('hpp')) {
        headerMap.putIfAbsent('cost', () => i);
      } else if (val.contains('jual') || val.contains('harga') || val.contains('price')) {
        headerMap.putIfAbsent('price', () => i);
      } else if (val.contains('stok awal') || val.contains('stock') || val.contains('stok')) {
        headerMap.putIfAbsent('stock', () => i);
      } else if (val.contains('min') || val.contains('alert')) {
        headerMap.putIfAbsent('min_stock', () => i);
      } else if (val.contains('usaha') || val.contains('tipe') || val.contains('segment')) {
        headerMap.putIfAbsent('segment', () => i);
      }
    }

    // Fallback index jika header tidak terdeteksi via nama
    final nameIdx = headerMap['name'] ?? 0;
    final barcodeIdx = headerMap['barcode'] ?? 1;
    final skuIdx = headerMap['sku'] ?? 2;
    final catIdx = headerMap['category'] ?? 3;
    final brandIdx = headerMap['brand'] ?? 4;
    final unitIdx = headerMap['unit'] ?? 5;
    final costIdx = headerMap['cost'] ?? 6;
    final priceIdx = headerMap['price'] ?? 7;
    final stockIdx = headerMap['stock'] ?? 8;
    final minStockIdx = headerMap['min_stock'] ?? 9;
    final segmentIdx = headerMap['segment'] ?? 10;

    for (var r = 1; r < prodSheet.maxRows; r++) {
      final row = prodSheet.row(r);
      if (row.isEmpty) continue;

      final name = _getCellValueString(row, nameIdx)?.trim();
      // Lewati jika seluruh baris kosong atau nama produk kosong
      if (name == null || name.isEmpty) {
        continue;
      }

      final barcode = _getCellValueString(row, barcodeIdx)?.trim();
      final sku = _getCellValueString(row, skuIdx)?.trim();
      final catName = _getCellValueString(row, catIdx)?.trim();
      final brandName = _getCellValueString(row, brandIdx)?.trim();
      var unitName = _getCellValueString(row, unitIdx)?.trim() ?? '';
      if (unitName.isEmpty) unitName = 'Pcs';

      final cost = _getCellValueDouble(row, costIdx) ?? 0.0;
      final price = _getCellValueDouble(row, priceIdx);

      if (price == null || price < 0) {
        warnings.add('Baris ${r + 1} ($name): Harga jual tidak valid / kosong, disetel ke 0.');
      }

      final stock = _getCellValueDouble(row, stockIdx) ?? 0.0;
      final minStock = _getCellValueInt(row, minStockIdx) ?? 0;
      var segment = _getCellValueString(row, segmentIdx)?.toLowerCase().trim() ?? 'retail';
      if (!['retail', 'fnb', 'general'].contains(segment)) {
        segment = 'retail';
      }

      parsedProducts.add(
        ParsedProductRow(
          name: name,
          barcode: (barcode != null && barcode.isNotEmpty) ? barcode : null,
          sku: (sku != null && sku.isNotEmpty) ? sku : null,
          categoryName: (catName != null && catName.isNotEmpty) ? catName : null,
          brandName: (brandName != null && brandName.isNotEmpty) ? brandName : null,
          unitName: unitName,
          costPrice: cost,
          sellPrice: price ?? 0.0,
          initialStock: stock,
          minStockAlert: minStock,
          businessSegment: segment,
        ),
      );
    }

    if (parsedProducts.isEmpty) {
      errors.add('Tidak ada data produk yang valid ditemukan dalam sheet.');
    }

    return ExcelParseResult(
      categories: parsedCategories,
      brands: parsedBrands,
      products: parsedProducts,
      warnings: warnings,
      errors: errors,
    );
  }

  static Sheet? _findSheet(Excel excel, List<String> aliases) {
    for (final key in excel.sheets.keys) {
      final lower = key.toLowerCase().trim();
      if (aliases.any((alias) => lower.contains(alias))) {
        return excel.sheets[key];
      }
    }
    return null;
  }

  static String? _getCellValueString(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    if (cell == null || cell.value == null) return null;
    return cell.value.toString();
  }

  static double? _getCellValueDouble(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    if (cell == null || cell.value == null) return null;
    final val = cell.value;
    if (val is DoubleCellValue) return val.value;
    if (val is IntCellValue) return val.value.toDouble();
    if (val is TextCellValue) {
      final clean = val.value.toString().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(clean);
    }
    final str = val.toString().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(str);
  }

  static int? _getCellValueInt(List<Data?> row, int index) {
    if (index >= row.length) return null;
    final cell = row[index];
    if (cell == null || cell.value == null) return null;
    final val = cell.value;
    if (val is IntCellValue) return val.value;
    if (val is DoubleCellValue) return val.value.toInt();
    if (val is TextCellValue) {
      final clean = val.value.toString().replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(clean);
    }
    final str = val.toString().replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(str);
  }
}
