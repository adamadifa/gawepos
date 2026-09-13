import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/product_excel_service.dart';
import '../bloc/product_cubit.dart';
import '../bloc/category_cubit.dart';
import '../bloc/brand_cubit.dart';

class ImportProductExcelDialog extends StatefulWidget {
  const ImportProductExcelDialog({super.key});

  @override
  State<ImportProductExcelDialog> createState() => _ImportProductExcelDialogState();
}

class _ImportProductExcelDialogState extends State<ImportProductExcelDialog> {
  bool _isExportingTemplate = false;
  bool _isParsing = false;
  bool _isImporting = false;
  String? _selectedFileName;
  ExcelParseResult? _parseResult;
  int _importProgress = 0;
  int _importTotal = 0;

  Future<void> _handleDownloadTemplate() async {
    setState(() => _isExportingTemplate = true);
    try {
      final categories = await context.read<ProductCubit>().repository.getCategories();
      final brands = await context.read<ProductCubit>().repository.getBrands();

      await ProductExcelService.exportTemplateAndShare(
        existingCategories: categories,
        existingBrands: brands,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat template: $e', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingTemplate = false);
    }
  }

  Future<void> _handlePickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);

      if (bytes == null) {
        throw Exception('Gagal membaca data file Excel.');
      }

      setState(() {
        _isParsing = true;
        _selectedFileName = file.name;
        _parseResult = null;
      });

      final parsed = ProductExcelService.parseExcelBytes(bytes);

      setState(() {
        _parseResult = parsed;
        _isParsing = false;
      });
    } catch (e) {
      setState(() => _isParsing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memproses file: $e', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleStartImport() async {
    if (_parseResult == null || _parseResult!.products.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = _parseResult!.products.length;
    });

    try {
      final repo = context.read<ProductCubit>().repository;
      final count = await repo.importProductsFromExcelBatch(
        _parseResult!,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _importProgress = current;
              _importTotal = total;
            });
          }
        },
      );

      if (mounted) {
        // Refresh master data di cubit
        context.read<ProductCubit>().loadProducts();
        context.read<CategoryCubit>().loadCategories();
        context.read<BrandCubit>().loadBrands();

        Navigator.pop(context, count);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengimpor produk: $e', style: GoogleFonts.poppins()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.table_view_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import Produk via Excel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Mendukung multi-sheet (Kategori, Merek, Produk)',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isImporting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Content Body (Scrollable)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Step 1: Download Template
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E293B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '1',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Unduh Template Excel Resmi',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Template berformat Multi-Sheet (Sheet Kategori, Sheet Merek, dan Sheet Produk). Kategori yang sudah ada di POS akan otomatis tercantum sebagai panduan.',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _isExportingTemplate || _isImporting ? null : _handleDownloadTemplate,
                              icon: _isExportingTemplate
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.file_download_outlined, size: 18),
                              label: Text(
                                _isExportingTemplate ? 'Menyiapkan Template...' : 'Download / Bagikan Template (.xlsx)',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Step 2: Upload File
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E293B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '2',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Pilih File Excel yang Telah Diisi',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pilih file .xlsx dari penyimpanan perangkat Anda untuk dibaca & divalidasi.',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: _isImporting || _isParsing ? null : _handlePickFile,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedFileName != null ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                    width: _selectedFileName != null ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _selectedFileName != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                                      color: _selectedFileName != null ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedFileName ?? 'Ketuk untuk memilih file (.xlsx / .xls)...',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: _selectedFileName != null ? FontWeight.w600 : FontWeight.normal,
                                          color: _selectedFileName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Parsing Loading
                      if (_isParsing) ...[
                        const SizedBox(height: 16),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ),
                      ],

                      // Preview Ringkasan Hasil Baca File
                      if (_parseResult != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _parseResult!.hasErrors ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _parseResult!.hasErrors ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _parseResult!.hasErrors ? Icons.error_outline_rounded : Icons.task_alt_rounded,
                                    color: _parseResult!.hasErrors ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _parseResult!.hasErrors ? 'Hasil Validasi File (Error)' : 'Hasil Validasi Data',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _parseResult!.hasErrors ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_parseResult!.hasErrors) ...[
                                for (final err in _parseResult!.errors)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• $err',
                                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF991B1B)),
                                    ),
                                  ),
                              ] else ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildBadge(
                                      icon: Icons.inventory_2_outlined,
                                      label: '${_parseResult!.products.length} Produk Siap Diimpor',
                                      color: const Color(0xFF0F172A),
                                    ),
                                    if (_parseResult!.categories.isNotEmpty)
                                      _buildBadge(
                                        icon: Icons.category_outlined,
                                        label: '${_parseResult!.categories.length} Kategori Referensi',
                                        color: const Color(0xFF0369A1),
                                      ),
                                    if (_parseResult!.brands.isNotEmpty)
                                      _buildBadge(
                                        icon: Icons.branding_watermark_outlined,
                                        label: '${_parseResult!.brands.length} Merek Referensi',
                                        color: const Color(0xFF6D28D9),
                                      ),
                                  ],
                                ),
                                if (_parseResult!.warnings.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'Catatan / Peringatan (${_parseResult!.warnings.length}):',
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF854D0E)),
                                  ),
                                  const SizedBox(height: 4),
                                  for (final warn in _parseResult!.warnings.take(3))
                                    Text(
                                      '• $warn',
                                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF854D0E)),
                                    ),
                                  if (_parseResult!.warnings.length > 3)
                                    Text(
                                      '...dan ${_parseResult!.warnings.length - 3} lainnya',
                                      style: GoogleFonts.poppins(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF854D0E)),
                                    ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Progress Bar saat Sedang Import
                      if (_isImporting) ...[
                        const SizedBox(height: 18),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sedang Mengimpor Data...',
                                  style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '$_importProgress / $_importTotal Produk',
                                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: _importTotal > 0 ? (_importProgress / _importTotal) : null,
                                minHeight: 8,
                                color: const Color(0xFF10B981),
                                backgroundColor: const Color(0xFFE2E8F0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isImporting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: (_parseResult != null && _parseResult!.hasProducts && !_isImporting)
                          ? _handleStartImport
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: _isImporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.file_upload_outlined, size: 20),
                      label: Text(
                        _isImporting ? 'Mengimpor...' : 'Mulai Import Produk',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
