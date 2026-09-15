import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/family_service.dart';
import '../services/ring_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'settings_screen.dart';

/// Tracks UIDs of members who are currently being rung.
/// Stored in a global provider so state survives navigation (e.g. to Settings).
class RingingMembersNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void add(String uid) => state = <String>{...state, uid};
  void remove(String uid) => state = <String>{...state}..remove(uid);
}

final ringingMembersProvider =
    NotifierProvider<RingingMembersNotifier, Set<String>>(RingingMembersNotifier.new);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _useSmsMode = false;

  // Dialog text controllers — kept as fields so they can be disposed properly
  final TextEditingController _createGroupController = TextEditingController();
  final TextEditingController _joinGroupController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ringServiceProvider).requestPermissions();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _createGroupController.dispose();
    _joinGroupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(familyGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nasan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppTheme.surfaceDark,
                  title: const Text('Log Out?'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Log Out',
                          style: TextStyle(color: AppTheme.primaryRed)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authServiceProvider).logout();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Network Toggle Mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.cardDark.withValues(alpha: 0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _useSmsMode ? Icons.signal_cellular_alt_rounded : Icons.wifi_rounded,
                      color: _useSmsMode ? AppTheme.accentGlow : AppTheme.success,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _useSmsMode ? 'Offline Mode (SMS)' : 'Internet Mode (Wi-Fi)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Switch(
                  value: _useSmsMode,
                  activeThumbColor: AppTheme.accentGlow,
                  onChanged: (val) {
                    setState(() {
                      _useSmsMode = val;
                    });
                  },
                ),
              ],
            ),
          ),
          
          Expanded(
            child: groupsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (groups) {
                if (groups.isEmpty) {
                  return _buildNoGroupView();
                }
                return ListView.builder(
                  itemCount: groups.length + 1, // +1 for add group button at end
                  itemBuilder: (context, index) {
                    if (index == groups.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddGroupOptions(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Another Group'),
                        ),
                      );
                    }
                    return _buildGroupSection(groups[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddGroupOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Create New Group'),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateGroupDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Join Existing Group'),
              onTap: () {
                Navigator.pop(ctx);
                _showJoinGroupDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoGroupView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.group_add_rounded,
                  size: 48, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Family Group',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a family group or join one\nwith an invite code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateGroupDialog(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Group'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _showJoinGroupDialog(),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Join with Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSection(Map<String, dynamic> group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header
        Container(
          margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.cardDark,
                AppTheme.cardDark.withValues(alpha: 0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryRed.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.family_restroom_rounded,
                    color: AppTheme.primaryRed, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group['name'] ?? 'Family Group',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(group['members'] as List?)?.length ?? 0} members',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                color: AppTheme.cardDark,
                onSelected: (value) async {
                  if (value == 'invite') {
                    _showInviteDialog(group['id']);
                  } else if (value == 'leave') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surfaceDark,
                        title: const Text('Leave Group?'),
                        content: const Text(
                            'You will lose the ability to ring or locate members in this group.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Leave',
                                style: TextStyle(color: AppTheme.primaryRed)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(familyServiceProvider).leaveGroup(group['id']);
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'invite', child: Text('Invite Member')),
                  const PopupMenuItem(
                      value: 'leave',
                      child: Text('Leave Group',
                          style: TextStyle(color: AppTheme.primaryRed))),
                ],
              ),
            ],
          ),
        ),

        // Group Members List using the familyMembersProvider
        Consumer(
          builder: (context, ref, child) {
            final membersAsync = ref.watch(familyMembersProvider(group['id']));
            return membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: $e'),
              ),
              data: (members) {
                if (members.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => _showInviteDialog(group['id']),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Invite someone'),
                      ),
                    ),
                  );
                }
                return Column(
                  children: members.map((m) => _buildMemberCard(m)).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final uid = member['uid'] as String;
    final isRinging = ref.watch(ringingMembersProvider).contains(uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: isRinging 
            ? Border.all(color: AppTheme.primaryRed, width: 2) 
            : null,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                (member['displayName'] as String? ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['displayName'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '@${member['username'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          // Action Button
          if (isRinging)
            ElevatedButton(
              onPressed: () => _cancelRing(member),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.textPrimary),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('CANCEL'),
            )
          else
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryRed.withValues(alpha: 0.4 * _pulseController.value),
                        blurRadius: 12 * _pulseController.value,
                        spreadRadius: 1 * _pulseController.value,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: ElevatedButton(
                onPressed: () => _ringMember(member),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'RING',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _ringMember(Map<String, dynamic> member) async {
    final name = member['displayName'] ?? 'Unknown';
    final uid = member['uid'] as String;
    final phoneNumber = member['phoneNumber'] as String?;

    if (_useSmsMode && (phoneNumber == null || phoneNumber.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot use Offline Mode: Target user has no phone number saved.')),
        );
      }
      return;
    }

    final modeName = _useSmsMode ? 'Offline (SMS)' : 'Internet (Wi-Fi)';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text('Ring $name?'),
        content: Text(
            'This will send a $modeName signal to ring $name\'s phone at maximum volume.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ring Now'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      bool success = false;
      if (_useSmsMode) {
        success = await ref.read(ringServiceProvider).sendRingRequestSms(phoneNumber!);
      } else {
        success = await ref.read(ringServiceProvider).sendRingRequest(uid);
      }

      if (success) {
        ref.read(ringingMembersProvider.notifier).add(uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ring signal sent to $name via $modeName!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        throw Exception("Request failed");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ring $name. Try again.'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }

  Future<void> _cancelRing(Map<String, dynamic> member) async {
    final uid = member['uid'] as String;
    final phoneNumber = member['phoneNumber'] as String?;
    final name = member['displayName'] ?? 'Unknown';

    try {
      if (_useSmsMode) {
        if (phoneNumber != null) {
          await ref.read(ringServiceProvider).sendAbortRequestSms(phoneNumber);
        }
      } else {
        await ref.read(ringServiceProvider).sendAbortRequest(uid);
      }
      
      ref.read(ringingMembersProvider.notifier).remove(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancel signal sent to $name.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      // Still remove from UI even if it fails to avoid being stuck
      ref.read(ringingMembersProvider.notifier).remove(uid);
    }
  }

  void _showCreateGroupDialog() {
    _createGroupController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Create Family Group'),
        content: TextField(
          controller: _createGroupController,
          decoration: const InputDecoration(hintText: 'Group Name'),
          style: const TextStyle(color: AppTheme.textPrimary),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_createGroupController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                final code = await ref
                    .read(familyServiceProvider)
                    .createGroup(_createGroupController.text.trim());
                if (mounted) _showCodeDialog(code);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this code with your family member:',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: AppTheme.accentGlow,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied!')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Code'),
            ),
            const SizedBox(height: 4),
            const Text(
              'This code expires in 24 hours.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    _joinGroupController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Join Family Group'),
        content: TextField(
          controller: _joinGroupController,
          decoration: const InputDecoration(hintText: 'Enter Invite Code'),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            letterSpacing: 3,
          ),
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_joinGroupController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(familyServiceProvider)
                    .joinGroup(_joinGroupController.text.trim());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Joined family group!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppTheme.primaryRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(String groupId) async {
    try {
      final code = await ref.read(familyServiceProvider).generateInvite(groupId);
      if (mounted) _showCodeDialog(code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating invite: $e')),
        );
      }
    }
  }
}
