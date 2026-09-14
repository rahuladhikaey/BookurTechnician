import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'booking_provider.dart';
import 'models.dart';
import 'theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/catalog_screens.dart';
import 'screens/cart_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/history_invoice_screens.dart';
import 'screens/misc_screens.dart';
import 'screens/legal_screen.dart';
import 'screens/ai_assistant_sheet.dart';
import 'screens/profile_completion_wizard_screen.dart';
import 'screens/profile_details_screen.dart';
import 'screens/saved_addresses_screen.dart';
import 'screens/booking_status_map_screen.dart';
import 'screens/razorpay_payment_screen.dart';
import 'screens/all_services_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const ProviderScope(child: CustomerApp()));
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bookurtechnician',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/splash':
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case '/onboarding':
            return MaterialPageRoute(builder: (_) => const OnboardingScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/otp':
            final args = settings.arguments as Map<String, String>? ?? {};
            final phone = args['phone'] ?? '';
            final email = args['email'] ?? '';
            return MaterialPageRoute(
              builder: (_) => OtpScreen(
                phoneNumber: phone,
                emailAddress: email,
              ),
            );
          case '/home':
            return MaterialPageRoute(builder: (_) => const _HomeWithRestoration());
          case '/all_services':
            final initialCat = settings.arguments as String?;
            return MaterialPageRoute(builder: (_) => AllServicesScreen(initialCategoryId: initialCat));
          case '/category':
            final catId = settings.arguments as String? ?? '';
            return MaterialPageRoute(builder: (_) => CategoryServicesScreen(categoryId: catId));
          case '/service_detail':
            final srvId = settings.arguments as String? ?? '';
            return MaterialPageRoute(builder: (_) => ServiceDetailScreen(serviceId: srvId));
          case '/cart':
            return MaterialPageRoute(builder: (_) => const CartScreen());
          case '/payment':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => RazorpayPaymentScreen(
                bookingId: args['bookingId']?.toString() ?? '',
                bookingCode: args['bookingCode']?.toString() ?? '',
                serviceName: args['serviceName']?.toString() ?? 'Service Booking',
                amount: (args['amount'] as num?)?.toDouble() ?? 0.0,
                schedule: args['schedule']?.toString() ?? '',
                address: args['address']?.toString() ?? '',
              ),
            );
          case '/tracking':
            final bId = settings.arguments as String? ?? '';
            return MaterialPageRoute(builder: (_) => BookingTrackingScreen(bookingId: bId));
          case '/booking_status_map':
            final args = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(builder: (_) => BookingStatusMapScreen(initialBookingData: args));
          case '/history':
            return MaterialPageRoute(builder: (_) => const BookingHistoryScreen());
          case '/invoice':
            final bId = settings.arguments as String? ?? '';
            return MaterialPageRoute(builder: (_) => InvoiceScreen(bookingId: bId));
          case '/profile':
            return MaterialPageRoute(builder: (_) => const ProfileScreen());
          case '/profile_completion_wizard':
            final returnToCart = settings.arguments as bool? ?? false;
            return MaterialPageRoute(builder: (_) => ProfileCompletionWizardScreen(returnToCartOnComplete: returnToCart));
          case '/profile_details':
            return MaterialPageRoute(builder: (_) => const ProfileDetailsScreen());
          case '/saved_addresses':
            return MaterialPageRoute(builder: (_) => const SavedAddressesScreen());
          case '/notifications':
            return MaterialPageRoute(builder: (_) => const NotificationsScreen());
          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case '/privacy_center':
            return MaterialPageRoute(builder: (_) => const PrivacyCenterScreen());
          case '/support':
            return MaterialPageRoute(builder: (_) => const SupportScreen());
          case '/assistant':
            return MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: AiAssistantSheet())));
          case '/legal':
            final tabIdx = settings.arguments as int? ?? 0;
            return MaterialPageRoute(builder: (_) => LegalScreen(initialTabIndex: tabIdx));
          case '/privacy':
            return MaterialPageRoute(builder: (_) => const LegalScreen(initialTabIndex: 0));
          case '/terms':
            return MaterialPageRoute(builder: (_) => const LegalScreen(initialTabIndex: 1));
          default:
            return MaterialPageRoute(builder: (_) => const OnboardingScreen());
        }
      },
    );
  }
}

// ─── Home With Payment Restoration Check ─────────────────────────────────────

class _HomeWithRestoration extends ConsumerStatefulWidget {
  const _HomeWithRestoration();
  @override
  ConsumerState<_HomeWithRestoration> createState() => _HomeWithRestorationState();
}

class _HomeWithRestorationState extends ConsumerState<_HomeWithRestoration> {
  @override
  void initState() {
    super.initState();
    // Defer restoration check to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(bookingProvider.notifier).checkRestoration();
      final status = ref.read(bookingProvider).paymentStatus;
      if (status == PaymentStatus.pendingRestoration && mounted) {
        _showRestorationDialog();
      }
    });
  }

  void _showRestorationDialog() {
    final total = ref.read(bookingProvider).restoredCartTotal;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Resume Interrupted Payment?'),
        content: Text(
          'We detected that your previous payment of ₹${total.toStringAsFixed(2)} was interrupted. '
          'Would you like to restore your cart and resume?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(bookingProvider.notifier).discardRestoration();
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(bookingProvider.notifier).restoreCart();
              if (mounted) Navigator.pushNamed(context, '/cart');
            },
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
