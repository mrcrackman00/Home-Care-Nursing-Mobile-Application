import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
} from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-auth.js';
import {
  collection,
  doc,
  getDoc,
  getFirestore,
  increment,
  onSnapshot,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';

const firebaseConfig = {
  apiKey: 'AIzaSyBOatncA5uBoI2XCv-9fVTnsim_l2zIzK0',
  authDomain: 'home-care-nursing-e733e.firebaseapp.com',
  projectId: 'home-care-nursing-e733e',
  storageBucket: 'home-care-nursing-e733e.firebasestorage.app',
  messagingSenderId: '1069702495258',
  appId: '1:1069702495258:web:e651e83ad9d7901a1825a3',
  measurementId: 'G-B2RR7NXH4R',
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const state = {
  patients: [],
  nurses: [],
  bookings: [],
  payments: [],
  withdrawals: [],
};

const unsubscribers = [];

const loginShell = document.getElementById('admin-login-shell');
const adminApp = document.getElementById('admin-app');
const loginForm = document.getElementById('admin-login-form');
const loginButton = document.getElementById('admin-login-button');
const loginError = document.getElementById('admin-login-error');
const signoutButton = document.getElementById('admin-signout');
const adminName = document.getElementById('admin-name');
const adminAvatar = document.getElementById('admin-avatar');
const adminStatus = document.getElementById('admin-status');
const bookingFilter = document.getElementById('booking-filter');
const searchUsersInput = document.getElementById('search-users');
const searchNursesInput = document.getElementById('search-nurses');
const opsBanner = document.getElementById('ops-banner');

function showPage(pageId) {
  document.querySelectorAll('.page').forEach((page) => page.classList.remove('active'));
  const page = document.getElementById(`page-${pageId}`);
  if (page) {
    page.classList.add('active');
  }

  document.querySelectorAll('.nav-item').forEach((item) => item.classList.remove('active'));
  const navItem = document.querySelector(`.nav-item[data-page="${pageId}"]`);
  if (navItem) {
    navItem.classList.add('active');
  }

  const titles = {
    dashboard: 'Dashboard',
    users: 'Users Management',
    nurses: 'Nurses Management',
    bookings: 'Bookings Management',
    payments: 'Payment History',
    withdrawals: 'Withdrawal Requests',
    pricing: 'Pricing Control',
    analytics: 'Analytics',
  };
  document.getElementById('page-title').textContent = titles[pageId] || pageId;
  document.getElementById('sidebar').classList.remove('open');
}

function toggleSidebar() {
  document.getElementById('sidebar').classList.toggle('open');
}

window.showPage = showPage;
window.toggleSidebar = toggleSidebar;
window.toggleNurseVerification = toggleNurseVerification;
window.offerNearestNurse = offerNearestNurse;
window.settleBooking = settleBooking;
window.approveWithdrawal = approveWithdrawal;
window.rejectWithdrawal = rejectWithdrawal;

function clearSubscriptions() {
  while (unsubscribers.length) {
    const unsubscribe = unsubscribers.pop();
    unsubscribe?.();
  }
}

function toDate(value) {
  if (!value) {
    return null;
  }
  if (typeof value.toDate === 'function') {
    return value.toDate();
  }
  if (typeof value.seconds === 'number') {
    return new Date(value.seconds * 1000);
  }
  return new Date(value);
}

function formatCurrency(amount) {
  const value = Number(amount || 0);
  return `₹${value.toLocaleString('en-IN', {
    maximumFractionDigits: 0,
  })}`;
}

function formatDate(value) {
  const date = toDate(value);
  if (!date) {
    return 'Just now';
  }

  return new Intl.DateTimeFormat('en-IN', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
}

function escapeHtml(value = '') {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function toNumber(value) {
  return Number(value || 0);
}

function showActionMessage(message, tone = 'info') {
  if (!opsBanner) {
    return;
  }

  opsBanner.textContent = message;
  opsBanner.className = `ops-banner ${tone}`;
  opsBanner.classList.remove('hidden');

  clearTimeout(showActionMessage._timeout);
  showActionMessage._timeout = setTimeout(() => {
    opsBanner.classList.add('hidden');
  }, 5000);
}

function distanceMeters(from, to) {
  if (!from || !to) {
    return Number.MAX_SAFE_INTEGER;
  }

  const toRadians = (value) => (value * Math.PI) / 180;
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

function platformCommissionForBooking(booking) {
  if (booking.serviceType === 'private_hire') {
    return 0;
  }

  const explicit = Number(booking.platformCommission);
  if (!Number.isNaN(explicit) && explicit > 0) {
    return explicit;
  }

  return Number((toNumber(booking.totalAmount) * 0.2).toFixed(2));
}

function nurseEarningForBooking(booking) {
  const explicit = Number(booking.nurseEarning);
  if (!Number.isNaN(explicit) && explicit > 0) {
    return explicit;
  }

  return Number(
    (toNumber(booking.totalAmount) - platformCommissionForBooking(booking)).toFixed(2),
  );
}

function bookingRequestPayload(booking, nurseId) {
  return {
    id: `${booking.id}_${nurseId}`,
    bookingId: booking.id,
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
    nurseEarning: nurseEarningForBooking(booking),
    status: 'pending',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    respondedAt: null,
  };
}

function pickNearestAvailableNurse(booking) {
  const rejectedNurseIds = Array.isArray(booking.rejectedNurseIds)
    ? booking.rejectedNurseIds
    : [];

  const candidates = state.nurses
    .filter((nurse) =>
      nurse.verified &&
      nurse.isOnline &&
      nurse.isAvailable &&
      nurse.currentLocation &&
      !rejectedNurseIds.includes(nurse.id),
    )
    .map((nurse) => ({
      nurse,
      distance: distanceMeters(booking.patientLocation, nurse.currentLocation),
    }))
    .sort((a, b) => a.distance - b.distance);

  return candidates[0]?.nurse || null;
}

function setAuthenticatedView(enabled) {
  loginShell.classList.toggle('hidden', enabled);
  adminApp.classList.toggle('hidden', !enabled);
}

function renderStats() {
  const totalRevenue = state.payments.reduce(
    (sum, item) => sum + Number(item.amount || 0),
    0,
  );
  const totalCommission = state.payments.reduce(
    (sum, item) => sum + Number(item.platformCommission || item.commission || 0),
    0,
  );
  const completedBookings = state.bookings.filter(
    (booking) => booking.status === 'completed',
  ).length;

  document.getElementById('stat-patients').textContent = state.patients.length.toLocaleString('en-IN');
  document.getElementById('stat-nurses').textContent = state.nurses.length.toLocaleString('en-IN');
  document.getElementById('stat-bookings').textContent = state.bookings.length.toLocaleString('en-IN');
  document.getElementById('stat-completed').textContent = completedBookings.toLocaleString('en-IN');
  document.getElementById('stat-revenue').textContent = formatCurrency(totalRevenue);
  document.getElementById('stat-commission').textContent = formatCurrency(totalCommission);

  document.getElementById('analytics-revenue').textContent = formatCurrency(totalRevenue);
  document.getElementById('analytics-profit').textContent = formatCurrency(totalCommission);
  document.getElementById('analytics-users').textContent = (
    state.patients.length + state.nurses.length
  ).toLocaleString('en-IN');
}

function renderUsers() {
  const term = searchUsersInput.value.trim().toLowerCase();
  const rows = state.patients
    .filter((user) => {
      if (!term) {
        return true;
      }
      return [user.name, user.email, user.phone]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(term));
    })
    .sort((a, b) => (toDate(b.createdAt)?.getTime() || 0) - (toDate(a.createdAt)?.getTime() || 0))
    .map((user) => `
      <tr>
        <td>${escapeHtml(user.name || 'Patient')}</td>
        <td>${escapeHtml(user.phone || '-')}</td>
        <td>${escapeHtml(user.email || '-')}</td>
        <td>${escapeHtml(user.address || 'No address')}</td>
        <td>${formatDate(user.createdAt)}</td>
      </tr>
    `)
    .join('');

  document.getElementById('users-list').innerHTML = rows
    ? tableMarkup(['Name', 'Phone', 'Email', 'Address', 'Joined'], rows)
    : emptyState('No patient records found for the current search.');
}

function renderNurses() {
  const term = searchNursesInput.value.trim().toLowerCase();
  const rows = state.nurses
    .filter((nurse) => {
      if (!term) {
        return true;
      }
      return [nurse.name, nurse.email, nurse.phone]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(term));
    })
    .sort((a, b) => (toDate(b.createdAt)?.getTime() || 0) - (toDate(a.createdAt)?.getTime() || 0))
    .map((nurse) => `
      <tr>
        <td>${escapeHtml(nurse.name || 'Nurse')}</td>
        <td>${escapeHtml(nurse.phone || '-')}</td>
        <td>${escapeHtml(nurse.specializations?.join(', ') || 'General care')}</td>
        <td>${nurse.verified ? '<span class="status-badge success">Verified</span>' : '<span class="status-badge warning">Pending</span>'}</td>
        <td>${nurse.isOnline ? '<span class="status-badge info">Online</span>' : '<span class="status-badge muted">Offline</span>'}</td>
        <td>${typeof nurse.rating === 'number' ? nurse.rating.toFixed(1) : '0.0'}</td>
        <td>
          <div class="action-row">
            <button class="btn ${nurse.verified ? 'btn-danger' : 'btn-success'}" onclick="toggleNurseVerification('${escapeHtml(nurse.id)}', ${!nurse.verified})">
              ${nurse.verified ? 'Unverify' : 'Verify'}
            </button>
          </div>
        </td>
      </tr>
    `)
    .join('');

  document.getElementById('nurses-list').innerHTML = rows
    ? tableMarkup(['Name', 'Phone', 'Specialization', 'Verification', 'Live Status', 'Rating', 'Actions'], rows)
    : emptyState('No nurse records found for the current search.');
}

function renderBookings() {
  const filterValue = bookingFilter.value;
  const rows = state.bookings
    .filter((booking) => filterValue === 'all' || booking.status === filterValue)
    .sort((a, b) => (toDate(b.createdAt)?.getTime() || 0) - (toDate(a.createdAt)?.getTime() || 0))
    .map((booking) => {
      const actions = [];
      if (booking.status === 'pending' && !booking.nurseId) {
        actions.push(
          `<button class="btn btn-secondary" onclick="offerNearestNurse('${escapeHtml(booking.id)}')">Offer nearest</button>`,
        );
      }
      if (booking.status === 'completed' && booking.paymentStatus !== 'manual_settled') {
        actions.push(
          `<button class="btn btn-success" onclick="settleBooking('${escapeHtml(booking.id)}')">Settle</button>`,
        );
      }

      return `
      <tr>
        <td>${escapeHtml(booking.serviceName || 'Service')}</td>
        <td>${escapeHtml(booking.patientName || 'Patient')}</td>
        <td>${escapeHtml(booking.nurseName || 'Awaiting assignment')}</td>
        <td>${formatCurrency(booking.totalAmount || 0)}</td>
        <td><span class="status-badge ${badgeClass(booking.status)}">${escapeHtml((booking.status || 'pending').replaceAll('_', ' '))}</span></td>
        <td>${formatDate(booking.createdAt)}</td>
        <td>
          ${actions.length ? `<div class="action-row">${actions.join('')}</div>` : '<span class="status-badge muted">No action</span>'}
        </td>
      </tr>
    `;
    })
    .join('');

  document.getElementById('bookings-list').innerHTML = rows
    ? tableMarkup(['Service', 'Patient', 'Nurse', 'Amount', 'Status', 'Created', 'Actions'], rows)
    : emptyState('No bookings match the selected filter.');
}

function renderRecentBookings() {
  const rows = state.bookings
    .slice()
    .sort((a, b) => (toDate(b.createdAt)?.getTime() || 0) - (toDate(a.createdAt)?.getTime() || 0))
    .slice(0, 6)
    .map((booking) => `
      <tr>
        <td>${escapeHtml(booking.patientName || 'Patient')}</td>
        <td>${escapeHtml(booking.serviceName || 'Service')}</td>
        <td>${escapeHtml(booking.nurseName || 'Searching')}</td>
        <td><span class="status-badge ${badgeClass(booking.status)}">${escapeHtml((booking.status || 'pending').replaceAll('_', ' '))}</span></td>
        <td>${formatCurrency(booking.totalAmount || 0)}</td>
      </tr>
    `)
    .join('');

  document.getElementById('recent-bookings').innerHTML = rows
    ? tableMarkup(['Patient', 'Service', 'Nurse', 'Status', 'Amount'], rows)
    : emptyState('Bookings will appear here once patients start placing orders.');
}

function renderPayments() {
  const rows = state.payments
    .slice()
    .sort((a, b) => (toDate(b.createdAt || b.timestamp)?.getTime() || 0) - (toDate(a.createdAt || a.timestamp)?.getTime() || 0))
    .map((payment) => `
      <tr>
        <td>${escapeHtml(payment.bookingId || '-')}</td>
        <td>${formatCurrency(payment.amount || 0)}</td>
        <td>${formatCurrency(payment.nurseEarning || 0)}</td>
        <td>${formatCurrency(payment.platformCommission || payment.commission || 0)}</td>
        <td><span class="status-badge ${badgeClass(payment.status)}">${escapeHtml(payment.status || 'pending')}</span></td>
        <td>${formatDate(payment.createdAt || payment.timestamp)}</td>
      </tr>
    `)
    .join('');

  document.getElementById('payments-list').innerHTML = rows
    ? tableMarkup(['Booking', 'Amount', 'Nurse Share', 'Commission', 'Status', 'Recorded'], rows)
    : emptyState('Payment records will appear here after completed services.');
}

function renderWithdrawals() {
  const rows = state.withdrawals
    .slice()
    .sort((a, b) => (toDate(b.requestedAt)?.getTime() || 0) - (toDate(a.requestedAt)?.getTime() || 0))
    .map((withdrawal) => {
      const actions = withdrawal.status === 'pending'
        ? `
          <div class="action-row">
            <button class="btn btn-success" onclick="approveWithdrawal('${escapeHtml(withdrawal.id)}')">Approve</button>
            <button class="btn btn-danger" onclick="rejectWithdrawal('${escapeHtml(withdrawal.id)}')">Reject</button>
          </div>
        `
        : '<span class="status-badge muted">No action</span>';

      return `
      <tr>
        <td>${escapeHtml(withdrawal.nurseId || '-')}</td>
        <td>${formatCurrency(withdrawal.amount || 0)}</td>
        <td><span class="status-badge ${badgeClass(withdrawal.status)}">${escapeHtml(withdrawal.status || 'pending')}</span></td>
        <td>${escapeHtml(withdrawal.payoutMode || 'manual_hold')}</td>
        <td>${formatDate(withdrawal.requestedAt)}</td>
        <td>${actions}</td>
      </tr>
    `;
    })
    .join('');

  document.getElementById('withdrawals-list').innerHTML = rows
    ? tableMarkup(['Nurse', 'Amount', 'Status', 'Payout Mode', 'Requested', 'Actions'], rows)
    : emptyState('Withdrawal requests will appear here once nurses request a payout.');
}

function tableMarkup(headers, rows) {
  return `
    <table>
      <thead>
        <tr>${headers.map((header) => `<th>${escapeHtml(header)}</th>`).join('')}</tr>
      </thead>
      <tbody>${rows}</tbody>
    </table>
  `;
}

function emptyState(text) {
  return `<p class="empty-state">${escapeHtml(text)}</p>`;
}

function badgeClass(status = '') {
  switch (status) {
    case 'completed':
    case 'manual_settled':
    case 'verified':
    case 'success':
      return 'success';
    case 'accepted':
    case 'in_progress':
    case 'processing':
      return 'info';
    case 'pending':
    case 'settlement_pending':
    case 'pending_review':
      return 'warning';
    case 'cancelled':
    case 'failed':
    case 'rejected':
      return 'danger';
    default:
      return 'muted';
  }
}

async function toggleNurseVerification(nurseId, nextValue) {
  try {
    await updateDoc(doc(db, 'users', nurseId), {
      verified: nextValue,
      updatedAt: serverTimestamp(),
    });
    showActionMessage(
      nextValue ? 'Nurse verified successfully.' : 'Nurse moved back to pending review.',
      'success',
    );
  } catch (error) {
    showActionMessage(error.message || 'Unable to update nurse verification.', 'error');
  }
}

async function offerNearestNurse(bookingId) {
  const booking = state.bookings.find((item) => item.id === bookingId);
  if (!booking) {
    showActionMessage('Booking not found.', 'error');
    return;
  }

  const nurse = pickNearestAvailableNurse(booking);
  if (!nurse) {
    showActionMessage('No verified online nurse is available right now.', 'error');
    return;
  }

  try {
    await setDoc(
      doc(db, 'booking_requests', `${bookingId}_${nurse.id}`),
      bookingRequestPayload(booking, nurse.id),
    );
    await updateDoc(doc(db, 'bookings', bookingId), {
      dispatchState: 'manually_offered',
      offeredNurseId: nurse.id,
      preferredNurseId: nurse.id,
      updatedAt: serverTimestamp(),
    });
    showActionMessage(`Booking offered to ${nurse.name || 'the nearest nurse'}.`, 'success');
  } catch (error) {
    showActionMessage(error.message || 'Unable to offer this booking.', 'error');
  }
}

async function settleBooking(bookingId) {
  try {
    await runTransaction(db, async (transaction) => {
      const bookingRef = doc(db, 'bookings', bookingId);
      const bookingSnap = await transaction.get(bookingRef);

      if (!bookingSnap.exists()) {
        throw new Error('Booking not found.');
      }

      const booking = { id: bookingSnap.id, ...bookingSnap.data() };
      if (booking.status !== 'completed') {
        throw new Error('Only completed bookings can be settled.');
      }
      if (!booking.nurseId) {
        throw new Error('Assign a nurse before settling this booking.');
      }
      if (booking.paymentStatus === 'manual_settled') {
        throw new Error('This booking has already been settled.');
      }

      const amount = toNumber(booking.totalAmount);
      const platformCommission = platformCommissionForBooking(booking);
      const nurseEarning = nurseEarningForBooking(booking);
      const earningsRef = doc(db, 'earnings', booking.nurseId);
      const paymentRef = doc(db, 'payments', bookingId);
      const adminTransactionRef = doc(db, 'transactions', bookingId);
      const nurseTransactionRef = doc(
        db,
        'earnings',
        booking.nurseId,
        'transactions',
        bookingId,
      );
      const nurseRef = doc(db, 'users', booking.nurseId);

      transaction.set(
        earningsRef,
        {
          nurseId: booking.nurseId,
          totalEarnings: increment(nurseEarning),
          withdrawableBalance: increment(nurseEarning),
          totalJobs: increment(1),
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
          amount,
          platformCommission,
          nurseEarning,
          method: 'manual_admin_settlement',
          status: 'completed',
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
          description: `Manual settlement for ${booking.serviceName || 'service visit'}`,
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
        paymentStatus: 'manual_settled',
        settledAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    showActionMessage('Booking settled and nurse earnings updated.', 'success');
  } catch (error) {
    showActionMessage(error.message || 'Unable to settle this booking.', 'error');
  }
}

async function approveWithdrawal(withdrawalId) {
  try {
    await runTransaction(db, async (transaction) => {
      const withdrawalRef = doc(db, 'withdrawals', withdrawalId);
      const withdrawalSnap = await transaction.get(withdrawalRef);

      if (!withdrawalSnap.exists()) {
        throw new Error('Withdrawal request not found.');
      }

      const withdrawal = { id: withdrawalSnap.id, ...withdrawalSnap.data() };
      if (withdrawal.status !== 'pending') {
        throw new Error('Only pending withdrawals can be approved.');
      }

      const earningsRef = doc(db, 'earnings', withdrawal.nurseId);
      const earningsSnap = await transaction.get(earningsRef);
      const availableBalance = toNumber(earningsSnap.data()?.withdrawableBalance);
      const amount = toNumber(withdrawal.amount);

      if (availableBalance < amount) {
        throw new Error('Insufficient withdrawable balance for this payout.');
      }

      const withdrawalTransactionRef = doc(
        db,
        'earnings',
        withdrawal.nurseId,
        'transactions',
        `withdrawal_${withdrawalId}`,
      );

      transaction.set(
        earningsRef,
        {
          nurseId: withdrawal.nurseId,
          withdrawableBalance: increment(-amount),
          totalWithdrawn: increment(amount),
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
          status: 'completed',
          timestamp: serverTimestamp(),
          description: 'Manual payout approved by admin',
        },
        { merge: true },
      );
      transaction.update(withdrawalRef, {
        status: 'completed',
        payoutMode: 'manual_admin',
        completedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    });

    showActionMessage('Withdrawal approved and balance updated.', 'success');
  } catch (error) {
    showActionMessage(error.message || 'Unable to approve withdrawal.', 'error');
  }
}

async function rejectWithdrawal(withdrawalId) {
  try {
    await updateDoc(doc(db, 'withdrawals', withdrawalId), {
      status: 'failed',
      failureReason: 'Rejected by admin review',
      updatedAt: serverTimestamp(),
    });
    showActionMessage('Withdrawal request rejected.', 'success');
  } catch (error) {
    showActionMessage(error.message || 'Unable to reject withdrawal.', 'error');
  }
}

function subscribeToLiveData() {
  clearSubscriptions();

  unsubscribers.push(
    onSnapshot(query(collection(db, 'users'), where('role', '==', 'patient')), (snapshot) => {
      state.patients = snapshot.docs.map((docSnap) => ({ id: docSnap.id, ...docSnap.data() }));
      renderUsers();
      renderStats();
    }),
  );

  unsubscribers.push(
    onSnapshot(query(collection(db, 'users'), where('role', '==', 'nurse')), (snapshot) => {
      state.nurses = snapshot.docs.map((docSnap) => ({ id: docSnap.id, ...docSnap.data() }));
      renderNurses();
      renderStats();
    }),
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'bookings'), (snapshot) => {
      state.bookings = snapshot.docs.map((docSnap) => ({ id: docSnap.id, ...docSnap.data() }));
      renderBookings();
      renderRecentBookings();
      renderStats();
    }),
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'payments'), (snapshot) => {
      state.payments = snapshot.docs.map((docSnap) => ({ id: docSnap.id, ...docSnap.data() }));
      renderPayments();
      renderStats();
    }),
  );

  unsubscribers.push(
    onSnapshot(collection(db, 'withdrawals'), (snapshot) => {
      state.withdrawals = snapshot.docs.map((docSnap) => ({ id: docSnap.id, ...docSnap.data() }));
      renderWithdrawals();
    }),
  );
}

async function handleAuthenticatedUser(user) {
  const profileRef = doc(db, 'users', user.uid);
  const profileSnap = await getDoc(profileRef);

  if (!profileSnap.exists() || profileSnap.data().role !== 'admin') {
    loginError.textContent = 'This account is not authorized for admin access.';
    await signOut(auth);
    return;
  }

  loginError.textContent = '';
  adminName.textContent = profileSnap.data().name || user.email || 'Admin';
  adminAvatar.textContent = (profileSnap.data().name || user.email || 'A')
    .trim()
    .charAt(0)
    .toUpperCase();
  adminStatus.textContent = `Signed in as ${user.email || 'admin user'}`;
  setAuthenticatedView(true);
  subscribeToLiveData();
  showPage('dashboard');
}

loginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  loginError.textContent = '';
  loginButton.disabled = true;
  loginButton.textContent = 'Signing In...';

  const email = document.getElementById('admin-email').value.trim();
  const password = document.getElementById('admin-password').value;

  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (error) {
    loginError.textContent = error.message || 'Unable to sign in.';
  } finally {
    loginButton.disabled = false;
    loginButton.textContent = 'Sign In';
  }
});

signoutButton.addEventListener('click', async () => {
  await signOut(auth);
});

searchUsersInput.addEventListener('input', renderUsers);
searchNursesInput.addEventListener('input', renderNurses);
bookingFilter.addEventListener('change', renderBookings);

onAuthStateChanged(auth, async (user) => {
  clearSubscriptions();

  if (!user) {
    setAuthenticatedView(false);
    adminStatus.textContent = 'Authenticated admin access';
    return;
  }

  try {
    await handleAuthenticatedUser(user);
  } catch (error) {
    loginError.textContent = error.message || 'Unable to load admin profile.';
    await signOut(auth);
  }
});
