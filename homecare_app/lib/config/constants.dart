class AppConstants {
  // App Info
  static const String appName = 'HomeCare';
  static const String appTagline = 'Quality Nursing at Your Doorstep';
  static const double defaultCommissionPercent = 20.0;

  // Commission Model
  static double calculateCommission(double totalAmount) {
    return totalAmount * (defaultCommissionPercent / 100);
  }

  static double calculateNurseEarning(double totalAmount) {
    return totalAmount - calculateCommission(totalAmount);
  }

  // Service Types
  static const List<Map<String, dynamic>> serviceTypes = [
    {
      'id': 'injection',
      'name': 'Injection',
      'icon': 'medical_services',
      'description': 'Single injection visit',
      'basePrice': 200,
      'maxPrice': 500,
      'duration': '30 mins',
      'emoji': '💉',
    },
    {
      'id': 'basic_visit',
      'name': 'Basic Nurse Visit',
      'icon': 'healing',
      'description': 'Basic checkup and care',
      'basePrice': 500,
      'maxPrice': 800,
      'duration': '1-2 hours',
      'emoji': '🩺',
    },
    {
      'id': 'basic_care',
      'name': 'Basic Care (8-12 hr)',
      'icon': 'favorite',
      'description': 'Normal patient care for 8-12 hours',
      'basePrice': 800,
      'maxPrice': 1500,
      'duration': '8-12 hours',
      'emoji': '❤️',
    },
    {
      'id': 'elder_care',
      'name': 'Elder Care',
      'icon': 'elderly',
      'description': 'Specialized care for elderly patients',
      'basePrice': 1000,
      'maxPrice': 2000,
      'duration': '8-12 hours',
      'emoji': '👴',
    },
    {
      'id': 'full_day',
      'name': 'Full Day (24 hr)',
      'icon': 'access_time_filled',
      'description': 'Live-in nurse for 24 hours',
      'basePrice': 1500,
      'maxPrice': 3500,
      'duration': '24 hours',
      'emoji': '🏥',
    },
    {
      'id': 'icu_skilled',
      'name': 'ICU / Skilled Nurse',
      'icon': 'monitor_heart',
      'description': 'Highly skilled nurse for critical care',
      'basePrice': 3000,
      'maxPrice': 6000,
      'duration': '12-24 hours',
      'emoji': '🫀',
    },
    {
      'id': 'monthly_basic',
      'name': 'Monthly Basic',
      'icon': 'calendar_month',
      'description': 'Monthly nursing care package',
      'basePrice': 20000,
      'maxPrice': 35000,
      'duration': '30 days',
      'emoji': '📅',
    },
    {
      'id': 'private_hire',
      'name': 'Private Direct Hire',
      'icon': 'person_pin',
      'description': 'Direct hire - No commission',
      'basePrice': 40000,
      'maxPrice': 65000,
      'duration': '30 days',
      'emoji': '👩‍⚕️',
      'noCommission': true,
    },
  ];

  // Price Chart for display
  static const List<Map<String, dynamic>> priceChart = [
    {
      'service': 'Basic Care (8-12 hr)',
      'patientPays': '₹800 – ₹1,500',
      'nurseGets': '₹640 – ₹1,200',
      'commission': '20%',
    },
    {
      'service': 'Full Day (24 hr)',
      'patientPays': '₹1,500 – ₹3,500',
      'nurseGets': '₹1,200 – ₹2,800',
      'commission': '20%',
    },
    {
      'service': 'Monthly Basic',
      'patientPays': '₹20,000 – ₹35,000',
      'nurseGets': '₹16,000 – ₹28,000',
      'commission': '20%',
    },
    {
      'service': 'ICU / Skilled',
      'patientPays': '₹3,000 – ₹6,000',
      'nurseGets': '₹2,400 – ₹4,800',
      'commission': '20%',
    },
    {
      'service': 'Private Direct Hire',
      'patientPays': '₹40,000 – ₹65,000',
      'nurseGets': 'Same amount',
      'commission': '0%',
    },
  ];

  // Booking Status
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusCancelled = 'cancelled';

  // User Roles
  static const String rolePatient = 'patient';
  static const String roleNurse = 'nurse';
  static const String roleAdmin = 'admin';

  // Nearby Radius (in meters)
  static const double nearbyRadiusMeters = 5000; // 5km

  // Razorpay Test Key (replace with live)
  static const String razorpayKeyId = 'rzp_test_XXXXXXXXXXXXXX';
  static const String razorpayKeySecret = 'XXXXXXXXXXXXXX';
}
