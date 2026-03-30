import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/patient/patient_home_screen.dart';
import '../screens/patient/service_selection_screen.dart';
import '../screens/patient/booking_screen.dart';
import '../screens/patient/tracking_screen.dart';
import '../screens/patient/payment_screen.dart';
import '../screens/patient/booking_history_screen.dart';
import '../screens/patient/rating_screen.dart';
import '../screens/patient/patient_profile_screen.dart';
import '../screens/patient/scan_nurse_screen.dart';
import '../screens/nurse/nurse_home_screen.dart';
import '../screens/nurse/booking_request_screen.dart';
import '../screens/nurse/active_booking_screen.dart';
import '../screens/nurse/earnings_dashboard_screen.dart';
import '../screens/nurse/withdrawal_screen.dart';
import '../screens/nurse/nurse_history_screen.dart';
import '../screens/nurse/nurse_profile_screen.dart';
import '../screens/nurse/nurse_qr_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String roleSelection = '/role-selection';
  
  // Patient Routes
  static const String patientHome = '/patient/home';
  static const String serviceSelection = '/patient/services';
  static const String booking = '/patient/booking';
  static const String tracking = '/patient/tracking';
  static const String payment = '/patient/payment';
  static const String bookingHistory = '/patient/history';
  static const String rating = '/patient/rating';
  static const String patientProfile = '/patient/profile';
  static const String scanNurse = '/patient/scan-nurse';
  
  // Nurse Routes
  static const String nurseHome = '/nurse/home';
  static const String bookingRequest = '/nurse/request';
  static const String activeBooking = '/nurse/active';
  static const String earningsDashboard = '/nurse/earnings';
  static const String withdrawal = '/nurse/withdrawal';
  static const String nurseHistory = '/nurse/history';
  static const String nurseProfile = '/nurse/profile';
  static const String nurseQr = '/nurse/qr';

  static Map<String, WidgetBuilder> get routes => {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    roleSelection: (_) => const RoleSelectionScreen(),
    patientHome: (_) => const PatientHomeScreen(),
    serviceSelection: (_) => const ServiceSelectionScreen(),
    booking: (_) => const BookingScreen(),
    tracking: (_) => const TrackingScreen(),
    payment: (_) => const PaymentScreen(),
    bookingHistory: (_) => const BookingHistoryScreen(),
    rating: (_) => const RatingScreen(),
    patientProfile: (_) => const PatientProfileScreen(),
    scanNurse: (_) => const ScanNurseScreen(),
    nurseHome: (_) => const NurseHomeScreen(),
    bookingRequest: (_) => const BookingRequestScreen(),
    activeBooking: (_) => const ActiveBookingScreen(),
    earningsDashboard: (_) => const EarningsDashboardScreen(),
    withdrawal: (_) => const WithdrawalScreen(),
    nurseHistory: (_) => const NurseHistoryScreen(),
    nurseProfile: (_) => const NurseProfileScreen(),
    nurseQr: (_) => const NurseQrScreen(),
  };
}
