const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const { FieldValue } = admin.firestore;

const APP_COMMISSION_RATE = 0.20;

function toNumber(value) {
  return Number(value || 0);
}

function serverTimestamp() {
  return FieldValue.serverTimestamp();
}

function bookingRequestId(bookingId, nurseId) {
  return `${bookingId}_${nurseId}`;
}

function toRadians(value) {
  return (value * Math.PI) / 180;
}

function distanceMeters(from, to) {
  if (!from || !to) {
    return Number.MAX_SAFE_INTEGER;
  }

  const earthRadiusMeters = 6371000;
  const lat1 = toRadians(from.latitude);
  const lat2 = toRadians(to.latitude);
  const deltaLat = toRadians(to.latitude - from.latitude);
  const deltaLng = toRadians(to.longitude - from.longitude);

  const a =
    Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(deltaLng / 2) *
      Math.sin(deltaLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

function calculateFinancials(booking) {
  const totalAmount = toNumber(booking.totalAmount);
  const isPrivateHire = booking.serviceType === 'private_hire';
  const platformCommission = isPrivateHire
    ? 0
    : Number((totalAmount * APP_COMMISSION_RATE).toFixed(2));
  const nurseEarning = isPrivateHire
    ? totalAmount
    : Number((totalAmount - platformCommission).toFixed(2));

  return {
    totalAmount,
    platformCommission,
    nurseEarning,
  };
}

function buildBookingRequest(bookingId, booking, nurseId) {
  return {
    id: bookingRequestId(bookingId, nurseId),
    bookingId,
    nurseId,
    patientId: booking.patientId || null,
    patientName: booking.patientName || '',
    patientPhone: booking.patientPhone || '',
    patientLocation: booking.patientLocation || null,
    patientAddress: booking.patientAddress || '',
    serviceType: booking.serviceType || '',
    serviceName: booking.serviceName || '',
    duration: booking.duration || '',
    isInstant: booking.isInstant !== false,
    scheduledTime: booking.scheduledTime || null,
    totalAmount: toNumber(booking.totalAmount),
    nurseEarning: toNumber(booking.nurseEarning),
    status: 'pending',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    respondedAt: null,
  };
}

function stringData(data = {}) {
  return Object.entries(data).reduce((result, [key, value]) => {
    if (value === undefined || value === null) {
      return result;
    }
    result[key] = String(value);
    return result;
  }, {});
}

async function getUserTokens(userId) {
  if (!userId) {
    return [];
  }

  const privateDoc = await db.collection('user_private').doc(userId).get();
  if (!privateDoc.exists) {
    return [];
  }

  const tokens = privateDoc.data().fcmTokens;
  if (!Array.isArray(tokens)) {
    return [];
  }

  return [...new Set(tokens.filter((token) => typeof token === 'string' && token.trim()))];
}

async function sendPushToUsers(userIds, payload) {
  const tokenLists = await Promise.all(userIds.map((userId) => getUserTokens(userId)));
  const tokens = [...new Set(tokenLists.flat())];

  if (!tokens.length) {
    return null;
  }

  return admin.messaging().sendEachForMulticast({
    tokens,
    notification: payload.notification,
    data: stringData(payload.data),
  });
}

async function getCandidateNurses(booking) {
  const nursesSnapshot = await db
    .collection('users')
    .where('role', '==', 'nurse')
    .where('isOnline', '==', true)
    .where('isAvailable', '==', true)
    .where('verified', '==', true)
    .get();

  return nursesSnapshot.docs
    .map((doc) => ({
      id: doc.id,
      distance: distanceMeters(booking.patientLocation, doc.data().currentLocation),
    }))
    .sort((a, b) => a.distance - b.distance)
    .map((item) => item.id);
}

async function expireOpenRequests(bookingId) {
  const openRequests = await db
    .collection('booking_requests')
    .where('bookingId', '==', bookingId)
    .where('status', '==', 'pending')
    .get();

  if (openRequests.empty) {
    return;
  }

  const batch = db.batch();
  openRequests.docs.forEach((doc) => {
    batch.update(doc.ref, {
      status: 'expired',
      updatedAt: serverTimestamp(),
    });
  });
  await batch.commit();
}

exports.onBookingCreated = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snap, context) => {
    const booking = snap.data();
    const bookingId = context.params.bookingId;
    const candidateIds = await getCandidateNurses(booking);

    if (!candidateIds.length) {
      await snap.ref.update({
        dispatchState: 'no_match',
        dispatchCandidateIds: [],
        offeredNurseId: null,
        updatedAt: serverTimestamp(),
      });
      return null;
    }

    const firstNurseId = candidateIds[0];
    const requestRef = db
      .collection('booking_requests')
      .doc(bookingRequestId(bookingId, firstNurseId));

    const batch = db.batch();
    batch.update(snap.ref, {
      dispatchState: 'offered',
      dispatchIndex: 0,
      dispatchCandidateIds: candidateIds,
      offeredNurseId: firstNurseId,
      updatedAt: serverTimestamp(),
    });
    batch.set(requestRef, buildBookingRequest(bookingId, booking, firstNurseId));
    await batch.commit();

    await sendPushToUsers([firstNurseId], {
      notification: {
        title: 'New patient request',
        body: `${booking.serviceName || 'Care service'} is waiting near you.`,
      },
      data: {
        type: 'new_booking_request',
        bookingId,
      },
    });

    return null;
  });

exports.onBookingRequestUpdated = functions.firestore
  .document('booking_requests/{requestId}')
  .onUpdate(async (change) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (beforeData.status === afterData.status || afterData.status !== 'rejected') {
      return null;
    }

    const bookingRef = db.collection('bookings').doc(afterData.bookingId);
    let nextNurseId = null;
    let bookingSnapshot = null;

    await db.runTransaction(async (transaction) => {
      bookingSnapshot = await transaction.get(bookingRef);
      if (!bookingSnapshot.exists) {
        return;
      }

      const booking = bookingSnapshot.data();
      if (booking.status !== 'pending' || booking.offeredNurseId !== afterData.nurseId) {
        return;
      }

      const candidates = Array.isArray(booking.dispatchCandidateIds)
        ? booking.dispatchCandidateIds
        : [];
      const currentIndex = Number(booking.dispatchIndex || 0);
      const nextIndex = currentIndex + 1;

      if (nextIndex >= candidates.length) {
        transaction.update(bookingRef, {
          rejectedNurseIds: FieldValue.arrayUnion(afterData.nurseId),
          dispatchState: 'no_match',
          dispatchIndex: nextIndex,
          offeredNurseId: null,
          updatedAt: serverTimestamp(),
        });
        return;
      }

      nextNurseId = candidates[nextIndex];
      const nextRequestRef = db
        .collection('booking_requests')
        .doc(bookingRequestId(afterData.bookingId, nextNurseId));

      transaction.update(bookingRef, {
        rejectedNurseIds: FieldValue.arrayUnion(afterData.nurseId),
        dispatchState: 'offered',
        dispatchIndex: nextIndex,
        offeredNurseId: nextNurseId,
        updatedAt: serverTimestamp(),
      });
      transaction.set(nextRequestRef, buildBookingRequest(afterData.bookingId, booking, nextNurseId));
    });

    if (nextNurseId && bookingSnapshot?.exists) {
      const booking = bookingSnapshot.data();
      await sendPushToUsers([nextNurseId], {
        notification: {
          title: 'New patient request',
          body: `${booking.serviceName || 'Care service'} is waiting near you.`,
        },
        data: {
          type: 'new_booking_request',
          bookingId: afterData.bookingId,
        },
      });
    }

    return null;
  });

exports.onBookingAccepted = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (beforeData.status === afterData.status || afterData.status !== 'accepted') {
      return null;
    }

    const bookingId = context.params.bookingId;
    const chatRef = db.collection('chatThreads').doc(bookingId);

    await chatRef.set(
      {
        id: bookingId,
        bookingId,
        participantIds: [afterData.patientId, afterData.nurseId].filter(Boolean),
        patientId: afterData.patientId || null,
        nurseId: afterData.nurseId || null,
        lastMessage: '',
        lastMessageSenderId: '',
        lastMessageAt: null,
        unreadCounts: {
          [afterData.patientId]: 0,
          [afterData.nurseId]: 0,
        },
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );

    await Promise.all([
      change.after.ref.set(
        {
          chatThreadId: bookingId,
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      ),
      expireOpenRequests(bookingId),
    ]);

    await sendPushToUsers([afterData.patientId], {
      notification: {
        title: 'Booking accepted',
        body: `${afterData.nurseName || 'A nurse'} is heading to your location.`,
      },
      data: {
        type: 'booking_accepted',
        bookingId,
        threadId: bookingId,
      },
    });

    return null;
  });

exports.onBookingCompleted = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const afterData = change.after.data();

    if (afterData.status !== 'completed' || afterData.financialsProcessedAt) {
      return null;
    }

    const bookingId = context.params.bookingId;
    const bookingRef = change.after.ref;

    await db.runTransaction(async (transaction) => {
      const bookingSnap = await transaction.get(bookingRef);
      if (!bookingSnap.exists) {
        return;
      }

      const booking = bookingSnap.data();
      if (booking.status !== 'completed' || booking.financialsProcessedAt || !booking.nurseId) {
        return;
      }

      const { totalAmount, platformCommission, nurseEarning } =
        calculateFinancials(booking);
      const earningsRef = db.collection('earnings').doc(booking.nurseId);
      const nurseRef = db.collection('users').doc(booking.nurseId);
      const paymentRef = db.collection('payments').doc(bookingId);
      const nurseTransactionRef = earningsRef.collection('transactions').doc(bookingId);
      const adminTransactionRef = db.collection('transactions').doc(bookingId);

      transaction.set(
        earningsRef,
        {
          nurseId: booking.nurseId,
          totalEarnings: FieldValue.increment(nurseEarning),
          withdrawableBalance: FieldValue.increment(nurseEarning),
          totalJobs: FieldValue.increment(1),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
      transaction.set(
        paymentRef,
        {
          id: bookingId,
          bookingId,
          patientId: booking.patientId || null,
          nurseId: booking.nurseId,
          amount: totalAmount,
          platformCommission,
          nurseEarning,
          method: 'internal_hold',
          status: 'settlement_pending',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
      transaction.set(
        nurseTransactionRef,
        {
          id: bookingId,
          type: 'earning',
          amount: nurseEarning,
          bookingId,
          status: 'completed',
          timestamp: serverTimestamp(),
          description: `Earning from ${booking.serviceName || 'service visit'}`,
        },
        { merge: true },
      );
      transaction.set(
        adminTransactionRef,
        {
          id: bookingId,
          bookingId,
          type: 'booking_commission',
          amount: platformCommission,
          nurseId: booking.nurseId,
          patientId: booking.patientId || null,
          timestamp: serverTimestamp(),
        },
        { merge: true },
      );
      transaction.set(
        nurseRef,
        {
          isAvailable: true,
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
      transaction.update(bookingRef, {
        platformCommission,
        nurseEarning,
        paymentStatus: 'settlement_pending',
        financialsProcessedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    return null;
  });

exports.onBookingResolved = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (beforeData.status === afterData.status) {
      return null;
    }

    if (!['cancelled', 'completed'].includes(afterData.status)) {
      return null;
    }

    await expireOpenRequests(afterData.id || change.after.id);

    if (afterData.status === 'cancelled' && afterData.nurseId) {
      await db
        .collection('users')
        .doc(afterData.nurseId)
        .set(
          {
            isAvailable: true,
            updatedAt: serverTimestamp(),
          },
          { merge: true },
        );
    }

    return null;
  });

exports.onBookingRated = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (beforeData.rating != null || afterData.rating == null || !afterData.nurseId) {
      return null;
    }

    const nurseRef = db.collection('users').doc(afterData.nurseId);

    await db.runTransaction(async (transaction) => {
      const nurseSnap = await transaction.get(nurseRef);
      if (!nurseSnap.exists) {
        return;
      }

      const nurse = nurseSnap.data();
      const currentRating = toNumber(nurse.rating);
      const totalRatings = Number(nurse.totalRatings || 0);
      const newTotalRatings = totalRatings + 1;
      const newRating =
        (currentRating * totalRatings + toNumber(afterData.rating)) / newTotalRatings;

      transaction.update(nurseRef, {
        rating: Number(newRating.toFixed(2)),
        totalRatings: newTotalRatings,
        updatedAt: serverTimestamp(),
      });
    });

    return null;
  });

exports.onWithdrawalCreated = functions.firestore
  .document('withdrawals/{withdrawalId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const withdrawalId = context.params.withdrawalId;
    const amount = toNumber(data.amount);
    const nurseId = data.nurseId;
    const earningsRef = db.collection('earnings').doc(nurseId);
    const privateRef = db.collection('user_private').doc(nurseId);
    const withdrawalTransactionRef = earningsRef
      .collection('transactions')
      .doc(`withdrawal_${withdrawalId}`);

    try {
      await db.runTransaction(async (transaction) => {
        const [earningsSnap, privateSnap, freshWithdrawalSnap] = await Promise.all([
          transaction.get(earningsRef),
          transaction.get(privateRef),
          transaction.get(snap.ref),
        ]);

        if (!freshWithdrawalSnap.exists) {
          throw new Error('Withdrawal request not found.');
        }

        const freshWithdrawal = freshWithdrawalSnap.data();
        if (freshWithdrawal.status !== 'pending') {
          return;
        }

        const withdrawableBalance = toNumber(earningsSnap.data()?.withdrawableBalance);
        const bankDetails =
          Object.keys(freshWithdrawal.bankDetails || {}).length > 0
            ? freshWithdrawal.bankDetails
            : privateSnap.data()?.bankDetails || {};

        if (amount <= 0) {
          throw new Error('Invalid withdrawal amount.');
        }
        if (withdrawableBalance < amount) {
          throw new Error('Insufficient withdrawable balance.');
        }
        if (!Object.keys(bankDetails).length) {
          throw new Error('Bank details are required before requesting a payout.');
        }

        transaction.set(
          earningsRef,
          {
            nurseId,
            withdrawableBalance: FieldValue.increment(-amount),
            pendingWithdrawalBalance: FieldValue.increment(amount),
            updatedAt: serverTimestamp(),
          },
          { merge: true },
        );
        transaction.set(
          snap.ref,
          {
            bankDetails,
            payoutMode: 'manual_hold',
            reviewRequired: true,
            updatedAt: serverTimestamp(),
          },
          { merge: true },
        );
        transaction.set(
          withdrawalTransactionRef,
          {
            id: `withdrawal_${withdrawalId}`,
            type: 'withdrawal',
            amount,
            status: 'pending',
            timestamp: serverTimestamp(),
            description: 'Withdrawal request submitted',
          },
          { merge: true },
        );
      });
    } catch (error) {
      await snap.ref.set(
        {
          status: 'failed',
          failureReason: error.message,
          updatedAt: serverTimestamp(),
        },
        { merge: true },
      );
    }

    return null;
  });

exports.onWithdrawalStatusUpdated = functions.firestore
  .document('withdrawals/{withdrawalId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    if (beforeData.status === afterData.status) {
      return null;
    }

    if (!['completed', 'failed'].includes(afterData.status)) {
      return null;
    }

    const withdrawalId = context.params.withdrawalId;
    const amount = toNumber(afterData.amount);
    const nurseId = afterData.nurseId;
    const earningsRef = db.collection('earnings').doc(nurseId);
    const transactionRef = earningsRef
      .collection('transactions')
      .doc(`withdrawal_${withdrawalId}`);

    await db.runTransaction(async (transaction) => {
      const [earningsSnap, withdrawalSnap] = await Promise.all([
        transaction.get(earningsRef),
        transaction.get(change.after.ref),
      ]);

      if (!withdrawalSnap.exists) {
        return;
      }

      const withdrawal = withdrawalSnap.data();
      if (withdrawal.accountingProcessedAt) {
        return;
      }

      if (afterData.status === 'completed') {
        transaction.set(
          earningsRef,
          {
            nurseId,
            pendingWithdrawalBalance: FieldValue.increment(-amount),
            totalWithdrawn: FieldValue.increment(amount),
            updatedAt: serverTimestamp(),
          },
          { merge: true },
        );
        transaction.set(
          transactionRef,
          {
            status: 'completed',
            timestamp: serverTimestamp(),
            description: 'Withdrawal completed',
          },
          { merge: true },
        );
        transaction.update(change.after.ref, {
          completedAt: serverTimestamp(),
          accountingProcessedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
        return;
      }

      if (afterData.status === 'failed') {
        transaction.set(
          earningsRef,
          {
            nurseId,
            withdrawableBalance: FieldValue.increment(amount),
            pendingWithdrawalBalance: FieldValue.increment(-amount),
            updatedAt: serverTimestamp(),
          },
          { merge: true },
        );
        transaction.set(
          transactionRef,
          {
            status: 'failed',
            timestamp: serverTimestamp(),
            description: 'Withdrawal failed and balance restored',
          },
          { merge: true },
        );
        transaction.update(change.after.ref, {
          accountingProcessedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
      }
    });

    return null;
  });

exports.onChatMessageCreated = functions.firestore
  .document('chatThreads/{threadId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const threadRef = db.collection('chatThreads').doc(context.params.threadId);
    const threadSnap = await threadRef.get();

    if (!threadSnap.exists) {
      return null;
    }

    const thread = threadSnap.data();
    const participantIds = Array.isArray(thread.participantIds)
      ? thread.participantIds.filter(Boolean)
      : [];
    const unreadCounts = { ...(thread.unreadCounts || {}) };

    participantIds.forEach((participantId) => {
      if (participantId === message.senderId) {
        unreadCounts[participantId] = 0;
      } else {
        unreadCounts[participantId] = Number(unreadCounts[participantId] || 0) + 1;
      }
    });

    await threadRef.set(
      {
        lastMessage: (message.text || '').slice(0, 160),
        lastMessageSenderId: message.senderId || '',
        lastMessageAt: serverTimestamp(),
        unreadCounts,
        updatedAt: serverTimestamp(),
      },
      { merge: true },
    );

    const recipients = participantIds.filter((participantId) => participantId !== message.senderId);
    await sendPushToUsers(recipients, {
      notification: {
        title: message.senderName || 'New message',
        body: (message.text || 'Sent you a message').slice(0, 120),
      },
      data: {
        type: 'chat_message',
        bookingId: message.bookingId,
        threadId: context.params.threadId,
      },
    });

    return null;
  });
