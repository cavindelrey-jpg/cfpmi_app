// lib/features/school/class_management_page.dart
// Production dynamic class management interface for school administrators.
// Enables creating, editing, reordering, and safely archiving/removing custom classes
// (e.g. Upper C, Lower C, 1A, Technical Year 1, Form 1–5, Lower/Upper Sixth).

import 'package:flutter/material.dart';
import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/school_class.dart';
import '../../repositories/school_class_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/application_shell.dart';
import 'student_roster_page.dart';
import 'timetable_page.dart';

class ClassManagementPage extends StatefulWidget {
  final AppUser user;
  const ClassManagementPage({super.key, required this.user});

  @override
  State<ClassManagementPage> createState() => _ClassManagementPageState();
}

class _ClassManagementPageState extends State<ClassManagementPage> {
  String get _schoolId => widget.user.effectiveSchoolId;

  bool _loading = true;
  List<SchoolClass> _classes = [];
  String _filter = 'all'; // 'all', 'active', 'archived'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _loading = true);
    final list = await SchoolClassRepository.instance.getClasses(_schoolId);
    if (mounted) {
      setState(() {
        _classes = list;
        _loading = false;
      });
    }
  }

  List<SchoolClass> get _filteredClasses {
    return _classes.where((c) {
      if (_filter == 'active' && !c.isActive) return false;
      if (_filter == 'archived' && c.isActive) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = c.name.toLowerCase().contains(q);
        final matchesProg = c.programme?.toLowerCase().contains(q) ?? false;
        final matchesCode = c.code?.toLowerCase().contains(q) ?? false;
        if (!matchesName && !matchesProg && !matchesCode) return false;
      }
      return true;
    }).toList();
  }

  void _showAddClassDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final progCtrl = TextEditingController();
    final yearCtrl = TextEditingController(text: '2025/2026');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final ac = AppColors.of(context);
        return AlertDialog(
          backgroundColor: ac.surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ac.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.school_rounded, color: ac.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Create New Class', style: AppText.title.copyWith(fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter any school-defined class name (e.g. Upper C, Lower C, 1A, Technical Year 1, Form 1).',
                      style: AppText.caption.copyWith(color: ac.muted),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Class Name *',
                        hintText: 'e.g. Upper C, 1A, Form 5, Technical 1',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Class name is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: codeCtrl,
                            decoration: InputDecoration(
                              labelText: 'Short Code (optional)',
                              hintText: 'e.g. UC, 1A',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: yearCtrl,
                            decoration: InputDecoration(
                              labelText: 'Academic Year',
                              hintText: '2025/2026',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: progCtrl,
                      decoration: InputDecoration(
                        labelText: 'Programme / Department (optional)',
                        hintText: 'e.g. Mechanical, Commercial, General',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                        prefixIcon: const Icon(Icons.category_outlined, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: ac.txt2)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ac.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                final name = nameCtrl.text.trim();
                final newClass = SchoolClass(
                  id: 'cls_${DateTime.now().millisecondsSinceEpoch}',
                  schoolId: _schoolId,
                  name: name,
                  code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                  programme: progCtrl.text.trim().isEmpty ? null : progCtrl.text.trim(),
                  academicYear: yearCtrl.text.trim().isEmpty ? null : yearCtrl.text.trim(),
                  displayOrder: _classes.length + 1,
                  isActive: true,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                final res = await SchoolClassRepository.instance.addClass(newClass);
                if (!mounted) return;
                if (res is Success<SchoolClass>) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Class "${newClass.name}" created successfully')),
                  );
                  _loadClasses();
                } else if (res is Failure<SchoolClass>) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res.message), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Create Class'),
            ),
          ],
        );
      },
    );
  }

  void _showEditClassDialog(SchoolClass cls) {
    final nameCtrl = TextEditingController(text: cls.name);
    final codeCtrl = TextEditingController(text: cls.code ?? '');
    final progCtrl = TextEditingController(text: cls.programme ?? '');
    final yearCtrl = TextEditingController(text: cls.academicYear ?? '');
    bool isActive = cls.isActive;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final ac = AppColors.of(context);
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: ac.surf,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ac.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_note_rounded, color: ac.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Edit Class Details', style: AppText.title.copyWith(fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Class Name *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Class name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: codeCtrl,
                              decoration: InputDecoration(
                                labelText: 'Short Code',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: yearCtrl,
                              decoration: InputDecoration(
                                labelText: 'Academic Year',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: progCtrl,
                        decoration: InputDecoration(
                          labelText: 'Programme / Department',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active Class Status'),
                        subtitle: Text(
                          isActive ? 'Visible in rosters & timetables' : 'Archived (hidden from active entries)',
                          style: AppText.caption.copyWith(color: ac.muted),
                        ),
                        value: isActive,
                        activeColor: ac.primary,
                        onChanged: (val) => setDialogState(() => isActive = val),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: ac.txt2)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ac.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(ctx);
                  final updated = cls.copyWith(
                    name: nameCtrl.text.trim(),
                    code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
                    programme: progCtrl.text.trim().isEmpty ? null : progCtrl.text.trim(),
                    academicYear: yearCtrl.text.trim().isEmpty ? null : yearCtrl.text.trim(),
                    isActive: isActive,
                  );
                  await SchoolClassRepository.instance.updateClass(updated);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Class "${updated.name}" updated successfully')),
                  );
                  _loadClasses();
                },
                child: const Text('Save Changes'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSafeRemoveDialog(SchoolClass cls) async {
    final ac = AppColors.of(context);

    // Show checking dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final stats = await SchoolClassRepository.instance.checkClassUsage(_schoolId, cls.name);
    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    showDialog(
      context: context,
      builder: (ctx) {
        final hasRecords = !stats.canSafelyDelete;
        return AlertDialog(
          backgroundColor: ac.surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
          title: Row(
            children: [
              Icon(
                hasRecords ? Icons.warning_amber_rounded : Icons.delete_outline_rounded,
                color: hasRecords ? Colors.amber[700] : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                hasRecords ? 'Protected Academic Records' : 'Remove Class?',
                style: AppText.title.copyWith(fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasRecords) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(Rad.sm),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Class "${cls.name}" cannot be permanently deleted because it has active academic data:',
                          style: AppText.bodySm.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if (stats.studentsCount > 0)
                          Text('• ${stats.studentsCount} student(s) currently enrolled', style: AppText.caption),
                        if (stats.marksCount > 0)
                          Text('• ${stats.marksCount} academic mark record(s)', style: AppText.caption),
                        if (stats.timetableCount > 0)
                          Text('• ${stats.timetableCount} timetable slot(s)', style: AppText.caption),
                        if (stats.homeworkCount > 0)
                          Text('• ${stats.homeworkCount} homework assignment(s)', style: AppText.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Safe Alternative: Archive this class instead. Archiving removes it from daily rosters and mark entry while safely preserving all historical academic records.',
                    style: AppText.bodySm.copyWith(color: ac.muted),
                  ),
                ] else ...[
                  Text(
                    'Are you sure you want to permanently delete "${cls.name}"? This class has no associated students, marks, or timetable records.',
                    style: AppText.bodySm,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: ac.txt2)),
            ),
            if (hasRecords)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                ),
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: const Text('Archive Class Safely'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await SchoolClassRepository.instance.deleteClass(
                    _schoolId,
                    cls.id,
                    cls.name,
                    archiveInstead: true,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Class "${cls.name}" has been archived')),
                  );
                  _loadClasses();
                },
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                ),
                icon: const Icon(Icons.delete_forever, size: 18),
                label: const Text('Delete Class'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final res = await SchoolClassRepository.instance.deleteClass(
                    _schoolId,
                    cls.id,
                    cls.name,
                    archiveInstead: false,
                  );
                  if (!mounted) return;
                  if (res is Success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Class "${cls.name}" removed')),
                    );
                    _loadClasses();
                  } else if (res is Failure<bool>) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res.message), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final displayed = _filteredClasses;

    return ApplicationShell(
      user: widget.user,
      currentDestination: AppNavDestination.schoolConnect,
      breadcrumbs: const [
        ShellBreadcrumb(label: 'School Connect'),
        ShellBreadcrumb(label: 'Class Management'),
      ],
      headerActions: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: ac.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Class'),
          onPressed: _showAddClassDialog,
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadClasses,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Overview Stats Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: ac.surf,
                      borderRadius: BorderRadius.circular(Rad.md),
                      border: Border.all(color: ac.bdr),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _summaryMetric(
                          ac,
                          'Total Classes',
                          '${_classes.length}',
                          Icons.meeting_room_outlined,
                          ac.primary,
                        ),
                        Container(width: 1, height: 36, color: ac.bdr),
                        _summaryMetric(
                          ac,
                          'Active Classes',
                          '${_classes.where((c) => c.isActive).length}',
                          Icons.check_circle_outline_rounded,
                          Colors.green,
                        ),
                        Container(width: 1, height: 36, color: ac.bdr),
                        _summaryMetric(
                          ac,
                          'Archived Classes',
                          '${_classes.where((c) => !c.isActive).length}',
                          Icons.archive_outlined,
                          Colors.amber,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filter & Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search classes, technical programmes…',
                            prefixIcon: Icon(Icons.search, size: 20, color: ac.muted),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: ac.surf,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'all', label: Text('All')),
                          ButtonSegment(value: 'active', label: Text('Active')),
                          ButtonSegment(value: 'archived', label: Text('Archived')),
                        ],
                        selected: {_filter},
                        onSelectionChanged: (val) => setState(() => _filter = val.first),
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Class Cards List
                  if (displayed.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ac.surf,
                        borderRadius: BorderRadius.circular(Rad.md),
                        border: Border.all(color: ac.bdr),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.meeting_room_outlined, size: 48, color: ac.muted),
                          const SizedBox(height: 12),
                          Text('No classes match your filter', style: AppText.title.copyWith(fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(
                            'Add custom classes or adjust your search filter.',
                            style: AppText.caption.copyWith(color: ac.muted),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final cls in displayed)
                      _buildClassCard(ac, cls),
                ],
              ),
            ),
    );
  }

  Widget _summaryMetric(
    AppColors ac,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppText.title.copyWith(fontSize: 18, color: ac.txt)),
            Text(label, style: AppText.caption.copyWith(color: ac.muted)),
          ],
        ),
      ],
    );
  }

  Widget _buildClassCard(AppColors ac, SchoolClass cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: cls.isActive ? ac.bdr : Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cls.isActive
                  ? ac.primary.withValues(alpha: 0.12)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.class_rounded,
              size: 24,
              color: cls.isActive ? ac.primary : ac.muted,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      cls.name,
                      style: AppText.title.copyWith(
                        fontSize: 16,
                        color: cls.isActive ? ac.txt : ac.muted,
                      ),
                    ),
                    if (cls.code != null && cls.code!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ac.surf2,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: ac.bdr),
                        ),
                        child: Text(
                          cls.code!,
                          style: AppText.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: ac.txt2,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cls.isActive
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cls.isActive ? 'Active' : 'Archived',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cls.isActive ? Colors.green[700] : Colors.amber[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (cls.programme != null && cls.programme!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category_outlined, size: 14, color: ac.muted),
                          const SizedBox(width: 4),
                          Text(cls.programme!, style: AppText.caption.copyWith(color: ac.muted)),
                        ],
                      ),
                    if (cls.academicYear != null && cls.academicYear!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: ac.muted),
                          const SizedBox(width: 4),
                          Text(cls.academicYear!, style: AppText.caption.copyWith(color: ac.muted)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Action Buttons
          Wrap(
            spacing: 6,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                ),
                icon: const Icon(Icons.people_alt_outlined, size: 16),
                label: const Text('Students', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    settings: RouteSettings(name: '/school/classes/${cls.id}/students'),
                    builder: (_) => StudentRosterPage(
                      user: widget.user,
                      initialClass: cls.name,
                    ),
                  ));
                },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.sm)),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 16),
                label: const Text('Timetable', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    settings: RouteSettings(name: '/school/classes/${cls.id}/timetable'),
                    builder: (_) => TimetablePage(
                      user: widget.user,
                      initialClass: cls.name,
                    ),
                  ));
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit Class',
                onPressed: () => _showEditClassDialog(cls),
              ),
              IconButton(
                icon: Icon(
                  cls.isActive ? Icons.archive_outlined : Icons.delete_outline,
                  size: 18,
                  color: cls.isActive ? Colors.amber[800] : Colors.red,
                ),
                tooltip: cls.isActive ? 'Archive / Delete Class' : 'Delete Class',
                onPressed: () => _showSafeRemoveDialog(cls),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
