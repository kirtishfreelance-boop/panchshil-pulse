import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../models/community.dart';
import '../models/post.dart';
import 'async_value.dart';

class CommunityProvider extends ChangeNotifier {
  CommunityProvider(this._api);

  final ApiClient _api;

  AsyncValue<List<Community>> _mine = const AsyncValue.idle();
  AsyncValue<List<Community>> _discover = const AsyncValue.idle();
  List<Community> _trending = const [];
  AsyncValue<List<Post>> _feed = const AsyncValue.idle();

  AsyncValue<List<Community>> get mine => _mine;
  AsyncValue<List<Community>> get discover => _discover;
  List<Community> get trending => _trending;
  AsyncValue<List<Post>> get feed => _feed;

  Future<void> loadAll({bool refresh = false}) async {
    await Future.wait([
      loadMine(refresh: refresh),
      loadDiscover(refresh: refresh),
      loadTrending(),
      loadFeed(refresh: refresh),
    ]);
  }

  Future<void> loadMine({bool refresh = false}) async {
    _mine = refresh ? _mine.toLoading() : const AsyncValue.loading();
    notifyListeners();
    try {
      final json = await _api.get(Api.myCommunities);
      _mine = AsyncValue.data(listFrom(json, 'communities', Community.fromJson));
    } on ApiException catch (e) {
      _mine = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<void> loadDiscover({bool refresh = false}) async {
    _discover = refresh ? _discover.toLoading() : const AsyncValue.loading();
    notifyListeners();
    try {
      final json = await _api.get(Api.otherCommunities);
      _discover = AsyncValue.data(listFrom(json, 'communities', Community.fromJson));
    } on ApiException catch (e) {
      _discover = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<void> loadTrending() async {
    try {
      final json = await _api.get(Api.trendingCommunities);
      _trending = listFrom(json, 'communities', Community.fromJson);
      notifyListeners();
    } on ApiException {
      _trending = const [];
    }
  }

  Future<void> loadFeed({int? communityId, bool refresh = false}) async {
    _feed = refresh ? _feed.toLoading() : const AsyncValue.loading();
    notifyListeners();
    try {
      final json = await _api.get(
        Api.posts,
        query: communityId == null ? null : {'community_id': communityId},
      );
      _feed = AsyncValue.data(listFrom(json, 'posts', Post.fromJson));
    } on ApiException catch (e) {
      _feed = AsyncValue.error(e.message);
    }
    notifyListeners();
  }

  Future<List<CommunityMember>> members(int communityId) async {
    final json = await _api.get(Api.communityMembers, query: {'community_id': communityId});
    return listFrom(json, 'members', CommunityMember.fromJson);
  }

  Future<void> join(int communityId) async {
    await _api.post(Api.communityMembers, body: {'community_id': communityId});
    await Future.wait([loadMine(refresh: true), loadDiscover(refresh: true)]);
  }

  Future<void> leave(int communityId) async {
    await _api.delete(Api.communityMembers, body: {'community_id': communityId});
    await Future.wait([loadMine(refresh: true), loadDiscover(refresh: true)]);
  }

  Future<void> createPost({required String body, int? communityId, String? imageUrl}) async {
    await _api.post(Api.posts, body: {
      'body': body,
      'community_id': communityId,
      'image_url': imageUrl,
    });
    await loadFeed(communityId: communityId, refresh: true);
  }

  /// Optimistic toggle — the row updates immediately and reconciles on response.
  Future<void> toggleLike(Post post, {String reaction = 'heart'}) async {
    final wasLiked = post.isLiked;
    _patchPost(post.copyWith(
      likesCount: post.likesCount + (wasLiked ? -1 : 1),
      myReaction: wasLiked ? null : reaction,
      clearReaction: wasLiked,
    ));

    try {
      final json = wasLiked
          ? await _api.delete(Api.likeThings,
              body: {'likeable_type': 'Post', 'likeable_id': post.id})
          : await _api.post(Api.likeThings, body: {
              'likeable_type': 'Post',
              'likeable_id': post.id,
              'reaction': reaction,
            });
      final updated = json['post'];
      if (updated is Map<String, dynamic>) _patchPost(Post.fromJson(updated));
    } on ApiException {
      _patchPost(post); // Roll back to the pre-tap state.
      rethrow;
    }
  }

  Future<List<Comment>> comments(int postId) async {
    final json = await _api.get(Api.comments, query: {'post_id': postId});
    return listFrom(json, 'comments', Comment.fromJson);
  }

  Future<Comment> addComment(int postId, String body) async {
    final json = await _api.post(Api.comments, body: {'post_id': postId, 'body': body});
    // Bump the comment count on the feed row the user came from.
    final list = _feed.data;
    if (list != null && list.any((p) => p.id == postId)) {
      await loadFeed(refresh: true);
    }
    return Comment.fromJson(json['comment'] as Map<String, dynamic>);
  }

  void _patchPost(Post updated) {
    final list = _feed.data;
    if (list == null) return;
    _feed = AsyncValue.data(
      list.map((p) => p.id == updated.id ? updated : p).toList(growable: false),
    );
    notifyListeners();
  }
}
