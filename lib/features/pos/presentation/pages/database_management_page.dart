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
      // Sort newest first
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
          SnackBar(content: Text('Gagal memuat daftar cadangan: $e'), backgroundColor: AppConstants.errorColor),
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

      // Inisialisasi Archive untuk membuat file ZIP
      final archive = Archive();

      // 1. Tambahkan file database
      final dbBytes = await sourceFile.readAsBytes();
      archive.addFile(ArchiveFile('posmobile.db', dbBytes.length, dbBytes));

      // 2. Tambahkan gambar produk (jika ada folder/file di path_provider)
      // Mencari letak gambar produk. Di master_repository biasanya disimpan di subfolder /products atau /images.
      // Kita backup semua file di subfolder 'products', 'images', dan 'logos' di database folder.
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

      // Encode archive menjadi format ZIP
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes == null) {
        throw Exception("Gagal mengompresi data cadangan.");
      }

      // Tulis file ZIP
      final backupZipFile = File(backupZipPath);
      await backupZipFile.writeAsBytes(zipBytes);
      
      await _loadDbInfo();
      await _loadBackups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadangan terpadu (Data & Gambar) berhasil dibuat!'), backgroundColor: AppConstants.successColor),
        );

        // Offer to share backup immediately
        _showShareImmediatelyDialog(backupZipFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat cadangan: $e'), backgroundColor: AppConstants.errorColor),
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
        title: Text('Bagikan Cadangan?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda ingin membagikan atau menyimpan file cadangan (ZIP) ini ke penyimpanan eksternal sekarang?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('TIDAK', style: GoogleFonts.poppins(color: AppConstants.textLightColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _shareBackup(backupFile);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
            child: Text('BAGIKAN / SIMPAN', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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
          SnackBar(content: Text('Gagal membagikan file: $e'), backgroundColor: AppConstants.errorColor),
        );
      }
    }
  }

  Future<void> _deleteBackup(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Cadangan?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus file cadangan ini? Tindakan ini tidak dapat dibatalkan.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('BATAL', style: GoogleFonts.poppins(color: AppConstants.textLightColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.errorColor),
            child: Text('HAPUS', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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
            const SnackBar(content: Text('File cadangan berhasil dihapus.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus file: $e'), backgroundColor: AppConstants.errorColor),
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
        title: Text('Pulihkan Database & Gambar?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppConstants.errorColor)),
        content: Text(
          'Peringatan: Proses ini akan menimpa seluruh data transaksi, produk, logo toko, dan semua foto saat ini dengan data dari file cadangan ini.\n\nAplikasi akan ditutup secara otomatis setelah pemulihan untuk memuat ulang data baru.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('BATAL', style: GoogleFonts.poppins(color: AppConstants.textLightColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.errorColor),
            child: Text('PULIHKAN & KELUAR', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // 1. Tutup koneksi Drift Database aktif
        final db = getIt<AppDatabase>();
        await db.close();

        // 2. Dekompresi file ZIP cadangan
        final bytes = await backupFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        final dbFolder = await getApplicationDocumentsDirectory();

        // 3. Ekstrak masing-masing item di dalam ZIP
        for (final archiveFile in archive) {
          final filename = archiveFile.name;
          if (archiveFile.isFile) {
            final data = archiveFile.content as List<int>;
            final targetFile = File(p.join(dbFolder.path, filename));
            
            // Buat direktori jika folder tujuan belum ada (seperti logos/ atau products/)
            await targetFile.parent.create(recursive: true);
            await targetFile.writeAsBytes(data);
          }
        }

        // 4. Beritahu sukses dan tutup aplikasi
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text('Pemulihan Sukses', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppConstants.successColor)),
              content: Text('Seluruh data database dan file gambar berhasil dipulihkan. Aplikasi harus ditutup untuk menerapkan perubahan ini. Silakan buka kembali aplikasi setelah keluar.', style: GoogleFonts.poppins()),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    exit(0);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                  child: Text('KELUAR APLIKASI', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memulihkan database: $e'), backgroundColor: AppConstants.errorColor),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restoreFromExternalFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final file = File(path);
        
        // Validasi ekstensi harus .zip
        if (!path.endsWith('.zip')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Format file tidak didukung. Harap pilih file cadangan berformat .zip'),
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
          SnackBar(content: Text('Gagal membuka file picker: $e'), backgroundColor: AppConstants.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Backup & Restore Data',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: AppConstants.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Info Card
              _buildDbInfoCard(),
              
              // Action Buttons Row
              _buildActionRow(),

              // Divider / Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'DAFTAR CADANGAN LOKAL',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textLightColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
                  ],
                ),
              ),

              // Backups List
              Expanded(
                child: _isLoading && _backups.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _backups.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _backups.length,
                            itemBuilder: (context, index) {
                              final entity = _backups[index];
                              final file = File(entity.path);
                              final stat = file.statSync();
                              final name = p.basename(file.path);
                              final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(stat.modified);
                              final formattedSize = _formatBytes(stat.size);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.storage_rounded, color: Colors.indigo),
                                  ),
                                  title: Text(
                                    name,
                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '$formattedDate • $formattedSize',
                                    style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.share_rounded, size: 18, color: AppConstants.primaryColor),
                                        onPressed: () => _shareBackup(file),
                                        tooltip: 'Bagikan',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.settings_backup_restore_rounded, size: 18, color: AppConstants.successColor),
                                        onPressed: () => _restoreBackup(file),
                                        tooltip: 'Pulihkan',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppConstants.errorColor),
                                        onPressed: () => _deleteBackup(file),
                                        tooltip: 'Hapus',
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
              color: Colors.black.withOpacity(0.1),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildDbInfoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Database Aktif',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppConstants.textDarkColor),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ukuran Database:', style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor)),
              Text(_dbSize, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.textDarkColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lokasi File:', style: GoogleFonts.poppins(fontSize: 12, color: AppConstants.textLightColor)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _dbPath,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.poppins(fontSize: 10, color: AppConstants.textLightColor),
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
              icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
              label: Text(
                'CADANGKAN DATA',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _restoreFromExternalFile,
              icon: const Icon(Icons.folder_open_rounded, color: AppConstants.primaryColor),
              label: Text(
                'PULIHKAN DATA',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: AppConstants.primaryColor, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppConstants.primaryColor,
                side: const BorderSide(color: AppConstants.primaryColor),
                minimumSize: const Size.fromHeight(48),
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
          Icon(Icons.storage_outlined, size: 54, color: AppConstants.textLightColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Belum ada file cadangan database.',
            style: GoogleFonts.poppins(color: AppConstants.textLightColor, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
