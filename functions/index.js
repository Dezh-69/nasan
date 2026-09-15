const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { initializeApp } = require("firebase-admin/app");

initializeApp();

exports.sendRingRequest = onCall(async (request) => {
  const data = request.data;
  const callerUid = request.auth?.uid;
  const targetUid = data.targetUid;

  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Must be logged in.");
  }

  if (!targetUid) {
    throw new HttpsError("invalid-argument", "Missing targetUid.");
  }

  const db = getFirestore();
  
  // Verify target user exists and get their FCM token
  const targetDoc = await db.collection("users").doc(targetUid).get();
  if (!targetDoc.exists) {
    throw new HttpsError("not-found", "Target user not found.");
  }

  const targetData = targetDoc.data();
  const fcmToken = targetData.fcmToken;
  const targetGroupId = targetData.familyGroupId;

  if (!fcmToken) {
    throw new HttpsError("failed-precondition", "Target user has no FCM token.");
  }

  // Verify caller is in the same family group
  const callerDoc = await db.collection("users").doc(callerUid).get();
  const callerData = callerDoc.data();
  
  if (!callerData || callerData.familyGroupId !== targetGroupId || !targetGroupId) {
    throw new HttpsError("permission-denied", "You are not in the same family group.");
  }

  // Send high-priority data message
  const message = {
    token: fcmToken,
    data: {
      type: "ring",
      from: callerUid
    },
    android: {
      priority: "high"
    }
  };

  try {
    const response = await getMessaging().send(message);
    
    // Log the request
    await db.collection("requests").add({
        from: callerUid,
        to: targetUid,
        type: "ring",
        status: "sent",
        createdAt: new Date(),
        messageId: response
    });
    
    return { success: true, messageId: response };
  } catch (error) {
    console.error("Error sending message:", error);
    throw new HttpsError("internal", "Failed to send ring request.");
  }
});
