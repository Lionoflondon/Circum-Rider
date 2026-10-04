import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchRiderLedger(
    String collection, String uid,
    {required int records}) {
  final query = FirebaseFirestore.instance
      .collection(collection)
      .where('riderId', isEqualTo: uid)
      .orderBy('createdAt', descending: true);
  return query.limit(40).snapshots().asyncMap((head) async {
    final documents = [...head.docs];
    var page = head.docs;
    while (documents.length < records && page.length == 40) {
      final next = await query.startAfterDocument(page.last).limit(40).get();
      page = next.docs;
      documents.addAll(page);
    }
    if (FirebaseAuth.instance.currentUser?.uid != uid)
      return <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    return {for (final doc in documents.take(records)) doc.id: doc}
        .values
        .toList();
  });
}
