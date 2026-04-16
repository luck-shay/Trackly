const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions, logger} = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();
setGlobalOptions({region: "asia-south2", maxInstances: 10});

const TOKEN_BATCH_SIZE = 500;

function chunkArray(items, size) {
  const chunks = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

async function reserveEventOnce(event, scope) {
  const eventId = event?.id;
  if (!eventId) {
    // If event id is missing for any reason, do not block delivery.
    return true;
  }

  const dedupeKey = `${scope}:${eventId}`;
  const ref = admin.firestore().collection("notificationEvents").doc(dedupeKey);
  try {
    await ref.create({
      scope,
      eventId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      ),
    });
    return true;
  } catch (error) {
    if (error?.code === 6 || error?.code === "already-exists") {
      logger.info("Skipping duplicate notification event", {scope, eventId});
      return false;
    }
    throw error;
  }
}

function toStringMap(data) {
  const out = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    out[key] = String(value);
  }
  return out;
}

function parseStorageRefFromUrl(rawUrl) {
  if (typeof rawUrl !== "string") return null;
  const url = rawUrl.trim();
  if (!url) return null;

  if (url.startsWith("gs://")) {
    const withoutScheme = url.slice(5);
    const slashIndex = withoutScheme.indexOf("/");
    if (slashIndex <= 0 || slashIndex === withoutScheme.length - 1) {
      return null;
    }

    return {
      bucket: withoutScheme.slice(0, slashIndex),
      path: withoutScheme.slice(slashIndex + 1),
    };
  }

  try {
    const parsed = new URL(url);
    const segments = parsed.pathname.split("/").filter(Boolean);
    const bucketIndex = segments.indexOf("b");
    const objectIndex = segments.indexOf("o");
    if (bucketIndex < 0 || objectIndex < 0) return null;
    if (bucketIndex + 1 >= segments.length || objectIndex + 1 >= segments.length) return null;

    const bucket = segments[bucketIndex + 1];
    const path = decodeURIComponent(segments.slice(objectIndex + 1).join("/"));
    if (!bucket || !path) return null;
    return {bucket, path};
  } catch (_) {
    return null;
  }
}

function isOwnedProfilePath(uid, path) {
  if (!uid || !path) return false;
  const normalized = String(path).trim();
  return normalized.startsWith(`profile_pictures/${uid}/`) ||
    normalized === `profile_pictures/${uid}.jpg`;
}

async function getUserProfile(uid) {
  if (!uid) return null;
  const doc = await admin.firestore().collection("users").doc(uid).get();
  if (!doc.exists) return null;
  return doc.data() || null;
}

async function getUserTokens(uid) {
  if (!uid) return [];
  const profile = await getUserProfile(uid);
  if (!profile) return [];
  const tokens = Array.isArray(profile.fcmTokens) ? profile.fcmTokens : [];
  return [...new Set(tokens
    .filter((token) => typeof token === "string" && token.trim().length > 0)
    .map((token) => token.trim()))];
}

async function removeInvalidTokens(uid, invalidTokens) {
  if (!uid || !invalidTokens.length) return;
  await admin.firestore().collection("users").doc(uid).set(
    {
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      lastTokenCleanup: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

async function sendPushToUser({uid, title, body, data}) {
  const tokens = await getUserTokens(uid);
  if (!tokens.length) {
    logger.info("No FCM tokens available for target user", {uid});
    return;
  }

  const payloadBase = {
    notification: {
      title,
      body,
    },
    data: toStringMap(data || {}),
    android: {
      priority: "high",
      notification: {
        channelId: "social_alerts_channel",
        sound: "default",
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  };

  let successCount = 0;
  let failureCount = 0;
  const invalidTokens = [];
  const failureCodeCounts = {};

  const tokenBatches = chunkArray(tokens, TOKEN_BATCH_SIZE);
  for (const batch of tokenBatches) {
    const response = await admin.messaging().sendEachForMulticast({
      ...payloadBase,
      tokens: batch,
    });

    successCount += response.successCount;
    failureCount += response.failureCount;

    response.responses.forEach((result, index) => {
      if (result.success) return;
      const code = result.error?.code || "unknown";
      failureCodeCounts[code] = (failureCodeCounts[code] || 0) + 1;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(batch[index]);
      }
    });
  }

  if (invalidTokens.length) {
    await removeInvalidTokens(uid, [...new Set(invalidTokens)]);
  }

  logger.info("Push dispatch complete", {
    uid,
    tokenCount: tokens.length,
    batchCount: tokenBatches.length,
    successCount,
    failureCount,
    invalidTokenCount: invalidTokens.length,
    failureCodeCounts,
  });
}

exports.notifyFriendInviteCreated = onDocumentCreated(
  "friendRequests/{requestId}",
  async (event) => {
    if (!(await reserveEventOnce(event, "notifyFriendInviteCreated"))) return;

    const data = event.data?.data();
    if (!data) return;
    if (data.status !== "pending") return;

    const toUid = data.to;
    const fromUid = data.from;
    if (!toUid || !fromUid) return;

    const sender = await getUserProfile(fromUid);
    const senderName = sender?.displayName || "A user";

    await sendPushToUser({
      uid: toUid,
      title: "New Friend Request",
      body: `${senderName} wants to connect with you.`,
      data: {
        type: "friendRequest",
        requestId: event.params.requestId,
      },
    });
  },
);

exports.notifyHabitInviteCreated = onDocumentCreated(
  "habitInvites/{inviteId}",
  async (event) => {
    if (!(await reserveEventOnce(event, "notifyHabitInviteCreated"))) return;

    const data = event.data?.data();
    if (!data) return;
    if (data.status !== "pending") return;

    const toUid = data.to;
    const fromUid = data.from;
    const habitId = data.habitId;
    if (!toUid || !fromUid) return;

    const sender = await getUserProfile(fromUid);
    const senderName = sender?.displayName || "A user";

    let habitTitle = "a habit";
    if (habitId) {
      const habitDoc = await admin.firestore().collection("habits").doc(habitId).get();
      if (habitDoc.exists) {
        const habit = habitDoc.data() || {};
        if (typeof habit.title === "string" && habit.title.trim().length > 0) {
          habitTitle = habit.title.trim();
        }
      }
    }

    await sendPushToUser({
      uid: toUid,
      title: "Habit Invite",
      body: `${senderName} invited you to join \"${habitTitle}\".`,
      data: {
        type: "habitInvite",
        inviteId: event.params.inviteId,
        habitId: habitId || "",
      },
    });
  },
);

exports.notifyGroupInviteCreated = onDocumentCreated(
  "groupInvites/{inviteId}",
  async (event) => {
    if (!(await reserveEventOnce(event, "notifyGroupInviteCreated"))) return;

    const data = event.data?.data();
    if (!data) return;
    if (data.status !== "pending") return;

    const toUid = data.to;
    const fromUid = data.from;
    if (!toUid || !fromUid) return;

    const sender = await getUserProfile(fromUid);
    const senderName = sender?.displayName || "A user";
    const groupName =
      typeof data.groupName === "string" && data.groupName.trim().length > 0
        ? data.groupName.trim()
        : "a group";

    await sendPushToUser({
      uid: toUid,
      title: "Group Invite",
      body: `${senderName} invited you to join \"${groupName}\".`,
      data: {
        type: "groupInvite",
        inviteId: event.params.inviteId,
      },
    });
  },
);

exports.notifyInviteResponses = onDocumentUpdated(
  "{collectionId}/{docId}",
  async (event) => {
    if (!(await reserveEventOnce(event, "notifyInviteResponses"))) return;

    const allowedCollections = new Set([
      "friendRequests",
      "habitInvites",
      "groupInvites",
    ]);

    const collectionId = event.params.collectionId;
    if (!allowedCollections.has(collectionId)) return;

    const before = event.data?.before?.data() || null;
    const after = event.data?.after?.data() || null;
    if (!before || !after) return;

    const beforeStatus = before.status || "";
    const afterStatus = after.status || "";
    if (beforeStatus === afterStatus) return;
    if (afterStatus !== "accepted" && afterStatus !== "declined") return;

    const fromUid = after.from;
    const toUid = after.to;
    if (!fromUid || !toUid) return;

    const targetUser = await getUserProfile(toUid);
    const targetName = targetUser?.displayName || "A user";
    const accepted = afterStatus === "accepted";

    let title;
    let body;

    if (collectionId === "friendRequests") {
      title = accepted ? "Friend Request Accepted" : "Friend Request Declined";
      body = accepted
        ? `${targetName} accepted your friend request.`
        : `${targetName} declined your friend request.`;
    } else if (collectionId === "habitInvites") {
      let habitTitle = "your habit";
      if (after.habitId) {
        const habitDoc = await admin.firestore().collection("habits").doc(after.habitId).get();
        if (habitDoc.exists) {
          const habit = habitDoc.data() || {};
          if (typeof habit.title === "string" && habit.title.trim().length > 0) {
            habitTitle = habit.title.trim();
          }
        }
      }
      title = accepted ? "Habit Invite Accepted" : "Habit Invite Declined";
      body = accepted
        ? `${targetName} accepted your invite to \"${habitTitle}\".`
        : `${targetName} declined your invite to \"${habitTitle}\".`;
    } else {
      const groupName =
        typeof after.groupName === "string" && after.groupName.trim().length > 0
          ? after.groupName.trim()
          : "your group";
      title = accepted ? "Group Invite Accepted" : "Group Invite Declined";
      body = accepted
        ? `${targetName} accepted your invite to \"${groupName}\".`
        : `${targetName} declined your invite to \"${groupName}\".`;
    }

    await sendPushToUser({
      uid: fromUid,
      title,
      body,
      data: {
        type: "inviteResponse",
        collectionId,
        docId: event.params.docId,
        status: afterStatus,
      },
    });
  },
);

exports.notifyHabitNoticeCreated = onDocumentCreated(
  "habitNotices/{noticeId}",
  async (event) => {
    if (!(await reserveEventOnce(event, "notifyHabitNoticeCreated"))) return;

    const data = event.data?.data();
    if (!data) return;
    if (data.status !== "unread") return;

    const toUid = data.to;
    if (!toUid) return;

    const message =
      typeof data.message === "string" && data.message.trim().length > 0
        ? data.message.trim()
        : "A participant left one of your shared habits.";

    await sendPushToUser({
      uid: toUid,
      title: "Participant Left",
      body: message,
      data: {
        type: "habitNotice",
        noticeId: event.params.noticeId,
      },
    });

    await event.data.ref.set(
      {
        status: "notified",
        notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  },
);

exports.cleanupOldProfilePictureOnUpdate = onDocumentUpdated(
  "users/{uid}",
  async (event) => {
    const uid = event.params.uid;
    if (!uid) return;

    const before = event.data?.before?.data() || null;
    const after = event.data?.after?.data() || null;
    if (!before || !after) return;

    const beforeUrl = typeof before.photoUrl === "string" ? before.photoUrl.trim() : "";
    const afterUrl = typeof after.photoUrl === "string" ? after.photoUrl.trim() : "";

    // Only act when the URL changed.
    if (beforeUrl === afterUrl || !beforeUrl) return;

    const oldRef = parseStorageRefFromUrl(beforeUrl);
    if (!oldRef) return;
    if (!isOwnedProfilePath(uid, oldRef.path)) return;

    // Never delete if old and new resolve to the same storage object.
    const newRef = parseStorageRefFromUrl(afterUrl);
    if (newRef && newRef.bucket === oldRef.bucket && newRef.path === oldRef.path) {
      return;
    }

    try {
      await admin.storage().bucket(oldRef.bucket).file(oldRef.path).delete({ignoreNotFound: true});
      logger.info("Cleaned old profile image", {
        uid,
        bucket: oldRef.bucket,
        path: oldRef.path,
      });
    } catch (error) {
      logger.error("Failed to clean old profile image", {
        uid,
        bucket: oldRef.bucket,
        path: oldRef.path,
        error: error?.message || String(error),
      });
    }
  },
);
