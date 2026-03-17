import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/core/utils/validators.dart';
import 'package:squadsync/features/roster/data/csv_mapper.dart';
import 'package:squadsync/features/roster/providers/add_player_provider.dart';

class AddPlayerScreen extends ConsumerStatefulWidget {
  const AddPlayerScreen({super.key, this.teamId});

  final String? teamId;

  @override
  ConsumerState<AddPlayerScreen> createState() => _AddPlayerScreenState();
}

class _AddPlayerScreenState extends ConsumerState<AddPlayerScreen> {
  // ── Tab 1: Add manually ───────────────────────────────────────
  final _manualFormKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _jerseyCtrl = TextEditingController();

  // ── Tab 2: Send invite ────────────────────────────────────────
  final _inviteFormKey = GlobalKey<FormState>();
  final _inviteEmailCtrl = TextEditingController();
  final _inviteNameCtrl = TextEditingController();
  bool _inviteSent = false;
  String? _lastInvitedEmail;

  // ── Tab 3: CSV import wizard ──────────────────────────────────
  final _csvPageCtrl = PageController();
  int _csvStep = 0;

  // Step 0 – Upload
  String? _csvFileName;
  List<String> _csvHeaders = [];
  List<List<dynamic>> _csvDataRows = [];

  // Step 1 – Map columns
  List<ColumnMapping> _columnMappings = [];

  // Step 2 – Preview (derived)
  List<PlayerImportRow> _validRows = [];
  List<SkippedRow> _skippedRows = [];

  // Step 3 – Results
  int _importProgress = 0;
  int _importTotal = 0;
  ImportResult? _importResult;
  bool _isImporting = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _positionCtrl.dispose();
    _jerseyCtrl.dispose();
    _inviteEmailCtrl.dispose();
    _inviteNameCtrl.dispose();
    _csvPageCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────

  String? _notEmpty(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _csvGoTo(int step) {
    setState(() => _csvStep = step);
    _csvPageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // ── Tab 1 actions ─────────────────────────────────────────────

  Future<void> _handleManualAdd() async {
    if (!_manualFormKey.currentState!.validate()) return;
    final teamId = widget.teamId;
    if (teamId == null) return;

    try {
      await ref.read(addPlayerNotifierProvider.notifier).addManually(
            teamId: teamId,
            fullName: _fullNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim().isEmpty
                ? null
                : _phoneCtrl.text.trim(),
            position: _positionCtrl.text.trim().isEmpty
                ? null
                : _positionCtrl.text.trim(),
            jerseyNumber: int.tryParse(_jerseyCtrl.text.trim()),
          );
      if (!mounted) return;
      _showSnackBar('Player added!');
      _manualFormKey.currentState!.reset();
      _fullNameCtrl.clear();
      _emailCtrl.clear();
      _phoneCtrl.clear();
      _positionCtrl.clear();
      _jerseyCtrl.clear();
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  // ── Tab 2 actions ─────────────────────────────────────────────

  Future<void> _handleSendInvite() async {
    if (!_inviteFormKey.currentState!.validate()) return;
    final teamId = widget.teamId;
    if (teamId == null) return;

    final email = _inviteEmailCtrl.text.trim();
    try {
      await ref.read(addPlayerNotifierProvider.notifier).sendInvite(
            teamId: teamId,
            email: email,
            fullName: _inviteNameCtrl.text.trim().isEmpty
                ? null
                : _inviteNameCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _inviteSent = true;
        _lastInvitedEmail = email;
      });
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  void _resetInviteTab() {
    setState(() {
      _inviteSent = false;
      _lastInvitedEmail = null;
    });
    _inviteEmailCtrl.clear();
    _inviteNameCtrl.clear();
  }

  // ── Tab 3 actions ─────────────────────────────────────────────

  Future<void> _pickCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) {
      _showSnackBar('Could not read file — please try again.');
      return;
    }
    _parseCsv(file.bytes!, file.name);
  }

  void _parseCsv(Uint8List bytes, String fileName) {
    try {
      final raw = utf8.decode(bytes);
      final normalized =
          raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      final rows =
          const CsvToListConverter().convert(normalized, eol: '\n');

      if (rows.isEmpty) {
        _showSnackBar('CSV file is empty.');
        return;
      }

      final headers =
          rows.first.map((h) => h.toString().trim()).toList();
      final dataRows = rows
          .skip(1)
          .where((r) => r.any((c) => c.toString().isNotEmpty))
          .toList();

      final mappings = headers
          .map((h) => ColumnMapping(
                originalHeader: h,
                mappedField: CsvMapper.matchColumn(h),
              ))
          .toList();

      setState(() {
        _csvFileName = fileName;
        _csvHeaders = headers;
        _csvDataRows = dataRows;
        _columnMappings = mappings;
      });
      _recomputePreviewRows();
    } catch (_) {
      _showSnackBar('Failed to parse CSV — check the file format.');
    }
  }

  void _recomputePreviewRows() {
    final valid = <PlayerImportRow>[];
    final skipped = <SkippedRow>[];

    for (int i = 0; i < _csvDataRows.length; i++) {
      final row = <String, dynamic>{};
      for (int j = 0;
          j < _csvHeaders.length && j < _csvDataRows[i].length;
          j++) {
        row[_csvHeaders[j]] = _csvDataRows[i][j];
      }

      final player =
          CsvMapper.validateAndTransformRow(row, _columnMappings);
      if (player != null) {
        valid.add(player);
      } else {
        final emailHeader = _columnMappings
            .where((m) => m.mappedField == SquadSyncField.email)
            .map((m) => m.originalHeader)
            .firstOrNull;
        skipped.add(SkippedRow(
          rowNumber: i + 2,
          email: emailHeader != null
              ? row[emailHeader]?.toString()
              : null,
          reason: 'Missing or invalid email',
        ));
      }
    }

    setState(() {
      _validRows = valid;
      _skippedRows = skipped;
    });
  }

  Future<void> _downloadTemplate() async {
    const content =
        'first_name,last_name,email,phone,position,jersey_number,date_of_birth\n'
        'John,Smith,john.smith@example.com,0400000000,Forward,10,1995-06-15\n';
    final bytes = Uint8List.fromList(utf8.encode(content));
    final file = XFile.fromData(
      bytes,
      mimeType: 'text/csv',
      name: 'squadsync_player_template.csv',
    );
    await Share.shareXFiles(
      [file],
      subject: 'SquadSync Player Import Template',
    );
  }

  Future<void> _startImport() async {
    final teamId = widget.teamId;
    if (teamId == null || _validRows.isEmpty) return;

    setState(() {
      _isImporting = true;
      _importProgress = 0;
      _importTotal = _validRows.length;
      _importResult = null;
    });
    _csvGoTo(3);

    try {
      final result = await ref
          .read(addPlayerNotifierProvider.notifier)
          .importPlayers(
            teamId: teamId,
            players: _validRows,
            onProgress: (current, total) {
              if (mounted) {
                setState(() {
                  _importProgress = current;
                  _importTotal = total;
                });
              }
            },
          );
      if (!mounted) return;
      setState(() {
        _importResult = result;
        _isImporting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      _showSnackBar('Import failed: $e');
    }
  }

  void _resetCsvWizard() {
    setState(() {
      _csvFileName = null;
      _csvHeaders = [];
      _csvDataRows = [];
      _columnMappings = [];
      _validRows = [];
      _skippedRows = [];
      _importProgress = 0;
      _importTotal = 0;
      _importResult = null;
      _isImporting = false;
      _csvStep = 0;
    });
    _csvPageCtrl.jumpToPage(0);
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(addPlayerNotifierProvider).isLoading;

    if (widget.teamId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Player')),
        body: const Center(
          child: Text('No team selected — go back and select a team.'),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Player'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Manually'),
              Tab(text: 'Invite'),
              Tab(text: 'Import CSV'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildManualTab(isLoading),
            _buildInviteTab(isLoading),
            _buildCsvTab(),
          ],
        ),
      ),
    );
  }

  // ── Tab 1 ─────────────────────────────────────────────────────

  Widget _buildManualTab(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _manualFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            TextFormField(
              controller: _fullNameCtrl,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              enabled: !isLoading,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => _notEmpty(v, 'Full name') ??
                  (v!.trim().length < 2
                      ? 'Name must be at least 2 characters'
                      : null),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.phone,
              enabled: !isLoading,
              decoration:
                  const InputDecoration(labelText: 'Phone (optional)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _positionCtrl,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              enabled: !isLoading,
              decoration:
                  const InputDecoration(labelText: 'Position (optional)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _jerseyCtrl,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.number,
              enabled: !isLoading,
              decoration: const InputDecoration(
                  labelText: 'Jersey number (optional)'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (int.tryParse(v.trim()) == null) {
                  return 'Must be a number';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleManualAdd(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: isLoading ? null : _handleManualAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Player'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 2 ─────────────────────────────────────────────────────

  Widget _buildInviteTab(bool isLoading) {
    if (_inviteSent) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Invite sent!',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _lastInvitedEmail ?? '',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: _resetInviteTab,
                child: const Text('Invite another'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _inviteFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Send a magic-link invitation. The player can sign in '
              'and see their team immediately.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _inviteEmailCtrl,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              enabled: !isLoading,
              decoration:
                  const InputDecoration(labelText: 'Email address'),
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _inviteNameCtrl,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              enabled: !isLoading,
              decoration:
                  const InputDecoration(labelText: 'Name (optional)'),
              onFieldSubmitted: (_) => _handleSendInvite(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: isLoading ? null : _handleSendInvite,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 3 — CSV wizard ────────────────────────────────────────

  Widget _buildCsvTab() {
    return Column(
      children: [
        _buildStepIndicator(),
        Expanded(
          child: PageView(
            controller: _csvPageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildCsvStep0Upload(),
              _buildCsvStep1Map(),
              _buildCsvStep2Preview(),
              _buildCsvStep3Results(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _csvStep
                      ? AppColors.primary
                      : Colors.grey[300],
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            'Step ${_csvStep + 1} of 4',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // Step 0 — Upload
  Widget _buildCsvStep0Upload() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drop zone
          GestureDetector(
            onTap: _pickCsvFile,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.grey[400]!, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: _csvFileName == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text('Tap to select a CSV file',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          '.csv or .txt files only',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            size: 40, color: Colors.green[600]),
                        const SizedBox(height: 12),
                        Text(
                          _csvFileName!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_csvDataRows.length} row${_csvDataRows.length != 1 ? "s" : ""} '
                          '· ${_csvHeaders.length} column${_csvHeaders.length != 1 ? "s" : ""}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _pickCsvFile,
                          child: const Text('Change file'),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _downloadTemplate,
            icon: const Icon(Icons.download),
            label: const Text('Download template'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _csvFileName == null
                ? null
                : () => _csvGoTo(1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  // Step 1 — Map columns
  Widget _buildCsvStep1Map() {
    final emailMapped = _columnMappings
        .any((m) => m.mappedField == SquadSyncField.email);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Match your columns',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                "We've matched what we can — review and adjust below.",
                style:
                    TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              // Email required indicator
              Row(
                children: [
                  Icon(
                    emailMapped
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 16,
                    color: emailMapped ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    emailMapped ? 'email ✓' : 'email required',
                    style: TextStyle(
                      fontSize: 13,
                      color: emailMapped ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            itemCount: _columnMappings.length,
            separatorBuilder: (_, _) => const Divider(height: 16),
            itemBuilder: (_, i) {
              final mapping = _columnMappings[i];
              final autoMatched =
                  mapping.mappedField != SquadSyncField.ignore;
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      mapping.originalHeader,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  DropdownButton<SquadSyncField>(
                    value: mapping.mappedField,
                    underline: const SizedBox.shrink(),
                    items: SquadSyncField.values
                        .map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(f.displayName,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (field) {
                      if (field == null) return;
                      setState(() {
                        _columnMappings[i] =
                            mapping.copyWith(mappedField: field);
                      });
                      _recomputePreviewRows();
                    },
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    autoMatched
                        ? Icons.check_circle
                        : Icons.warning_amber,
                    size: 18,
                    color: autoMatched
                        ? Colors.green
                        : Colors.amber[700],
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () => _csvGoTo(0),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: emailMapped ? () => _csvGoTo(2) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 2 — Preview
  Widget _buildCsvStep2Preview() {
    final previewRows = _validRows.take(5).toList();
    final mappedFields = _columnMappings
        .where((m) => m.mappedField != SquadSyncField.ignore)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Review before importing',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        // Data table (horizontal scroll)
        if (previewRows.isNotEmpty && mappedFields.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                    AppColors.primary.withValues(alpha: 0.08)),
                columns: mappedFields
                    .map((m) => DataColumn(
                          label: Text(m.mappedField.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ))
                    .toList(),
                rows: previewRows.map((player) {
                  return DataRow(
                    cells: mappedFields.map((m) {
                      String v = '';
                      switch (m.mappedField) {
                        case SquadSyncField.firstName:
                          v = player.firstName ?? '';
                        case SquadSyncField.lastName:
                          v = player.lastName ?? '';
                        case SquadSyncField.email:
                          v = player.email;
                        case SquadSyncField.phone:
                          v = player.phone ?? '';
                        case SquadSyncField.position:
                          v = player.position ?? '';
                        case SquadSyncField.jerseyNumber:
                          v = player.jerseyNumber?.toString() ?? '';
                        case SquadSyncField.dateOfBirth:
                          v = player.dateOfBirth ?? '';
                        case SquadSyncField.ignore:
                          v = '';
                      }
                      return DataCell(Text(v,
                          style: const TextStyle(fontSize: 12)));
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_validRows.length} row${_validRows.length != 1 ? "s" : ""} ready to import',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (_skippedRows.isNotEmpty)
                Text(
                  '${_skippedRows.length} row${_skippedRows.length != 1 ? "s" : ""} will be skipped',
                  style: const TextStyle(color: Colors.orange),
                ),
            ],
          ),
        ),
        if (_skippedRows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'See skipped rows (${_skippedRows.length})',
                style: const TextStyle(fontSize: 13),
              ),
              children: _skippedRows
                  .map((r) => ListTile(
                        dense: true,
                        title: Text(r.email ?? 'Row ${r.rowNumber}',
                            style: const TextStyle(fontSize: 12)),
                        subtitle: Text(r.reason,
                            style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: () => _csvGoTo(1),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _validRows.isEmpty ? null : _startImport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    'Import ${_validRows.length} player${_validRows.length != 1 ? "s" : ""}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Step 3 — Results
  Widget _buildCsvStep3Results() {
    if (_isImporting) {
      final progress = _importTotal > 0
          ? _importProgress / _importTotal
          : 0.0;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: progress,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Importing... $_importProgress of $_importTotal',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final result = _importResult;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle,
              color: Colors.green, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Import complete!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // Result cards
          _buildResultCard(
              '${result.linkedCount} linked',
              'Existing accounts added to team',
              Colors.blue[100]!,
              Colors.blue[800]!),
          const SizedBox(height: 8),
          _buildResultCard(
              '${result.invitedCount} invited',
              'New players — invite email sent',
              Colors.amber[100]!,
              Colors.amber[900]!),
          const SizedBox(height: 8),
          _buildResultCard(
              '${result.skippedCount} skipped',
              'Already a member or invalid row',
              Colors.grey[200]!,
              Colors.grey[700]!),
          if (result.skippedRows.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpansionTile(
              title: Text(
                '${result.skippedRows.length} rows had errors',
                style: const TextStyle(fontSize: 13),
              ),
              children: result.skippedRows
                  .map((r) => ListTile(
                        dense: true,
                        title: Text(r.email ?? 'Row ${r.rowNumber}',
                            style: const TextStyle(fontSize: 12)),
                        subtitle: Text(r.reason,
                            style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('View roster'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _resetCsvWizard,
            child: const Text('Import another'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
    String count,
    String label,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(count,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: fg)),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(fontSize: 13, color: fg)),
        ],
      ),
    );
  }
}
