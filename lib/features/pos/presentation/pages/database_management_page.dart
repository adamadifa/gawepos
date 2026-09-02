import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive_io.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';

class DatabaseManagementPage extends StatefulWidget {
  const DatabaseManagementPage({super.key});

  @override
  State<DatabaseManagementPage> createState() => _DatabaseManagementPageState();
}

class _DatabaseManagementPageState extends State<DatabaseManagementPage> {
  List<FileSystemEntity> _backups = [];
  bool _isLoading = false;
  String _dbSize = "Unknown";
  String _dbPath = "";

  @override
  void initState() {
    super.initState();
    _loadDbInfo();
    _loadBackups();
  }

  Future<void> _loadDbInfo() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'posmobile.db'));
      if (await file.exists()) {
        final length = await file.length();
        setState(() {
          _dbPath = file.path;
          _dbSize = _formatBytes(length);
        });
      }
    } catch (e) {
      debugPrint("Gagal memuat info DB: $e");
    }
  }

  Future<Directory> _getBackupsDir() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(dbFolder.path, 'backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final dir = await _getBackupsDir();
      final entities = dir.listSync().where((e) => e.path.endsWith('.zip')).toList();
      entities.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      setState(() {
        _backups = entities;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat daftar cadangan: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final sourceFile = File(p.join(dbFolder.path, 'posmobile.db'));
      if (!await sourceFile.exists()) {
        throw Exception("Database aktif tidak ditemukan.");
      }

      final backupsDir = await _getBackupsDir();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupZipPath = p.join(backupsDir.path, 'backup_$timestamp.zip');

      final archive = Archive();

      // 1. Database file
      final dbBytes = await sourceFile.readAsBytes();
      archive.addFile(ArchiveFile('posmobile.db', dbBytes.length, dbBytes));

      // 2. Images and assets
      final List<String> assetFolders = ['products', 'images', 'logos'];
      for (final folderName in assetFolders) {
        final folderDir = Directory(p.join(dbFolder.path, folderName));
        if (await folderDir.exists()) {
          final files = folderDir.listSync(recursive: true);
          for (final entity in files) {
            if (entity is File) {
              final relativePath = p.relative(entity.path, from: dbFolder.path);
              final fileBytes = await entity.readAsBytes();
              archive.addFile(ArchiveFile(relativePath, fileBytes.length, fileBytes));
            }
          }
        }
      }

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      final backupZipFile = File(backupZipPath);
      await backupZipFile.writeAsBytes(zipBytes);

      await _loadDbInfo();
      await _loadBackups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Cadangan data & gambar berhasil dibuat!', style: GoogleFonts.poppins(fontSize: 12.5)),
              ],
            ),
            backgroundColor: AppConstants.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        _showShareImmediatelyDialog(backupZipFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat cadangan: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showShareImmediatelyDialog(File backupFile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bagikan File Cadangan?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'File cadangan ZIP berhasil dibuat. Apakah Anda ingin membagikan atau menyimpannya ke Google Drive / WhatsApp sekarang?',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('NANTI', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _shareBackup(backupFile);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('BAGIKAN SEKARANG', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareBackup(File file) async {
    try {
      final name = p.basename(file.path);
      await Share.shareXFiles([XFile(file.path)], text: 'Cadangan Lengkap GawePOS - $name');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan file: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Cadangan?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFFDC2626))),
        content: Text(
          'Apakah Anda yakin ingin menghapus file cadangan ini dari memori lokal? Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('BATAL', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('HAPUS', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        if (await file.exists()) {
          await file.delete();
        }
        await _loadBackups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File cadangan berhasil dihapus.', style: GoogleFonts.poppins(fontSize: 12.5)),
              backgroundColor: AppConstants.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus file: $e', style: GoogleFonts.poppins()),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreBackup(File backupFile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Pulihkan Database & Gambar?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFFDC2626)),
        ),
        content: Text(
          'Peringatan: Seluruh data transaksi, produk, logo toko, dan foto saat ini akan ditimpa dengan data dari file cadangan ini.\n\nAplikasi akan ditutup secara otomatis setelah pemulihan.',
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('BATAL', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('PULIHKAN & KELUAR', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final db = getIt<AppDatabase>();
        await db.close();

        final bytes = await backupFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        final dbFolder = await getApplicationDocumentsDirectory();

        for (final archiveFile in archive) {
          final filename = archiveFile.name;
          if (archiveFile.isFile) {
            final data = archiveFile.content as List<int>;
            final targetFile = File(p.join(dbFolder.path, filename));
            await targetFile.parent.create(recursive: true);
            await targetFile.writeAsBytes(data);
          }
        }

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Pemulihan Sukses', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF059669))),
              content: Text(
                'Seluruh data database dan file gambar berhasil dipulihkan. Silakan buka kembali aplikasi setelah keluar.',
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => exit(0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('KELUAR APLIKASI', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memulihkan database: $e', style: GoogleFonts.poppins()),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreFromExternalFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);

        if (!path.endsWith('.zip')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Format file harus berformat .zip', style: GoogleFonts.poppins()),
                backgroundColor: AppConstants.errorColor,
              ),
            );
          }
          return;
        }

        await _restoreBackup(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka file picker: $e', style: GoogleFonts.poppins()),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup & Restore Data',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Cadangkan & pulihkan basis data SQLite aplikasi',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildDbInfoCard(),
              _buildActionRow(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    Text(
                      'Daftar Cadangan Lokal (${_backups.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading && _backups.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                    : _backups.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _backups.length,
                            itemBuilder: (context, index) {
                              final entity = _backups[index];
                              final file = File(entity.path);
                              final stat = file.statSync();
                              final name = p.basename(file.path);
                              final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(stat.modified);
                              final formattedSize = _formatBytes(stat.size);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.archive_rounded, color: Color(0xFF4F46E5), size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$formattedDate • $formattedSize',
                                              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF1A56DB)),
                                            onPressed: () => _shareBackup(file),
                                            tooltip: 'Bagikan File',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.settings_backup_restore_rounded, size: 18, color: Color(0xFF059669)),
                                            onPressed: () => _restoreBackup(file),
                                            tooltip: 'Pulihkan',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                            onPressed: () => _deleteBackup(file),
                                            tooltip: 'Hapus',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.15),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
            ),
        ],
      ),
    );
  }

  Widget _buildDbInfoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.storage_rounded, size: 16, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 8),
              Text(
                'Informasi Database SQLite',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13.5, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ukuran File Database:', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
              Text(_dbSize, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lokasi File:', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _dbPath,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.poppins(fontSize: 10.5, color: const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _createBackup,
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(
                'CADANGKAN DATA',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 11.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _restoreFromExternalFile,
              icon: const Icon(Icons.folder_open_rounded, size: 18, color: Color(0xFF0F172A)),
              label: Text(
                'PULIHKAN FILE',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A), fontSize: 11.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 36, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum ada file cadangan database lokal.',
            style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
