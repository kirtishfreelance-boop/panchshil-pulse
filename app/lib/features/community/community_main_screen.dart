import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/pulse_widgets.dart';
import '../../models/community.dart';
import '../../models/post.dart';
import '../../providers/community_provider.dart';

/// Feed + community directory. Two tabs: what people are saying, and the groups
/// you can join.
class CommunityMainScreen extends StatefulWidget {
  const CommunityMainScreen({super.key});

  @override
  State<CommunityMainScreen> createState() => _CommunityMainScreenState();
}

class _CommunityMainScreenState extends State<CommunityMainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<CommunityProvider>().loadAll(),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _compose() async {
    final body = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ComposeSheet(),
    );
    if (body == null || body.trim().isEmpty || !mounted) return;
    try {
      await context.read<CommunityProvider>().createPost(body: body.trim());
      if (mounted) showPulseSnack(context, 'Posted to the feed.');
    } on ApiException catch (e) {
      if (mounted) showPulseSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'Feed'), Tab(text: 'Groups')],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _compose,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit_rounded),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FeedTab(provider: provider),
          _GroupsTab(provider: provider),
        ],
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({required this.provider});

  final CommunityProvider provider;

  @override
  Widget build(BuildContext context) {
    final state = provider.feed;

    if (state.isLoading && !state.hasData) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: CardListSkeleton(count: 3, height: 150),
      );
    }
    if (state.hasError && !state.hasData) {
      return ErrorView(
        message: state.error!,
        onRetry: () => provider.loadFeed(refresh: true),
      );
    }

    final posts = state.data ?? const <Post>[];
    if (posts.isEmpty) {
      return const EmptyState(
        title: 'The feed is quiet',
        message: 'Be the first to say something to your office park.',
        icon: Icons.forum_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadFeed(refresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _PostCard(post: posts[i], provider: provider),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.provider});

  final Post post;
  final CommunityProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PulseAvatar(
                imageUrl: post.author?.profileImage,
                initials: post.author?.initials ?? 'P',
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author?.fullName ?? 'Someone',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (post.author?.subtitle.isNotEmpty == true)
                          post.author!.subtitle,
                        relativeTime(post.createdAt),
                      ].join(' · '),
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (post.communityName != null)
                PulseChip(
                  label: post.communityName!,
                  color: AppColors.tintFor(post.communityName),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Text(post.body, style: theme.textTheme.bodyMedium),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 13),
            PulseImage(url: post.imageUrl, height: 190, radius: 12),
          ],
          const SizedBox(height: 13),
          Row(
            children: [
              _ActionButton(
                icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: post.likesCount == 0 ? 'Like' : '${post.likesCount}',
                active: post.isLiked,
                onTap: () async {
                  try {
                    await provider.toggleLike(post);
                  } on ApiException catch (e) {
                    if (context.mounted) {
                      showPulseSnack(context, e.message, isError: true);
                    }
                  }
                },
              ),
              const SizedBox(width: 18),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                label: post.commentsCount == 0 ? 'Comment' : '${post.commentsCount}',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => _CommentsSheet(post: post, provider: provider),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.danger
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab({required this.provider});

  final CommunityProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = provider.mine.data ?? const <Community>[];
    final discover = provider.discover.data ?? const <Community>[];

    if (provider.mine.isLoading && !provider.mine.hasData) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: CardListSkeleton(count: 3, height: 96),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadAll(refresh: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
        children: [
          if (mine.isNotEmpty) ...[
            Text('Your groups', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            ...mine.map((c) => _CommunityTile(community: c, provider: provider)),
            const SizedBox(height: 24),
          ],
          Text('Discover groups', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (discover.isEmpty)
            const EmptyState(
              title: 'You are in every group',
              message: 'New groups for your park will show up here.',
              icon: Icons.groups_outlined,
            )
          else
            ...discover.map((c) => _CommunityTile(community: c, provider: provider)),
        ],
      ),
    );
  }
}

class _CommunityTile extends StatelessWidget {
  const _CommunityTile({required this.community, required this.provider});

  final Community community;
  final CommunityProvider provider;

  Future<void> _toggle(BuildContext context) async {
    try {
      if (community.joined) {
        await provider.leave(community.id);
        if (context.mounted) showPulseSnack(context, 'You left ${community.name}.');
      } else {
        await provider.join(community.id);
        if (context.mounted) showPulseSnack(context, 'Joined ${community.name}.');
      }
    } on ApiException catch (e) {
      if (context.mounted) showPulseSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Row(
          children: [
            PulseImage(url: community.coverImage, height: 58, width: 58, radius: 12),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${community.membersCount} '
                    '${community.membersCount == 1 ? 'member' : 'members'}'
                    '${community.category != null ? ' · ${community.category}' : ''}',
                    style: theme.textTheme.labelSmall,
                  ),
                  if (community.description != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      community.description!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            TextButton(
              onPressed: () => _toggle(context),
              style: TextButton.styleFrom(
                foregroundColor:
                    community.joined ? theme.colorScheme.onSurfaceVariant : AppColors.primary,
                minimumSize: const Size(64, 36),
              ),
              child: Text(community.joined ? 'Leave' : 'Join'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet();

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Say something', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 5,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Share something with your office park…',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post, required this.provider});

  final Post post;
  final CommunityProvider provider;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  List<Comment>? _comments;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await widget.provider.comments(widget.post.id);
      if (mounted) setState(() => _comments = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.provider.addComment(widget.post.id, text);
      _controller.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) showPulseSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comments = _comments;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Text('Comments', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (_error != null) {
                    return ErrorView(message: _error!, onRetry: _load);
                  }
                  if (comments == null) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: CardListSkeleton(count: 3, height: 56),
                    );
                  }
                  if (comments.isEmpty) {
                    return const EmptyState(
                      title: 'No comments yet',
                      message: 'Start the conversation.',
                      icon: Icons.mode_comment_outlined,
                    );
                  }
                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                    itemCount: comments.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 18),
                    itemBuilder: (_, i) {
                      final c = comments[i];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PulseAvatar(
                            imageUrl: c.author?.profileImage,
                            initials: c.author?.initials ?? 'P',
                            size: 34,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      c.author?.fullName ?? 'Someone',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      relativeTime(c.createdAt),
                                      style: theme.textTheme.labelSmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(c.body, style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment…',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 19),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
