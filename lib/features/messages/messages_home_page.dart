// lib/features/messages/messages_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/result.dart';
import '../../models/app_user.dart';
import '../../models/messaging.dart';
import '../../repositories/messaging_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/application_shell.dart';
import '../../widgets/compact_sign_in_dialog.dart';
import '../../widgets/widgets.dart';
import 'chat_conversation_page.dart';
import 'find_people_page.dart';

import '../../widgets/skeleton_spinner.dart';
class MessagesHomePage extends StatefulWidget {
  final AppUser user;
  const MessagesHomePage({super.key, required this.user});

  @override
  State<MessagesHomePage> createState() => _MessagesHomePageState();
}

class _MessagesHomePageState extends State<MessagesHomePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _filter = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openRequestsDialog(BuildContext context) {
    final ac = AppColors.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ac.surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.mark_chat_unread_outlined,
                      color: Color(0xFFE5A93C),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Message Requests',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: ac.txt,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: Icon(Icons.close_rounded, color: ac.txt2, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Accept a request to start messaging directly.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: _MessageRequestsList(
                    user: widget.user,
                    onOpenChat: (convId, r) {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatConversationPage(
                            conversationId: convId,
                            currentUser: widget.user,
                            otherUserId: r.fromUserId,
                            otherUserName: r.fromUserName,
                            otherUserPhoto: r.fromUserPhotoUrl,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isGuest = widget.user.isGuest || widget.user.id.isEmpty;

    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Messages',
      subtitle: 'Direct conversations with classmates, study partners, and lecturers',
      currentDestination: AppNavDestination.messages,
      contextualPanel: MessagesContextualPanel(user: widget.user),
      headerActions: [
        if (!isGuest)
          StreamBuilder<List<FriendRequest>>(
            stream: MessagingRepository.instance.watchIncomingRequests(widget.user.id),
            builder: (context, snap) {
              final count = snap.data?.length ?? 0;
              return OutlinedButton.icon(
                onPressed: () => _openRequestsDialog(context),
                icon: const Icon(Icons.mark_chat_unread_outlined, size: 16),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Message Requests'),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A93C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF081630),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: ac.txt,
                  side: BorderSide(color: count > 0 ? const Color(0xFFE5A93C) : ac.bdr),
                ),
              );
            },
          ),
        const SizedBox(width: 8),
        if (isGuest)
          ElevatedButton.icon(
            onPressed: () => showCompactSignInDialog(context),
            icon: const Icon(Icons.login_rounded, size: 16),
            label: const Text('Sign In to Chat'),
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: const Color(0xFFE5A93C),
              foregroundColor: const Color(0xFF081630),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FindPeoplePage(user: widget.user),
                ),
              );
            },
            icon: const Icon(Icons.edit_square, size: 16),
            label: const Text('New Message'),
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: const Color(0xFF081630),
              foregroundColor: Colors.white,
            ),
          ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.inter(fontSize: 13.5, color: ac.txt),
              decoration: InputDecoration(
                hintText: 'Filter conversations by contact name or message...',
                hintStyle: GoogleFonts.inter(color: ac.muted, fontSize: 13.5),
                prefixIcon: Icon(Icons.search_rounded, color: ac.muted, size: 20),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: ac.muted, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: ac.surf,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ac.bdr),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ac.bdr),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _ConversationsOverview(user: widget.user, filter: _filter),
          ),
        ],
      ),
    );
  }
}

class _ConversationsOverview extends StatelessWidget {
  final AppUser user;
  final String filter;
  const _ConversationsOverview({required this.user, required this.filter});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    if (user.isGuest || user.id.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 56, color: ac.muted.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              Text(
                'Sign in to message classmates and teachers',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ac.txt,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create an account or sign in to send direct messages and share study materials.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: ac.txt2),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => showCompactSignInDialog(context),
                icon: const Icon(Icons.login_rounded, size: 16),
                label: const Text('Sign In Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ac.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<Conversation>>(
      stream: MessagingRepository.instance.watchConversations(user.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: SkeletonSpinner());
        }
        if (snap.hasError) {
          return Center(child: ErrorView(message: snap.error.toString()));
        }

        final all = snap.data ?? const <Conversation>[];
        var filtered = all;
        if (filter.isNotEmpty) {
          filtered = filtered.where((c) {
            final otherId = c.otherParticipantId(user.id);
            final otherName = c.participantNames[otherId] ?? '';
            return otherName.toLowerCase().contains(filter) ||
                c.lastMessageText.toLowerCase().contains(filter);
          }).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 56,
                    color: ac.muted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    filter.isNotEmpty
                        ? 'No conversations match "$filter"'
                        : 'No conversations yet',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ac.txt,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    filter.isNotEmpty
                        ? 'Try a different keyword or search for new people.'
                        : 'Start a conversation with a classmate, study partner, or teacher.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: ac.txt2),
                  ),
                  if (filter.isEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FindPeoplePage(user: user),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_search_rounded, size: 18),
                      label: const Text('Find People'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF081630),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        final pinned =
            filtered.where((c) => c.pinnedBy.contains(user.id)).toList();
        final unpinned =
            filtered.where((c) => !c.pinnedBy.contains(user.id)).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (pinned.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 4),
                child: Row(
                  children: [
                    Icon(Icons.push_pin_rounded, size: 14, color: ac.muted),
                    const SizedBox(width: 6),
                    Text(
                      'PINNED CONVERSATIONS',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: ac.muted,
                      ),
                    ),
                  ],
                ),
              ),
              ...pinned.map((c) => _ConversationRow(user: user, conversation: c)),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'ALL CONVERSATIONS',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: ac.muted,
                  ),
                ),
              ),
            ],
            ...unpinned.map((c) => _ConversationRow(user: user, conversation: c)),
          ],
        );
      },
    );
  }
}

class _MessageRequestsList extends StatelessWidget {
  final AppUser user;
  final void Function(String convId, FriendRequest request) onOpenChat;

  const _MessageRequestsList({
    required this.user,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<List<FriendRequest>>(
      stream: MessagingRepository.instance.watchIncomingRequests(user.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: SkeletonSpinner());
        }
        final reqs = snap.data ?? const <FriendRequest>[];
        if (reqs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mark_email_read_rounded,
                    size: 44,
                    color: ac.muted.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No pending message requests.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ac.txt,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'When someone new sends you a request to connect, it will appear here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12.5, color: ac.txt2),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          itemCount: reqs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final r = reqs[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ac.surf2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ac.bdr),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    initials: r.fromUserName.isEmpty
                        ? '?'
                        : r.fromUserName[0].toUpperCase(),
                    radius: 22,
                    photoUrl: r.fromUserPhotoUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.fromUserName.isNotEmpty ? r.fromUserName : 'Student',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: ac.txt,
                          ),
                        ),
                        if (r.fromUserRoleLabel.isNotEmpty)
                          Text(
                            r.fromUserRoleLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: ac.txt2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      MessagingRepository.instance.declineRequest(r.id);
                    },
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final res = await MessagingRepository.instance
                          .acceptRequest(r, user.name, user.photoUrl);
                      if (!context.mounted) return;
                      if (res.isSuccess) {
                        final convRes = await MessagingRepository.instance
                            .getOrCreateConversation(
                          userAId: user.id,
                          userAName: user.name,
                          userAPhoto: user.photoUrl,
                          userBId: r.fromUserId,
                          userBName: r.fromUserName,
                          userBPhoto: r.fromUserPhotoUrl,
                        );
                        if (!context.mounted) return;
                        final convId = convRes.valueOrNull;
                        if (convId != null) {
                          onOpenChat(convId, r);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A93C),
                      foregroundColor: const Color(0xFF081630),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Accept'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

extension _MsgIconExt on Icons {
  static const IconData mark_email_Read_rounded_or_default =
      Icons.mark_email_read_outlined;
}

class _ConversationRow extends StatelessWidget {
  final AppUser user;
  final Conversation conversation;
  const _ConversationRow({required this.user, required this.conversation});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final otherId = conversation.otherParticipantId(user.id);
    final otherName = conversation.participantNames[otherId] ?? 'Unknown';
    final otherPhoto = conversation.participantPhotos[otherId];
    final unread = conversation.unreadCount[user.id] ?? 0;
    final isPinned = conversation.pinnedBy.contains(user.id);
    final online = conversation.isRecentlyActive(otherId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          MessagingRepository.instance
              .togglePinned(conversation.id, user.id, !isPinned);
          showToast(context, isPinned ? 'Unpinned' : 'Pinned to top');
        },
        child: Container(
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread > 0
                  ? const Color(0xFFE5A93C).withValues(alpha: 0.6)
                  : ac.bdr,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  settings: RouteSettings(name: '/messages/${conversation.id}'),
                  builder: (_) => ChatConversationPage(
                    conversationId: conversation.id,
                    currentUser: user,
                    otherUserId: otherId,
                    otherUserName: otherName,
                    otherUserPhoto: otherPhoto,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    UserAvatar(
                      initials:
                          otherName.isEmpty ? '?' : otherName[0].toUpperCase(),
                      radius: 24,
                      photoUrl: otherPhoto,
                      showPresenceDot: true,
                      online: online,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  otherName,
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    fontWeight: unread > 0
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: ac.txt,
                                  ),
                                ),
                              ),
                              if (isPinned)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.push_pin_rounded,
                                    size: 13,
                                    color: ac.muted,
                                  ),
                                ),
                              Text(
                                _relativeTime(conversation.lastMessageAt),
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: unread > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: unread > 0
                                      ? const Color(0xFFE5A93C)
                                      : ac.muted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conversation.lastMessageText.isEmpty
                                      ? 'No messages yet — say hello!'
                                      : (conversation.lastMessageSenderId ==
                                              user.id
                                          ? 'You: ${conversation.lastMessageText}'
                                          : conversation.lastMessageText),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: unread > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: unread > 0 ? ac.txt : ac.txt2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unread > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5A93C),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF081630),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:${dt.minute.toString().padLeft(2, '0')} $ampm';
    }
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}
