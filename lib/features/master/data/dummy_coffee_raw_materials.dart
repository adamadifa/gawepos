import 'package:flutter/material.dart';

class DummyCoffeeRawMaterial {
  final String name;
  final String category;
  final String unitName;
  final double costPrice;
  final double initialStock;
  final int minStock;

  const DummyCoffeeRawMaterial({
    required this.name,
    required this.category,
    required this.unitName,
    required this.costPrice,
    required this.initialStock,
    required this.minStock,
  });
}

class DummyRecipeIngredient {
  final String rawMaterialName;
  final double quantity;
  final String? notes;

  const DummyRecipeIngredient({
    required this.rawMaterialName,
    required this.quantity,
    this.notes,
  });
}

class DummyCoffeeProduct {
  final String name;
  final String sku;
  final String barcode;
  final String category;
  final String brand;
  final double sellPrice;
  final double grosirPrice;
  final String unitName;
  final Color badgeColor;
  final String shortCode;
  final IconData icon;
  final List<DummyRecipeIngredient> recipe;

  const DummyCoffeeProduct({
    required this.name,
    required this.sku,
    required this.barcode,
    required this.category,
    required this.brand,
    required this.sellPrice,
    required this.grosirPrice,
    required this.unitName,
    required this.badgeColor,
    required this.shortCode,
    required this.icon,
    required this.recipe,
  });
}

class CoffeeShopDummyData {
  // ─── 1. DAFTAR BAHAN BAKU (RAW MATERIALS) ───────────────────────────
  static const List<DummyCoffeeRawMaterial> rawMaterials = [
    // 1. Kopi & Biji
    DummyCoffeeRawMaterial(
      name: 'Biji Kopi Espresso Blend (Arabika 70% Robusta 30%)',
      category: 'Bahan Baku Kopi',
      unitName: 'Gram',
      costPrice: 220, // Rp 220.000 / kg -> Rp 220 / gram
      initialStock: 10000, // 10 Kg (10.000 gr)
      minStock: 1000,
    ),
    DummyCoffeeRawMaterial(
      name: 'Biji Kopi Single Origin Gayo Arabika',
      category: 'Bahan Baku Kopi',
      unitName: 'Gram',
      costPrice: 280, // Rp 280.000 / kg -> Rp 280 / gram
      initialStock: 5000,
      minStock: 500,
    ),
    DummyCoffeeRawMaterial(
      name: 'Bubuk Kopi Robusta Dampit',
      category: 'Bahan Baku Kopi',
      unitName: 'Gram',
      costPrice: 120, // Rp 120.000 / kg -> Rp 120 / gram
      initialStock: 5000,
      minStock: 500,
    ),

    // 2. Susu & Dairy
    DummyCoffeeRawMaterial(
      name: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)',
      category: 'Dairy & Susu',
      unitName: 'Ml',
      costPrice: 24, // Rp 24.000 / Liter -> Rp 24 / ml
      initialStock: 25000, // 25 Liter
      minStock: 3000,
    ),
    DummyCoffeeRawMaterial(
      name: 'Susu Evaporasi F&N',
      category: 'Dairy & Susu',
      unitName: 'Ml',
      costPrice: 45, // Rp 18.000 / 380ml
      initialStock: 7600, // 20 kaleng
      minStock: 1000,
    ),
    DummyCoffeeRawMaterial(
      name: 'Susu Kental Manis (Carnation/Omela)',
      category: 'Dairy & Susu',
      unitName: 'Gram',
      costPrice: 35, // Rp 17.500 / 500gr
      initialStock: 10000,
      minStock: 1000,
    ),
    DummyCoffeeRawMaterial(
      name: 'Susu Oat Milk (Oatside Barista Blend)',
      category: 'Dairy & Susu',
      unitName: 'Ml',
      costPrice: 42, // Rp 42.000 / Liter
      initialStock: 12000,
      minStock: 2000,
    ),

    // 3. Pemanis & Sirup
    DummyCoffeeRawMaterial(
      name: 'Sirup Gula Aren Cair Organik',
      category: 'Pemanis & Sirup',
      unitName: 'Ml',
      costPrice: 38, // Rp 38.000 / Liter
      initialStock: 15000,
      minStock: 2000,
    ),
    DummyCoffeeRawMaterial(
      name: 'Sirup Karamel (Monin / Davinci)',
      category: 'Pemanis & Sirup',
      unitName: 'Ml',
      costPrice: 160, // Rp 120.000 / 750ml
      initialStock: 3750,
      minStock: 500,
    ),
    DummyCoffeeRawMaterial(
      name: 'Sirup Vanila (Monin / Toffin)',
      category: 'Pemanis & Sirup',
      unitName: 'Ml',
      costPrice: 160,
      initialStock: 3750,
      minStock: 500,
    ),
    DummyCoffeeRawMaterial(
      name: 'Sirup Hazelnut',
      category: 'Pemanis & Sirup',
      unitName: 'Ml',
      costPrice: 160,
      initialStock: 3750,
      minStock: 500,
    ),
    DummyCoffeeRawMaterial(
      name: 'Simple Syrup (Gula Pasir Cair)',
      category: 'Pemanis & Sirup',
      unitName: 'Ml',
      costPrice: 18,
      initialStock: 10000,
      minStock: 1000,
    ),

    // 4. Bubuk Non-Kopi & Topping
    DummyCoffeeRawMaterial(
      name: 'Bubuk Matcha Premium Jepang',
      category: 'Bubuk Minuman',
      unitName: 'Gram',
      costPrice: 280, // Rp 280.000 / 1 Kg
      initialStock: 3000,
      minStock: 500,
    ),
    DummyCoffeeRawMaterial(
      name: 'Bubuk Cokelat Pure Cocoa Powder',
      category: 'Bubuk Minuman',
      unitName: 'Gram',
      costPrice: 180,
      initialStock: 5000,
      minStock: 500,
    ),
    DummyCoffeeRawMaterial(
      name: 'Bubuk Red Velvet',
      category: 'Bubuk Minuman',
      unitName: 'Gram',
      costPrice: 150,
      initialStock: 3000,
      minStock: 500,
    ),
    DummyCoffeeRawMaterial(
      name: 'Boba Pearl Tapioka',
      category: 'Topping',
      unitName: 'Gram',
      costPrice: 40,
      initialStock: 5000,
      minStock: 1000,
    ),
    DummyCoffeeRawMaterial(
      name: 'Grass Jelly (Cincau Hitam)',
      category: 'Topping',
      unitName: 'Gram',
      costPrice: 30,
      initialStock: 4000,
      minStock: 500,
    ),

    // 5. Kemasan & Packaging
    DummyCoffeeRawMaterial(
      name: 'Cup Plastik PET 16oz + Custom Logo',
      category: 'Kemasan & Packaging',
      unitName: 'Pcs',
      costPrice: 650,
      initialStock: 1000,
      minStock: 200,
    ),
    DummyCoffeeRawMaterial(
      name: 'Cup Plastik PET 12oz (Small)',
      category: 'Kemasan & Packaging',
      unitName: 'Pcs',
      costPrice: 550,
      initialStock: 500,
      minStock: 100,
    ),
    DummyCoffeeRawMaterial(
      name: 'Paper Cup Panas 8oz + Sleeve',
      category: 'Kemasan & Packaging',
      unitName: 'Pcs',
      costPrice: 850,
      initialStock: 500,
      minStock: 100,
    ),
    DummyCoffeeRawMaterial(
      name: 'Tutup Cup Lid Sealer Roll (Plastik Seal)',
      category: 'Kemasan & Packaging',
      unitName: 'Pcs',
      costPrice: 80,
      initialStock: 2400,
      minStock: 400,
    ),
    DummyCoffeeRawMaterial(
      name: 'Sedotan Higienis Steril Kertas/Plastik',
      category: 'Kemasan & Packaging',
      unitName: 'Pcs',
      costPrice: 120,
      initialStock: 1500,
      minStock: 200,
    ),
    DummyCoffeeRawMaterial(
      name: 'Kantong Plastik Kresek Takeaway 1 Cup (T-Bag)',
      category: 'Kemasan & Packaging',
      unitName: 'Pcs',
      costPrice: 150,
      initialStock: 800,
      minStock: 100,
    ),
  ];

  // ─── 2. DAFTAR MENU PRODUK JADI F&B (SIAP JUAL DI KASIR) ───────────
  static const List<DummyCoffeeProduct> menuProducts = [
    // 1. Signature Coffee
    DummyCoffeeProduct(
      name: 'Es Kopi Susu Gula Aren (Signature)',
      sku: 'COF-AREN-01',
      barcode: '899100100001',
      category: 'Coffee Specialties',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 18000,
      grosirPrice: 16000,
      unitName: 'Cup',
      badgeColor: Color(0xFF78350F), // Warm Amber Brown
      shortCode: 'KOPISU',
      icon: Icons.coffee_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Biji Kopi Espresso Blend (Arabika 70% Robusta 30%)', quantity: 18, notes: 'Double shot espresso (18 gr)'),
        DummyRecipeIngredient(rawMaterialName: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)', quantity: 120, notes: '120 ml fresh milk'),
        DummyRecipeIngredient(rawMaterialName: 'Sirup Gula Aren Cair Organik', quantity: 25, notes: '25 ml gula aren cair'),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1, notes: '1 pcs Cup 16oz'),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1, notes: '1 pcs Lid Seal'),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1, notes: '1 pcs Sedotan'),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Iced Caramel Macchiato',
      sku: 'COF-CARM-02',
      barcode: '899100100002',
      category: 'Coffee Specialties',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 24000,
      grosirPrice: 22000,
      unitName: 'Cup',
      badgeColor: Color(0xFFB45309), // Amber
      shortCode: 'CARMAC',
      icon: Icons.local_cafe_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Biji Kopi Espresso Blend (Arabika 70% Robusta 30%)', quantity: 18, notes: 'Double shot espresso'),
        DummyRecipeIngredient(rawMaterialName: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)', quantity: 140, notes: '140 ml fresh milk'),
        DummyRecipeIngredient(rawMaterialName: 'Sirup Karamel (Monin / Davinci)', quantity: 20, notes: '20 ml sirup karamel'),
        DummyRecipeIngredient(rawMaterialName: 'Sirup Vanila (Monin / Toffin)', quantity: 10, notes: '10 ml sirup vanila'),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Iced Hazelnut Latte',
      sku: 'COF-HAZL-03',
      barcode: '899100100003',
      category: 'Coffee Specialties',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 23000,
      grosirPrice: 21000,
      unitName: 'Cup',
      badgeColor: Color(0xFF92400E),
      shortCode: 'HAZLAT',
      icon: Icons.coffee_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Biji Kopi Espresso Blend (Arabika 70% Robusta 30%)', quantity: 18),
        DummyRecipeIngredient(rawMaterialName: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)', quantity: 130),
        DummyRecipeIngredient(rawMaterialName: 'Sirup Hazelnut', quantity: 25),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Iced Vanilla Oat Latte (Plant-Based)',
      sku: 'COF-VOAT-04',
      barcode: '899100100004',
      category: 'Coffee Specialties',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 28000,
      grosirPrice: 26000,
      unitName: 'Cup',
      badgeColor: Color(0xFF451A03),
      shortCode: 'VOAT',
      icon: Icons.coffee_maker_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Biji Kopi Espresso Blend (Arabika 70% Robusta 30%)', quantity: 18),
        DummyRecipeIngredient(rawMaterialName: 'Susu Oat Milk (Oatside Barista Blend)', quantity: 150, notes: '150 ml oat milk'),
        DummyRecipeIngredient(rawMaterialName: 'Sirup Vanila (Monin / Toffin)', quantity: 20),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Iced Americano / Long Black',
      sku: 'COF-AMER-05',
      barcode: '899100100005',
      category: 'Espresso & Black Coffee',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 15000,
      grosirPrice: 13000,
      unitName: 'Cup',
      badgeColor: Color(0xFF1E293B), // Slate Navy
      shortCode: 'AMER',
      icon: Icons.local_cafe_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Biji Kopi Espresso Blend (Arabika 70% Robusta 30%)', quantity: 18, notes: 'Double shot espresso'),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Hot Espresso Single Shot',
      sku: 'COF-ESPS-06',
      barcode: '899100100006',
      category: 'Espresso & Black Coffee',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 10000,
      grosirPrice: 9000,
      unitName: 'Cup',
      badgeColor: Color(0xFF0F172A),
      shortCode: 'ESP-S',
      icon: Icons.coffee_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Biji Kopi Espresso Blend (Arabika 70% Robusta 30%)', quantity: 10, notes: 'Single shot espresso (10 gr)'),
        DummyRecipeIngredient(rawMaterialName: 'Paper Cup Panas 8oz + Sleeve', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Hot Cappuccino Creamy 8oz',
      sku: 'COF-CAPP-07',
      barcode: '899100100007',
      category: 'Espresso & Black Coffee',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 20000,
      grosirPrice: 18000,
      unitName: 'Cup',
      badgeColor: Color(0xFF7C2D12),
      shortCode: 'CAPP',
      icon: Icons.coffee_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Biji Kopi Espresso Blend (Arabika 70% Robusta 30%)', quantity: 18),
        DummyRecipeIngredient(rawMaterialName: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)', quantity: 150, notes: 'Steamed milk + foam'),
        DummyRecipeIngredient(rawMaterialName: 'Paper Cup Panas 8oz + Sleeve', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Manual Brew V60 Single Origin Gayo',
      sku: 'COF-V60G-08',
      barcode: '899100100008',
      category: 'Manual Brew Single Origin',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 25000,
      grosirPrice: 22000,
      unitName: 'Cup',
      badgeColor: Color(0xFF065F46), // Dark Emerald
      shortCode: 'V60GAYO',
      icon: Icons.local_cafe_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Biji Kopi Single Origin Gayo Arabika', quantity: 15, notes: '15 gr grind medium fine (1:15 ratio)'),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Kopi Tubruk Robusta Dampit Tradisional',
      sku: 'COF-TBRK-09',
      barcode: '899100100009',
      category: 'Manual Brew Single Origin',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 8000,
      grosirPrice: 7000,
      unitName: 'Cup',
      badgeColor: Color(0xFF374151),
      shortCode: 'TUBRUK',
      icon: Icons.coffee_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Bubuk Kopi Robusta Dampit', quantity: 12, notes: '12 gr kopi robusta'),
        DummyRecipeIngredient(rawMaterialName: 'Simple Syrup (Gula Pasir Cair)', quantity: 15),
        DummyRecipeIngredient(rawMaterialName: 'Paper Cup Panas 8oz + Sleeve', quantity: 1),
      ],
    ),

    // 2. Non-Coffee Favorites
    DummyCoffeeProduct(
      name: 'Iced Matcha Green Tea Latte',
      sku: 'NON-MATC-10',
      barcode: '899100100010',
      category: 'Non-Coffee & Tea',
      brand: 'Gawe Artisan Beverage',
      sellPrice: 22000,
      grosirPrice: 20000,
      unitName: 'Cup',
      badgeColor: Color(0xFF15803D), // Green
      shortCode: 'MATCHA',
      icon: Icons.local_drink_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Bubuk Matcha Premium Jepang', quantity: 15, notes: '15 gr bubuk matcha'),
        DummyRecipeIngredient(rawMaterialName: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)', quantity: 140),
        DummyRecipeIngredient(rawMaterialName: 'Simple Syrup (Gula Pasir Cair)', quantity: 20),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Signature Dark Choco Ice',
      sku: 'NON-CHOC-11',
      barcode: '899100100011',
      category: 'Non-Coffee & Tea',
      brand: 'Gawe Artisan Beverage',
      sellPrice: 20000,
      grosirPrice: 18000,
      unitName: 'Cup',
      badgeColor: Color(0xFF3F2314), // Dark Chocolate
      shortCode: 'CHOCO',
      icon: Icons.fastfood_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Bubuk Cokelat Pure Cocoa Powder', quantity: 20, notes: '20 gr cokelat murni'),
        DummyRecipeIngredient(rawMaterialName: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)', quantity: 120),
        DummyRecipeIngredient(rawMaterialName: 'Susu Kental Manis (Carnation/Omela)', quantity: 15),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Iced Red Velvet Velvet Cream',
      sku: 'NON-RDVL-12',
      barcode: '899100100012',
      category: 'Non-Coffee & Tea',
      brand: 'Gawe Artisan Beverage',
      sellPrice: 22000,
      grosirPrice: 20000,
      unitName: 'Cup',
      badgeColor: Color(0xFF991B1B), // Deep Red
      shortCode: 'REDVEL',
      icon: Icons.local_drink_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Bubuk Red Velvet', quantity: 20),
        DummyRecipeIngredient(rawMaterialName: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)', quantity: 130),
        DummyRecipeIngredient(rawMaterialName: 'Susu Evaporasi F&N', quantity: 20),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Brown Sugar Fresh Milk with Boba',
      sku: 'NON-BOBA-13',
      barcode: '899100100013',
      category: 'Boba & Sweet Series',
      brand: 'Gawe Artisan Beverage',
      sellPrice: 24000,
      grosirPrice: 21000,
      unitName: 'Cup',
      badgeColor: Color(0xFF713F12), // Deep Brown
      shortCode: 'BOBAMLK',
      icon: Icons.bubble_chart_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Boba Pearl Tapioka', quantity: 40, notes: '40 gr boba pearl'),
        DummyRecipeIngredient(rawMaterialName: 'Sirup Gula Aren Cair Organik', quantity: 30),
        DummyRecipeIngredient(rawMaterialName: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)', quantity: 150),
        DummyRecipeIngredient(rawMaterialName: 'Susu Evaporasi F&N', quantity: 15),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Es Kopi Susu Cincau (Grass Jelly Coffee)',
      sku: 'COF-CNCU-14',
      barcode: '899100100014',
      category: 'Coffee Specialties',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 20000,
      grosirPrice: 18000,
      unitName: 'Cup',
      badgeColor: Color(0xFF1F2937),
      shortCode: 'KOPCNCU',
      icon: Icons.coffee_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Biji Kopi Espresso Blend (Arabika 70% Robusta 30%)', quantity: 18),
        DummyRecipeIngredient(rawMaterialName: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)', quantity: 110),
        DummyRecipeIngredient(rawMaterialName: 'Sirup Gula Aren Cair Organik', quantity: 20),
        DummyRecipeIngredient(rawMaterialName: 'Grass Jelly (Cincau Hitam)', quantity: 35, notes: '35 gr cincau potong'),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 16oz + Custom Logo', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
    DummyCoffeeProduct(
      name: 'Iced Coffee Latte Regular 12oz',
      sku: 'COF-LATR-15',
      barcode: '899100100015',
      category: 'Coffee Specialties',
      brand: 'Gawe Coffee Roastery',
      sellPrice: 16000,
      grosirPrice: 14000,
      unitName: 'Cup',
      badgeColor: Color(0xFF854D0E),
      shortCode: 'LATTE12',
      icon: Icons.local_cafe_rounded,
      recipe: [
        DummyRecipeIngredient(rawMaterialName: 'Biji Kopi Espresso Blend (Arabika 70% Robusta 30%)', quantity: 14, notes: '14 gr espresso'),
        DummyRecipeIngredient(rawMaterialName: 'Susu Fresh Milk Pasteurisasi (Greenfields / Diamond)', quantity: 100),
        DummyRecipeIngredient(rawMaterialName: 'Simple Syrup (Gula Pasir Cair)', quantity: 15),
        DummyRecipeIngredient(rawMaterialName: 'Cup Plastik PET 12oz (Small)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Tutup Cup Lid Sealer Roll (Plastik Seal)', quantity: 1),
        DummyRecipeIngredient(rawMaterialName: 'Sedotan Higienis Steril Kertas/Plastik', quantity: 1),
      ],
    ),
  ];
}
