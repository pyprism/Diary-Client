import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/content_utils.dart';
import '../../../core/utils/date_utils.dart' as du;
import '../../../features/image_upload/data/image_upload_repository.dart';
import '../../../features/tags/presentation/tags_providers.dart';
import 'diary_content_quill_codec.dart';
import 'diary_providers.dart';

class DiaryEditorScreen extends ConsumerStatefulWidget {
  final int? localId;

  const DiaryEditorScreen({super.key, this.localId});

  @override
  ConsumerState<DiaryEditorScreen> createState() => _DiaryEditorScreenState();
}

class _DiaryEditorScreenState extends ConsumerState<DiaryEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _editorFocusNode = FocusNode();

  late quill.QuillController _quillCtrl;

  DateTime _selectedDate = DateTime.now();
  PostType _postType = PostType.short;
  Set<String> _selectedTags = {};
  int _wordCount = 0;

  bool _loading = false;
  bool _initialized = false;

  String _initialTitle = '';
  String _initialDelta = '';
  late DateTime _initialDate;
  late PostType _initialPostType;
  Set<String> _initialTags = {};

  @override
  void initState() {
    super.initState();
    _quillCtrl = quill.QuillController.basic();
    _quillCtrl.addListener(_syncPostTypeFromContent);
    _initialDate =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _initialPostType = _postType;
    _syncPostTypeFromContent(notify: false);
    _captureInitialState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && widget.localId != null) {
      _loadEntry();
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _editorFocusNode.dispose();
    _quillCtrl.removeListener(_syncPostTypeFromContent);
    _quillCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    final entry =
        await ref.read(diaryRepositoryProvider).getById(widget.localId!);
    if (entry == null || !mounted) return;

    final nextController = quill.QuillController(
      document: DiaryContentQuillCodec.blocksToDocument(entry.content.blocks),
      selection: const TextSelection.collapsed(offset: 0),
    );
    nextController.addListener(_syncPostTypeFromContent);
    final nextWordCount = _countWords(nextController.document.toPlainText());

    setState(() {
      _quillCtrl.removeListener(_syncPostTypeFromContent);
      _quillCtrl.dispose();
      _quillCtrl = nextController;
      _titleCtrl.text = entry.title;
      _selectedDate = du.DateUtils.fromApiFormat(entry.date) ?? DateTime.now();
      _wordCount = nextWordCount;
      _postType = _postTypeForWordCount(nextWordCount);
      _selectedTags = entry.tags.map((t) => t.name).toSet();
      _captureInitialState();
    });
  }

  void _syncPostTypeFromContent({bool notify = true}) {
    final count = _countWords(_quillCtrl.document.toPlainText());
    final nextType = _postTypeForWordCount(count);

    if (_wordCount == count && _postType == nextType) return;
    if (!notify || !mounted) {
      _wordCount = count;
      _postType = nextType;
      return;
    }

    setState(() {
      _wordCount = count;
      _postType = nextType;
    });
  }

  PostType _postTypeForWordCount(int wordCount) {
    return wordCount > 80 ? PostType.long : PostType.short;
  }

  int _countWords(String text) {
    return RegExp(r"[\p{L}\p{N}']+", unicode: true).allMatches(text).length;
  }

  void _captureInitialState() {
    _initialTitle = _titleCtrl.text.trim();
    _initialDelta = jsonEncode(_quillCtrl.document.toDelta().toJson());
    _initialDate =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _initialPostType = _postType;
    _initialTags = {..._selectedTags};
  }

  bool _hasUnsavedChanges() {
    final currentDate =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final currentDelta = jsonEncode(_quillCtrl.document.toDelta().toJson());

    return _initialTitle != _titleCtrl.text.trim() ||
        _initialDelta != currentDelta ||
        _initialDate != currentDate ||
        _initialPostType != _postType ||
        _initialTags.length != _selectedTags.length ||
        !_initialTags.containsAll(_selectedTags);
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasUnsavedChanges()) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes in this entry.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return discard == true;
  }

  Future<void> _handleBack() async {
    final canLeave = await _confirmDiscardChanges();
    if (!canLeave || !mounted) return;

    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/diary');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(imageUploadRepositoryProvider);
      final url = await repo.uploadImage(file);
      _insertImage(url);
    } catch (_) {
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? 'image/jpeg';
      final localUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      _insertImage(localUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image saved locally and will upload during sync.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _insertImage(String url) {
    final selection = _quillCtrl.selection;
    final index = selection.baseOffset < 0
        ? _quillCtrl.document.length - 1
        : selection.baseOffset;
    _quillCtrl.replaceText(index, 0, quill.BlockEmbed.image(url), null);
    _quillCtrl.replaceText(index + 1, 0, '\n', null);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty')),
      );
      return;
    }

    final blocks = DiaryContentQuillCodec.documentToBlocks(_quillCtrl.document);
    if (blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some content before saving')),
      );
      return;
    }
    final content = DiaryContent(blocks: blocks);
    final postType = _postTypeForWordCount(_wordCount);
    if (_postType != postType) {
      setState(() => _postType = postType);
    }
    final validationError = content.validateForApi(allowLocalImages: true);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.localId == null) {
        final entry = await ref.read(diaryRepositoryProvider).createDiary(
              title: title,
              date: du.DateUtils.toApiFormat(_selectedDate),
              postType: postType,
              content: content,
              tagNames: _selectedTags.toList(),
            );

        if (mounted) {
          context.pushReplacement('/diary/${entry.localId}');
        }
      } else {
        await ref.read(diaryRepositoryProvider).updateDiary(
              localId: widget.localId!,
              title: title,
              date: du.DateUtils.toApiFormat(_selectedDate),
              postType: postType,
              content: content,
              tagNames: _selectedTags.toList(),
            );

        _captureInitialState();
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/diary');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider);
    final isEdit = widget.localId != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leadingWidth: 56,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
            tooltip: 'Back',
          ),
          title: Text(isEdit ? 'Edit Entry' : 'New Entry'),
          actions: _loading
              ? const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ]
              : const [],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(isEdit ? 'Save Changes' : 'Create Entry'),
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 700;
            final isDesktop = constraints.maxWidth >= 920;
            final maxWidth =
                constraints.maxWidth > 1180 ? 1180.0 : double.infinity;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 16 : 24,
                    20,
                    isCompact ? 16 : 24,
                    96,
                  ),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _WritingPanel(
                                titleCtrl: _titleCtrl,
                                quillCtrl: _quillCtrl,
                                editorFocusNode: _editorFocusNode,
                                toolbarConfig: _toolbarConfig(false),
                                minEditorHeight: 520,
                              ),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: 320,
                              child: _MetadataPanel(
                                selectedDate: _selectedDate,
                                postType: _postType,
                                wordCount: _wordCount,
                                tags: tags,
                                selectedTags: _selectedTags,
                                onPickDate: _pickDate,
                                onTagSelected: _setTagSelected,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _WritingPanel(
                              titleCtrl: _titleCtrl,
                              quillCtrl: _quillCtrl,
                              editorFocusNode: _editorFocusNode,
                              toolbarConfig: _toolbarConfig(isCompact),
                              minEditorHeight: isCompact ? 360 : 460,
                            ),
                            const SizedBox(height: 16),
                            _MetadataPanel(
                              selectedDate: _selectedDate,
                              postType: _postType,
                              wordCount: _wordCount,
                              tags: tags,
                              selectedTags: _selectedTags,
                              onPickDate: _pickDate,
                              onTagSelected: _setTagSelected,
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _setTagSelected(String tagName, bool selected) {
    setState(() {
      if (selected) {
        _selectedTags.add(tagName);
      } else {
        _selectedTags.remove(tagName);
      }
    });
  }

  quill.QuillSimpleToolbarConfig _toolbarConfig(bool isCompact) {
    return quill.QuillSimpleToolbarConfig(
      showSearchButton: false,
      showSubscript: false,
      showSuperscript: false,
      showCodeBlock: false,
      showFontFamily: !isCompact,
      showFontSize: !isCompact,
      showUnderLineButton: !isCompact,
      showStrikeThrough: !isCompact,
      showInlineCode: !isCompact,
      showColorButton: !isCompact,
      showBackgroundColorButton: !isCompact,
      showIndent: !isCompact,
      showAlignmentButtons: !isCompact,
      customButtons: [
        quill.QuillToolbarCustomButtonOptions(
          icon: const Icon(Icons.image_outlined, size: 18),
          tooltip: 'Upload image',
          onPressed: _pickAndUploadImage,
        ),
      ],
    );
  }
}

class _WritingPanel extends StatelessWidget {
  final TextEditingController titleCtrl;
  final quill.QuillController quillCtrl;
  final FocusNode editorFocusNode;
  final quill.QuillSimpleToolbarConfig toolbarConfig;
  final double minEditorHeight;

  const _WritingPanel({
    required this.titleCtrl,
    required this.quillCtrl,
    required this.editorFocusNode,
    required this.toolbarConfig,
    required this.minEditorHeight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: titleCtrl,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'Entry title...',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: quill.QuillSimpleToolbar(
                  controller: quillCtrl,
                  config: toolbarConfig,
                ),
              ),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.25)),
              Container(
                constraints: BoxConstraints(minHeight: minEditorHeight),
                padding: const EdgeInsets.all(16),
                child: quill.QuillEditor.basic(
                  controller: quillCtrl,
                  focusNode: editorFocusNode,
                  config: quill.QuillEditorConfig(
                    placeholder: 'Write your diary entry...',
                    embedBuilders: [_DiaryImageEmbedBuilder()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiaryImageEmbedBuilder extends quill.EmbedBuilder {
  const _DiaryImageEmbedBuilder();

  @override
  String get key => quill.BlockEmbed.imageType;

  @override
  bool get expanded => false;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final source = embedContext.node.value.data.toString();
    final image = _buildImage(context, source);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: image,
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String source) {
    if (source.startsWith('data:image/')) {
      final bytes = _decodeDataUrl(source);
      if (bytes != null) {
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _brokenImage(context),
        );
      }
    }

    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Consumer(
        builder: (context, ref, _) {
          final signedUrl = ref.watch(signedImageUrlProvider(source));
          return signedUrl.when(
            data: (displayUrl) => Image.network(
              displayUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _imagePlaceholder(context);
              },
              errorBuilder: (_, __, ___) => _brokenImage(context),
            ),
            loading: () => _imagePlaceholder(context),
            error: (_, __) => _brokenImage(context),
          );
        },
      );
    }

    return _brokenImage(context);
  }

  Uint8List? _decodeDataUrl(String source) {
    final match = RegExp(r'^data:image/[^;]+;base64,(.+)$').firstMatch(source);
    if (match == null) return null;

    try {
      return base64Decode(match.group(1)!);
    } on FormatException {
      return null;
    }
  }

  Widget _imagePlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest),
      child: const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _brokenImage(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest),
      child: SizedBox(
        height: 180,
        child: Icon(
          Icons.broken_image_outlined,
          color: cs.onSurfaceVariant,
          size: 36,
        ),
      ),
    );
  }
}

class _MetadataPanel extends StatelessWidget {
  final DateTime selectedDate;
  final PostType postType;
  final int wordCount;
  final AsyncValue<List<Tag>> tags;
  final Set<String> selectedTags;
  final VoidCallback onPickDate;
  final void Function(String tagName, bool selected) onTagSelected;

  const _MetadataPanel({
    required this.selectedDate,
    required this.postType,
    required this.wordCount,
    required this.tags,
    required this.selectedTags,
    required this.onPickDate,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Entry Details',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(du.DateUtils.toApiFormat(selectedDate)),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 14),
            IgnorePointer(
              child: SegmentedButton<PostType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: PostType.short, label: Text('Short')),
                  ButtonSegment(value: PostType.long, label: Text('Long')),
                ],
                selected: {postType},
                onSelectionChanged: (_) {},
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$wordCount words',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
            ),
            const SizedBox(height: 18),
            Text('Tags', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            tags.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(
                'Unable to load tags',
                style: TextStyle(color: cs.error),
              ),
              data: (tagList) {
                if (tagList.isEmpty) {
                  return Text(
                    'No tags yet',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.62),
                    ),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tagList
                      .map(
                        (tag) => FilterChip(
                          label: Text(tag.name),
                          selected: selectedTags.contains(tag.name),
                          onSelected: (selected) =>
                              onTagSelected(tag.name, selected),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
