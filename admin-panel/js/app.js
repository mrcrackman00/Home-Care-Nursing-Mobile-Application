// ====== PAGE NAVIGATION ======
function showPage(pageId) {
  // Hide all pages
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  
  // Show selected page
  const page = document.getElementById(`page-${pageId}`);
  if (page) page.classList.add('active');

  // Update nav
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  const navItem = document.querySelector(`.nav-item[data-page="${pageId}"]`);
  if (navItem) navItem.classList.add('active');

  // Update title
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

  // Close sidebar on mobile
  document.getElementById('sidebar').classList.remove('open');
}

// ====== SIDEBAR TOGGLE ======
function toggleSidebar() {
  document.getElementById('sidebar').classList.toggle('open');
}

// ====== DEMO DATA ======
// This populates the dashboard with sample data
// Replace with Firebase integration when connected

function loadDemoData() {
  // Stats
  animateCounter('stat-patients', 156);
  animateCounter('stat-nurses', 42);
  animateCounter('stat-bookings', 893);
  animateCounter('stat-completed', 761);
  document.getElementById('stat-revenue').textContent = '₹8,93,000';
  document.getElementById('stat-commission').textContent = '₹1,78,600';
  
  // Analytics
  document.getElementById('analytics-revenue').textContent = '₹8,93,000';
  document.getElementById('analytics-profit').textContent = '₹1,78,600';
  document.getElementById('analytics-users').textContent = '198';
}

function animateCounter(id, target) {
  const el = document.getElementById(id);
  let current = 0;
  const step = Math.ceil(target / 30);
  const interval = setInterval(() => {
    current += step;
    if (current >= target) {
      current = target;
      clearInterval(interval);
    }
    el.textContent = current.toLocaleString('en-IN');
  }, 30);
}

// ====== FIREBASE INTEGRATION ======
// Uncomment and configure when Firebase is connected
/*
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-app.js';
import { getFirestore, collection, getDocs, query, where, onSnapshot } from 'https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore.js';

const firebaseConfig = {
  // Your Firebase config here
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

async function loadFirebaseData() {
  // Load patients
  const usersSnap = await getDocs(query(collection(db, 'users'), where('role', '==', 'patient')));
  document.getElementById('stat-patients').textContent = usersSnap.size;

  // Load nurses
  const nursesSnap = await getDocs(query(collection(db, 'users'), where('role', '==', 'nurse')));
  document.getElementById('stat-nurses').textContent = nursesSnap.size;

  // Load bookings
  const bookingsSnap = await getDocs(collection(db, 'bookings'));
  document.getElementById('stat-bookings').textContent = bookingsSnap.size;
  
  const completedSnap = await getDocs(query(collection(db, 'bookings'), where('status', '==', 'completed')));
  document.getElementById('stat-completed').textContent = completedSnap.size;

  // Load payments
  const paymentsSnap = await getDocs(collection(db, 'payments'));
  let totalRevenue = 0, totalCommission = 0;
  paymentsSnap.forEach(doc => {
    totalRevenue += doc.data().amount || 0;
    totalCommission += doc.data().commission || 0;
  });
  document.getElementById('stat-revenue').textContent = `₹${totalRevenue.toLocaleString('en-IN')}`;
  document.getElementById('stat-commission').textContent = `₹${totalCommission.toLocaleString('en-IN')}`;
}
*/

// ====== INIT ======
document.addEventListener('DOMContentLoaded', () => {
  loadDemoData();
});
