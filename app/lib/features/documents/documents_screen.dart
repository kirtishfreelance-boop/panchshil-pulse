import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/document.dart';
import '../../providers/amenity_provider.dart';
import '../../providers/async_value.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _searchController = TextEditingController();
  List<PulseDocument>? _searchResults;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AmenityProvider>().loadFolders(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String term) async {
    if (term.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await context.read<AmenityProvider>().documents(search: term);
      if (mounted) setState(() => _searchResults = results);
    } on ApiException catch (e) {
      if (mounted) showPulseSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AmenityProvider>();
    final state = provider.folders;

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              onChanged: (v) {
                if (v.trim().isEmpty) setState(() => _searchResults = null);
              },
              decoration: InputDecoration(
                hintText: 'Search documents…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = null);
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _searching
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CardListSkeleton(count: 3, height: 72),
                  )
                : _searchResults != null
                    ? _DocumentList(documents: _searchResults!)
                    : _buildFolders(provider, state),
          ),
        ],
      ),
    );
  }

  Widget _buildFolders(
    AmenityProvider provider,
    AsyncValue<List<DocumentFolder>> state,
  ) {
    if (state.isLoading && !state.hasData) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: CardListSkeleton(count: 4, height: 84),
      );
    }
    if (state.hasError && !state.hasData) {
      return ErrorView(message: state.error!, onRetry: provider.loadFolders);
    }

    final folders = state.data ?? const <DocumentFolder>[];
    if (folders.isEmpty) {
      return const EmptyState(
        title: 'No documents yet',
        message: 'Handbooks, forms and certificates will appear here.',
        icon: Icons.folder_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadFolders,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        itemCount: folders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _FolderTile(folder: folders[i]),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder});

  final DocumentFolder folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _FolderScreen(folder: folder)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.folder_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(folder.name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    '${folder.documentCount} '
                    '${folder.documentCount == 1 ? 'file' : 'files'} · ${folder.sizeLabel}'
                    '${folder.lastUpdated != null ? ' · ${relativeTime(folder.lastUpdated)}' : ''}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _FolderScreen extends StatefulWidget {
  const _FolderScreen({required this.folder});

  final DocumentFolder folder;

  @override
  State<_FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<_FolderScreen> {
  List<PulseDocument>? _documents;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docs = await context
          .read<AmenityProvider>()
          .documents(folderId: widget.folder.id);
      if (mounted) setState(() => _documents = docs);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder.name)),
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _documents == null
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: CardListSkeleton(count: 4, height: 72),
                )
              : _DocumentList(documents: _documents!),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.documents});

  final List<PulseDocument> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const EmptyState(
        title: 'Nothing here',
        message: 'No documents match.',
        icon: Icons.description_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      itemCount: documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _DocumentTile(document: documents[i]),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.document});

  final PulseDocument document;

  static const _tints = {
    'PDF': AppColors.danger,
    'DOC': AppColors.primary,
    'XLS': AppColors.success,
    'IMG': AppColors.accent,
  };

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(document.fileUrl);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        showPulseSnack(context, 'Could not open this file.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = (document.fileType ?? 'OTHER').toUpperCase();
    final tint = _tints[type] ?? AppColors.lightTextSecondary;

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                type == 'OTHER' ? 'FILE' : type,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: tint),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (document.description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      document.description!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${document.sizeLabel}'
                    '${document.updatedAt != null ? ' · updated ${relativeTime(document.updatedAt)}' : ''}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
