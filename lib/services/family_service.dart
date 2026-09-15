import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

final familyServiceProvider = Provider<FamilyService>((ref) => FamilyService());

final userProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data());
});

final familyGroupsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userAsync = ref.watch(userProvider);
  
  return userAsync.when(
    data: (userData) {
      if (userData == null || userData['familyGroupIds'] == null) {
        return Stream.value([]);
      }
      final List<dynamic> groupIds = userData['familyGroupIds'];
      if (groupIds.isEmpty) return Stream.value([]);

      return FirebaseFirestore.instance
          .collection('family_groups')
          .where(FieldPath.documentId, whereIn: groupIds)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList());
    },
    loading: () => Stream.value([]),
    error: (e, st) => Stream.value([]),
  );
});

final familyMembersProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  return FirebaseFirestore.instance
      .collection('family_groups')
      .doc(groupId)
      .snapshots()
      .asyncMap((groupDoc) async {
    if (!groupDoc.exists) return [];
    final List<dynamic> memberIds = groupDoc.data()?['members'] ?? [];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (memberIds.isEmpty) return [];

    final otherMemberIds = memberIds.where((id) => id != currentUid).toList();
    if (otherMemberIds.isEmpty) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: otherMemberIds)
        .get();

    return snapshot.docs
        .map((doc) => {'uid': doc.id, ...doc.data()})
        .toList();
  });
});

class FamilyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  /// Create a new family group and generate an invite code
  Future<String> createGroup(String groupName) async {
    final inviteCode = _generateInviteCode();

    final groupRef = await _firestore.collection('family_groups').add({
      'name': groupName,
      'owner': _uid,
      'members': [_uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Create the invite
    await _firestore.collection('invites').doc(inviteCode).set({
      'familyGroupId': groupRef.id,
      'createdBy': _uid,
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
      'usedBy': null,
    });

    // Update user with family group
    await _firestore.collection('users').doc(_uid).update({
      'familyGroupIds': FieldValue.arrayUnion([groupRef.id]),
    });

    return inviteCode;
  }

  /// Join a family group using an invite code
  Future<void> joinGroup(String inviteCode) async {
    final inviteDoc = await _firestore.collection('invites').doc(inviteCode.toUpperCase()).get();

    if (!inviteDoc.exists) {
      throw Exception('Invalid invite code.');
    }

    final inviteData = inviteDoc.data()!;

    if (inviteData['usedBy'] != null) {
      throw Exception('This invite code has already been used.');
    }

    final expiresAt = (inviteData['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) {
      throw Exception('This invite code has expired.');
    }

    final groupId = inviteData['familyGroupId'] as String;

    // Add to family group
    await _firestore.collection('family_groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([_uid]),
    });

    // Mark invite as used
    await _firestore.collection('invites').doc(inviteCode.toUpperCase()).update({
      'usedBy': _uid,
    });

    // Update user
    await _firestore.collection('users').doc(_uid).update({
      'familyGroupIds': FieldValue.arrayUnion([groupId]),
    });
  }

  /// Leave a family group
  Future<void> leaveGroup(String groupId) async {
    await _firestore.collection('family_groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([_uid]),
    });

    await _firestore.collection('users').doc(_uid).update({
      'familyGroupIds': FieldValue.arrayRemove([groupId]),
    });
  }

  /// Generate a 6-character invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate a new invite code for an existing group
  Future<String> generateInvite(String groupId) async {
    final inviteCode = _generateInviteCode();

    await _firestore.collection('invites').doc(inviteCode).set({
      'familyGroupId': groupId,
      'createdBy': _uid,
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
      'usedBy': null,
    });

    return inviteCode;
  }
}
