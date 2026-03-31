import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vanavil_ui/vanavil_ui.dart';

import '../../data/attachment_service.dart';
import '../../data/firestore_records.dart';

// Conditional imports for mobile-only features.
// On web these are never called, just imported for type resolution.
import 'proof_submission_mobile.dart'
    if (dart.library.html) 'proof_submission_stub.dart' as mobile;

// ---------------------------------------------------------------------------
// Data class for a file the child has selected
// ---------------------------------------------------------------------------

class SelectedProofFile {
  const SelectedProofFile({
    required this.filePath,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    this.bytes,
  });

  final String filePath;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final Uint8List? bytes;
}

// ---------------------------------------------------------------------------
// Proof submission screen
// ---------------------------------------------------------------------------

class ProofSubmissionScreen extends StatefulWidget {
  const ProofSubmissionScreen({
    super.key,
    required this.assignmentId,
    required this.taskId,
    required this.childId,
    required this.taskTitle,
    this.isResubmission = false,
  });

  final String assignmentId;
  final String taskId;
  final String childId;
  final String taskTitle;
  final bool isResubmission;

  @override
  State<ProofSubmissionScreen> createState() => _ProofSubmissionScreenState();
}

class _ProofSubmissionScreenState extends State<ProofSubmissionScreen> {
  static const _maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB

  final _attachmentService = AttachmentService();
  final _imagePicker = ImagePicker();
  final _noteController = TextEditingController();

  final List<SelectedProofFile> _selectedFiles = [];
  bool _isSubmitting = false;
  String _uploadProgress = '';
  String? _error;

  // Voice recording state (mobile only)
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_onNoteChanged);
  }

  void _onNoteChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    _recordingTimer?.cancel();
    if (!kIsWeb) mobile.disposeRecorder();
    super.dispose();
  }

  // ── File picking ────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final image = await _imagePicker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 85,
    );
    if (image == null) return;
    await _addXFile(image);
  }

  Future<void> _pickVideo() async {
    final video = await _imagePicker.pickVideo(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
    );
    if (video == null) return;
    await _addXFile(video);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: kIsWeb, // on web, load bytes into memory
    );
    if (result == null) return;

    for (final pf in result.files) {
      final size = pf.size;
      if (size > _maxFileSizeBytes) {
        _showFileTooLarge(pf.name);
        continue;
      }
      final contentType = contentTypeFromFileName(pf.name);
      setState(() {
        _selectedFiles.add(
          SelectedProofFile(
            filePath: pf.path ?? '',
            fileName: pf.name,
            contentType: contentType,
            sizeBytes: size,
            bytes: pf.bytes,
          ),
        );
      });
    }
  }

  Future<void> _addXFile(XFile xFile) async {
    final bytes = await xFile.readAsBytes();
    final size = bytes.length;
    if (size > _maxFileSizeBytes) {
      _showFileTooLarge(xFile.name);
      return;
    }
    final contentType = contentTypeFromFileName(xFile.name);
    setState(() {
      _selectedFiles.add(
        SelectedProofFile(
          filePath: xFile.path,
          fileName: xFile.name,
          contentType: contentType,
          sizeBytes: size,
          bytes: bytes,
        ),
      );
    });
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  void _showFileTooLarge(String fileName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$fileName" is too large. Max size is 50 MB.'),
        backgroundColor: VanavilPalette.coral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Voice recording (mobile only) ───────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (kIsWeb) return;
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await mobile.hasRecordingPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission is required.'),
            backgroundColor: VanavilPalette.coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      await mobile.startRecording();

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
        if (_recordingDuration.inSeconds >= 120) {
          _stopRecording();
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not start recording.'),
          backgroundColor: VanavilPalette.coral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final result = await mobile.stopRecording();
    if (result == null) {
      setState(() => _isRecording = false);
      return;
    }

    final duration = _recordingDuration;
    final durationLabel =
        '${duration.inMinutes}m${(duration.inSeconds % 60).toString().padLeft(2, '0')}s';

    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
      _selectedFiles.add(
        SelectedProofFile(
          filePath: result.filePath,
          fileName: 'voice_note_$durationLabel.m4a',
          contentType: 'audio/mp4',
          sizeBytes: result.sizeBytes,
          bytes: result.bytes,
        ),
      );
    });
  }

  String _formatRecordingTime(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please write an explanation before submitting.'),
          backgroundColor: VanavilPalette.coral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _uploadProgress = 'Preparing upload...';
    });

    try {
      final entries = <SubmissionFileEntry>[];

      for (var i = 0; i < _selectedFiles.length; i++) {
        final sf = _selectedFiles[i];
        setState(() {
          _uploadProgress =
              'Uploading ${i + 1} of ${_selectedFiles.length}...';
        });

        final UploadResult result;
        if (sf.bytes != null) {
          result = await _attachmentService.uploadChildProofBytes(
            assignmentId: widget.assignmentId,
            childId: widget.childId,
            fileName: sf.fileName,
            contentType: sf.contentType,
            bytes: sf.bytes!,
          );
        } else {
          result = await _attachmentService.uploadChildProof(
            assignmentId: widget.assignmentId,
            childId: widget.childId,
            fileName: sf.fileName,
            contentType: sf.contentType,
            filePath: sf.filePath,
          );
        }

        entries.add(
          SubmissionFileEntry(
            objectKey: result.objectKey,
            fileName: sf.fileName,
            contentType: result.contentType,
            sizeBytes: sf.sizeBytes,
          ),
        );
      }

      setState(() => _uploadProgress = 'Saving submission...');

      await _attachmentService.submitChildProof(
        assignmentId: widget.assignmentId,
        taskId: widget.taskId,
        childId: widget.childId,
        files: entries,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Proof submitted!'),
            ],
          ),
          backgroundColor: VanavilPalette.leaf,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = _friendlyError(e);
      });
    }
  }

  String _friendlyError(Object error) {
    final msg = error.toString().replaceFirst('Exception: ', '');
    if (msg.contains('VANAVIL_API_BASE_URL')) {
      return 'Upload is not ready yet. Ask your parent to check the setup.';
    }
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Could not upload. Check your internet and try again.';
    }
    if (msg.contains('child-upload')) {
      return 'The upload service is not available yet. Ask your parent to check the backend.';
    }
    return msg.isEmpty ? 'Something went wrong. Try again.' : msg;
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final headerTitle = widget.isResubmission
        ? 'Fix And Resubmit'
        : 'Submit Your Work';
    final headerGradient = widget.isResubmission
        ? const [VanavilPalette.coral, Color(0xFFEF5350)]
        : const [VanavilPalette.leaf, Color(0xFF66BB6A)];

    return Scaffold(
      body: Stack(
        children: [
          // ── Sky gradient background ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFD0ECFF),
                  Color(0xFFEFF8FF),
                  VanavilPalette.creamSoft,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.35, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header bar ──
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: headerGradient),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: headerGradient.first.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          headerTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Scrollable body ──
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      // Task title reminder
                      Text(
                        widget.taskTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: VanavilPalette.ink,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Explanation text box (always visible) ──
                      _buildSectionHeader(
                        'Your Explanation',
                        Icons.edit_note_rounded,
                        VanavilPalette.sky,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                VanavilPalette.lavender.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _noteController,
                          maxLines: 4,
                          minLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText:
                                'Tell us what you did and how it went...',
                            hintStyle: TextStyle(color: VanavilPalette.inkSoft),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Picker buttons ──
                      _buildSectionHeader(
                        'Add Proof',
                        Icons.add_circle_outline_rounded,
                        VanavilPalette.leaf,
                      ),
                      const SizedBox(height: 12),
                      _buildPickerButtons(),
                      const SizedBox(height: 20),

                      // ── Voice recorder (mobile only) ──
                      if (!kIsWeb) ...[
                        _buildVoiceRecorder(),
                        const SizedBox(height: 20),
                      ],

                      // ── Selected files ──
                      if (_selectedFiles.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Your Proof (${_selectedFiles.length})',
                          Icons.collections_rounded,
                          VanavilPalette.berry,
                        ),
                        const SizedBox(height: 10),
                        ..._selectedFiles.asMap().entries.map(
                          (entry) => _buildFileCard(entry.key, entry.value),
                        ),
                      ],

                      // ── Error ──
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorCard(_error!),
                      ],
                    ],
                  ),
                ),

                // ── Bottom submit button ──
                _buildSubmitButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Picker buttons ────────────────────────────────────────────────────

  Widget _buildPickerButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PickerCircle(
          label: kIsWeb ? 'Image' : 'Photo',
          icon: kIsWeb ? Icons.image_rounded : Icons.camera_alt_rounded,
          gradient: const [VanavilPalette.berry, VanavilPalette.lavender],
          onTap: _isSubmitting ? null : _pickPhoto,
        ),
        const SizedBox(width: 24),
        _PickerCircle(
          label: 'Video',
          icon: Icons.videocam_rounded,
          gradient: const [VanavilPalette.leaf, Color(0xFF81C784)],
          onTap: _isSubmitting ? null : _pickVideo,
        ),
        const SizedBox(width: 24),
        _PickerCircle(
          label: 'File',
          icon: Icons.attach_file_rounded,
          gradient: const [VanavilPalette.sky, Color(0xFF42A5F5)],
          onTap: _isSubmitting ? null : _pickFiles,
        ),
      ],
    );
  }

  // ── Voice recorder widget (mobile only) ──────────────────────────────

  Widget _buildVoiceRecorder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isRecording
            ? VanavilPalette.coral.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isRecording
              ? VanavilPalette.coral.withValues(alpha: 0.3)
              : VanavilPalette.sun.withValues(alpha: 0.25),
          width: _isRecording ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isSubmitting ? null : _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isRecording
                      ? const [VanavilPalette.coral, Color(0xFFEF5350)]
                      : const [VanavilPalette.sun, Color(0xFFFFB74D)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                            ? VanavilPalette.coral
                            : VanavilPalette.sun)
                        .withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRecording ? 'Recording...' : 'Voice Note',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _isRecording
                        ? VanavilPalette.coral
                        : VanavilPalette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isRecording
                      ? _formatRecordingTime(_recordingDuration)
                      : 'Tap to record (up to 2 min)',
                  style: TextStyle(
                    fontSize: 13,
                    color: _isRecording
                        ? VanavilPalette.coral.withValues(alpha: 0.7)
                        : VanavilPalette.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          if (_isRecording)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: VanavilPalette.coral,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
              onEnd: () {
                if (_isRecording && mounted) setState(() {});
              },
            ),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────

  Widget _buildSectionHeader(String label, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: VanavilPalette.ink,
          ),
        ),
      ],
    );
  }

  // ── File card ─────────────────────────────────────────────────────────

  Widget _buildFileCard(int index, SelectedProofFile file) {
    final isImage = file.contentType.startsWith('image/');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 48,
                height: 48,
                child: isImage && file.bytes != null
                    ? Image.memory(
                        file.bytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fileIconCircle(file),
                      )
                    : _fileIconCircle(file),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: VanavilPalette.ink,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatFileSize(file.sizeBytes),
                    style: const TextStyle(
                      fontSize: 12,
                      color: VanavilPalette.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!_isSubmitting)
              GestureDetector(
                onTap: () => _removeFile(index),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: VanavilPalette.coral.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: VanavilPalette.coral,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fileIconCircle(SelectedProofFile file) {
    final color = _fileColor(file.contentType);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          Icon(iconForContentType(file.contentType), color: color, size: 22),
    );
  }

  static Color _fileColor(String contentType) {
    final ct = contentType.toLowerCase();
    if (ct.startsWith('image/')) return VanavilPalette.berry;
    if (ct.startsWith('video/')) return VanavilPalette.leaf;
    if (ct.startsWith('audio/')) return VanavilPalette.sun;
    if (ct.contains('pdf')) return VanavilPalette.coral;
    return VanavilPalette.sky;
  }

  // ── Error card ────────────────────────────────────────────────────────

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VanavilPalette.coral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: VanavilPalette.coral.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: VanavilPalette.coral,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: VanavilPalette.coral,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit button ─────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    final hasExplanation = _noteController.text.trim().isNotEmpty;
    final canSubmit = hasExplanation && !_isSubmitting && !_isRecording;
    final label = widget.isResubmission ? 'Resubmit Task' : 'Submit Task';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: GestureDetector(
        onTap: canSubmit ? _submit : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: canSubmit
                  ? const [VanavilPalette.leaf, Color(0xFF66BB6A)]
                  : [
                      VanavilPalette.inkSoft.withValues(alpha: 0.2),
                      VanavilPalette.inkSoft.withValues(alpha: 0.15),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: canSubmit
                ? [
                    BoxShadow(
                      color: VanavilPalette.leaf.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSubmitting) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _uploadProgress,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ] else ...[
                Icon(
                  widget.isResubmission
                      ? Icons.refresh_rounded
                      : Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  !hasExplanation ? 'Write an explanation first' : label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Picker circle button
// ---------------------------------------------------------------------------

class _PickerCircle extends StatelessWidget {
  const _PickerCircle({
    required this.label,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: VanavilPalette.ink,
            ),
          ),
        ],
      ),
    );
  }
}
