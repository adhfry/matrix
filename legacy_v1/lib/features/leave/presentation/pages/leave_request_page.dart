import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/leave_request_model.dart';
import '../../data/repositories/leave_request_repository.dart';
import '../providers/leave_request_provider.dart';
import '../widgets/file_preview_dialog.dart';

class LeaveRequestPage extends ConsumerStatefulWidget {
  const LeaveRequestPage({super.key});

  @override
  ConsumerState<LeaveRequestPage> createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends ConsumerState<LeaveRequestPage> {
  DateTime _selectedMonth = DateTime.now();

  void _changeMonth(int monthDelta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthDelta,
      );
    });
    ref.invalidate(leaveRequestProvider);
  }

  @override
  Widget build(BuildContext context) {
    final leaveAsync = ref.watch(
      leaveRequestProvider((_selectedMonth.month, _selectedMonth.year)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Izin/Cuti'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          Expanded(
            child: leaveAsync.when(
              data: (leave) => _buildContent(leave),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildError(error.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showLeaveRequestDialog(),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Ajukan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
                style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(LeaveRequestModel leave) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          leaveRequestProvider((_selectedMonth.month, _selectedMonth.year)),
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatsCards(leave.stats),
          const SizedBox(height: 16),
          Text(
            'Daftar Pengajuan (${leave.leaves.length})',
            style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (leave.leaves.isEmpty)
            _buildEmptyState()
          else
            ...leave.leaves.map((item) => _buildLeaveCard(item)),
        ],
      ),
    );
  }

  Widget _buildStatsCards(LeaveStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total',
            stats.total.toString(),
            Icons.event_note,
            AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Pending',
            stats.pending.toString(),
            Icons.hourglass_empty,
            AppColors.warning,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Disetujui',
            stats.approved.toString(),
            Icons.check_circle,
            AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Ditolak',
            stats.rejected.toString(),
            Icons.cancel,
            AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.h6.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(LeaveItem item) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getLeaveTypeLabel(item.leaveType),
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('dd MMM', 'id_ID').format(DateTime.parse(item.startDate))} - ${DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(item.endDate))}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(item.status),
              ],
            ),
            const Divider(height: 24),

            // Duration
            Row(
              children: [
                Icon(Icons.event, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '${item.durationDays} hari',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Reason
            Text(
              'Alasan:',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(item.reason, style: AppTextStyles.bodyMedium),

            // Attachment
            if (item.attachmentPath != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  _showAttachmentPreview(item.attachmentPath!);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.attachmentPath!.toLowerCase().endsWith('.pdf')
                            ? Icons.picture_as_pdf
                            : Icons.image,
                        size: 16,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lihat Lampiran',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: AppColors.info,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Deduction
            if (item.deductionAmount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Potongan: ${formatter.format(item.deductionAmount)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Admin Notes
            if (item.adminNotes != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.textHint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Catatan Admin:',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.adminNotes!,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getLeaveTypeLabel(String type) {
    switch (type) {
      case 'Sakit':
        return '🏥 Sakit';
      case 'Izin':
        return '📝 Izin';
      case 'Cuti':
        return '🏖️ Cuti';
      case 'Alpa':
        return '❌ Alpa';
      default:
        return type;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'Pending':
        color = AppColors.warning;
        text = 'Menunggu';
        icon = Icons.hourglass_empty;
        break;
      case 'Approved':
        color = AppColors.success;
        text = 'Disetujui';
        icon = Icons.check_circle;
        break;
      case 'Approved_WithDeduction':
        color = AppColors.info;
        text = 'Disetujui + Potongan';
        icon = Icons.check_circle_outline;
        break;
      case 'Rejected':
        color = AppColors.error;
        text = 'Ditolak';
        icon = Icons.cancel;
        break;
      default:
        color = AppColors.textHint;
        text = status;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Belum ada pengajuan',
              style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Klik tombol di bawah untuk mengajukan izin/cuti',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data',
              style: AppTextStyles.h6.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(
                  leaveRequestProvider((
                    _selectedMonth.month,
                    _selectedMonth.year,
                  )),
                );
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveRequestDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LeaveRequestForm(
        onSuccess: () {
          ref.invalidate(leaveRequestProvider);
        },
      ),
    );
  }

  void _showAttachmentPreview(String url) {
    final fileName = url.split('/').last;
    showDialog(
      context: context,
      builder: (context) => FilePreviewDialog(
        url: url,
        fileName: fileName,
      ),
    );
  }
}

// Form Widget untuk pengajuan
class _LeaveRequestForm extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const _LeaveRequestForm({required this.onSuccess});

  @override
  ConsumerState<_LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends ConsumerState<_LeaveRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  String _leaveType = 'Izin';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  File? _attachment;
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final image = await picker.pickImage(
                  source: ImageSource.camera,
                );
                if (image != null) {
                  setState(() {
                    _attachment = File(image.path);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  setState(() {
                    _attachment = File(image.path);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('Pilih File PDF'),
              onTap: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result != null && result.files.single.path != null) {
                  setState(() {
                    _attachment = File(result.files.single.path!);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(leaveRequestRepositoryProvider);
      await repository.submitLeaveRequest(
        leaveType: _leaveType,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonController.text,
        attachment: _attachment,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengajuan berhasil dikirim')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showLocalFilePreview() {
    if (_attachment == null) return;
    showDialog(
      context: context,
      builder: (context) => LocalFilePreviewDialog(
        file: _attachment!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ajukan Izin/Cuti',
                      style: AppTextStyles.h5.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Leave Type
              Text(
                'Jenis',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _leaveType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'Sakit', child: Text('🏥 Sakit')),
                  DropdownMenuItem(value: 'Izin', child: Text('📝 Izin')),
                  DropdownMenuItem(value: 'Cuti', child: Text('🏖️ Cuti')),
                ],
                onChanged: (value) => setState(() => _leaveType = value!),
              ),
              const SizedBox(height: 16),

              // Date Range
              Text(
                'Tanggal',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          setState(() => _startDate = date);
                          if (_endDate.isBefore(_startDate)) {
                            setState(() => _endDate = _startDate);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('-'),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          setState(() => _endDate = date);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Reason
              Text(
                'Alasan',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Jelaskan alasan Anda...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Alasan harus diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Attachment
              Text(
                'Lampiran (Opsional)',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (_attachment == null)
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Pilih File/Foto'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _showLocalFilePreview,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _attachment!.path.endsWith('.pdf')
                              ? Icon(
                                  Icons.picture_as_pdf,
                                  color: AppColors.primary,
                                  size: 32,
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _attachment!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _attachment!.path.split('/').last.split('\\').last,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: _showLocalFilePreview,
                              child: Text(
                                'Tap untuk preview',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _attachment = null),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Kirim Pengajuan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
