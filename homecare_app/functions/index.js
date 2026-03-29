const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// 20% App Commission
const APP_COMMISSION_PERCENTAGE = 0.20;

exports.onBookingCompleted = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if the booking status changed to 'completed'
    if (beforeData.status !== 'completed' && afterData.status === 'completed') {
      const nurseId = afterData.nurseId;
      const totalAmount = afterData.totalAmount || 0;
      const commission = totalAmount * APP_COMMISSION_PERCENTAGE;
      const nurseEarning = totalAmount - commission;

      console.log(`Booking completed: ${context.params.bookingId}, Total: ₹${totalAmount}, Nurse Gets: ₹${nurseEarning}, Commission: ₹${commission}`);

      try {
        const batch = db.batch();

        // 1. Update Booking with exact financial breakdown
        const bookingRef = db.collection('bookings').doc(context.params.bookingId);
        batch.update(bookingRef, {
          appCommission: commission,
          nurseEarning: nurseEarning,
          paymentStatus: 'pending_settlement',
          completedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        // 2. Add Transaction Record for the App/Admin
        const transactionRef = db.collection('transactions').doc();
        batch.set(transactionRef, {
          bookingId: context.params.bookingId,
          type: 'booking_commission',
          amount: commission,
          nurseId: nurseId,
          patientId: afterData.patientId,
          timestamp: admin.firestore.FieldValue.serverTimestamp()
        });

        // 3. Update Nurse's Total Earnings in their User Document
        const nurseRef = db.collection('users').doc(nurseId);
        batch.update(nurseRef, {
          'earnings.totalWithdrawable': admin.firestore.FieldValue.increment(nurseEarning),
          'earnings.totalEarned': admin.firestore.FieldValue.increment(nurseEarning),
          'earnings.totalBookings': admin.firestore.FieldValue.increment(1)
        });

        await batch.commit();
        console.log('Successfully completed financial breakdown for booking.');
      } catch (error) {
        console.error('Error updating financial records:', error);
      }
    }
    return null;
  });

// Handle Nurse Withdrawal Requests
exports.requestWithdrawal = functions.firestore
  .document('withdrawals/{withdrawalId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const nurseId = data.nurseId;
    const amount = data.amount || 0;

    const nurseRef = db.collection('users').doc(nurseId);
    
    try {
      await db.runTransaction(async (transaction) => {
        const nurseDoc = await transaction.get(nurseRef);
        if (!nurseDoc.exists) {
          throw new Error('Nurse does not exist!');
        }

        const currentWithdrawable = nurseDoc.data().earnings?.totalWithdrawable || 0;
        
        if (currentWithdrawable < amount) {
          throw new Error('Insufficient funds!');
        }

        // Deduct from withdrawable balance
        transaction.update(nurseRef, {
          'earnings.totalWithdrawable': admin.firestore.FieldValue.increment(-amount),
          'earnings.pendingWithdrawal': admin.firestore.FieldValue.increment(amount)
        });
        
        // Update request status
        transaction.update(snap.ref, {
          status: 'pending',
          processedAt: null
        });
      });
      console.log(`Withdrawal request ${context.params.withdrawalId} processed successfully.`);
    } catch (error) {
      console.error('Transaction failure:', error);
      // Mark withdrawal as failed
      await snap.ref.update({
        status: 'failed',
        error: error.message
      });
    }
  });
