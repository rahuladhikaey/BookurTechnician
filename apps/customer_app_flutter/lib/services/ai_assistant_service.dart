import '../models.dart';
import '../booking_provider.dart';
import '../models/ai_assistant_models.dart';

class AiAssistantService {
  static const String welcomeMessageText =
      "Hi 👋 I'm Bookur Assistant.\n\n"
      "I can help you understand our services, booking process, cancellation and refund policies, "
      "payments, technician information, and other BookurTechnician policies.";

  static final List<ChatQuickAction> defaultQuickActions = [
    const ChatQuickAction(
      label: 'Our Services',
      actionType: QuickActionType.ourServices,
      queryText: 'What services do you provide?',
    ),
    const ChatQuickAction(
      label: 'How Booking Works',
      actionType: QuickActionType.howBookingWorks,
      queryText: 'How can I book a service?',
    ),
    const ChatQuickAction(
      label: 'Service Charges',
      actionType: QuickActionType.serviceCharges,
      queryText: 'How much does it cost and what are the charges?',
    ),
    const ChatQuickAction(
      label: 'Cancellation Policy',
      actionType: QuickActionType.cancellationPolicy,
      queryText: 'What is your cancellation policy?',
    ),
    const ChatQuickAction(
      label: 'Refund Policy',
      actionType: QuickActionType.refundPolicy,
      queryText: 'How do refunds work?',
    ),
    const ChatQuickAction(
      label: 'Payment Information',
      actionType: QuickActionType.paymentInfo,
      queryText: 'What payment methods are supported and is it safe?',
    ),
    const ChatQuickAction(
      label: 'Technician Information',
      actionType: QuickActionType.technicianInfo,
      queryText: 'Who will perform the service?',
    ),
    const ChatQuickAction(
      label: 'Terms & Conditions',
      actionType: QuickActionType.termsConditions,
      queryText: 'What are your terms and conditions?',
    ),
    const ChatQuickAction(
      label: 'Privacy Policy',
      actionType: QuickActionType.privacyPolicy,
      queryText: 'What is your privacy policy?',
    ),
    const ChatQuickAction(
      label: 'Contact Support',
      actionType: QuickActionType.contactSupport,
      queryText: 'I need to contact customer support',
    ),
  ];

  // ─── Supported Brands Database ───
  static const Map<String, List<String>> supportedBrands = {
    'ac': ['Daikin', 'Voltas', 'LG', 'Samsung', 'Hitachi', 'Blue Star', 'Carrier', 'Panasonic', 'Godrej', 'Lloyd'],
    'laptop': ['Dell', 'HP', 'Lenovo', 'Asus', 'Acer', 'Apple MacBook', 'MSI', 'Samsung'],
    'refrigerator': ['LG', 'Samsung', 'Whirlpool', 'Godrej', 'Haier', 'Bosch', 'Panasonic'],
    'washing_machine': ['LG', 'Samsung', 'IFB', 'Whirlpool', 'Bosch', 'Godrej', 'Panasonic'],
    'fan': ['Havells', 'Orient', 'Crompton', 'Usha', 'Atomberg', 'Bajaj', 'Luminous'],
  };

  /// Main message processing pipeline
  static Future<ChatMessage> processUserQuery({
    required String query,
    required AppState appState,
    List<ChatMessage> conversationHistory = const [],
  }) async {
    final lower = query.toLowerCase().trim();

    // Small delay to simulate realistic AI inference & typing
    await Future.delayed(const Duration(milliseconds: 450));

    // 1. ACTIVE BOOKING & LIVE STATUS INQUIRIES
    if (lower.contains('status') ||
        lower.contains('where is my technician') ||
        lower.contains('track') ||
        lower.contains('technician assigned') ||
        lower.contains('my booking')) {
      return _handleBookingStatusQuery(appState);
    }

    // 2. REFUND INQUIRIES (AMOUNT & ELIGIBILITY)
    if (lower.contains('how much will i get back') ||
        lower.contains('refund amount') ||
        lower.contains('refund calculate') ||
        (lower.contains('refund') && lower.contains('how much'))) {
      return _handleRefundAmountQuery(appState);
    }

    // 3. OUR SERVICES OVERVIEW
    if (lower.contains('service') &&
        (lower.contains('what') || lower.contains('our') || lower.contains('provide') || lower.contains('list') || lower.contains('available') || lower.contains('explore'))) {
      return _handleOurServicesQuery(appState);
    }

    // 4. HOW BOOKING WORKS
    if (lower.contains('how') && (lower.contains('book') || lower.contains('process') || lower.contains('work') || lower.contains('schedule'))) {
      return _handleHowBookingWorksQuery();
    }

    // 5. PRICING & GST RULES
    if (lower.contains('cost') ||
        lower.contains('price') ||
        lower.contains('charge') ||
        lower.contains('pricing') ||
        lower.contains('fee') ||
        lower.contains('gst') ||
        lower.contains('tax')) {
      return _handlePricingQuery(lower, appState);
    }

    // 6. CANCELLATION POLICY
    if (lower.contains('cancel') || lower.contains('cancellation')) {
      return _handleCancellationQuery();
    }

    // 7. GENERAL REFUND POLICY
    if (lower.contains('refund')) {
      return _handleGeneralRefundPolicyQuery();
    }

    // 8. PAYMENT & SECURITY INFORMATION
    if (lower.contains('payment') || lower.contains('upi') || lower.contains('card') || lower.contains('gateway') || lower.contains('security') || lower.contains('safe')) {
      return _handlePaymentInfoQuery();
    }

    // 9. TECHNICIAN & PARTNER INFORMATION
    if (lower.contains('technician') || lower.contains('who will come') || lower.contains('partner') || lower.contains('electrician') || lower.contains('expert')) {
      return _handleTechnicianInfoQuery(appState);
    }

    // 10. BRAND SPECIFIC CHECKS (Samsung, LG, Dell, etc.)
    final brandResult = _checkBrandSupport(lower);
    if (brandResult != null) {
      return brandResult;
    }

    // 11. SPECIFIC SERVICE VERTICAL INQUIRIES
    if (lower.contains('ac') || lower.contains('air conditioner')) {
      return _handleAcServiceDetails(appState);
    }
    if (lower.contains('laptop') || lower.contains('computer') || lower.contains('screen') || lower.contains('keyboard')) {
      return _handleLaptopServiceDetails(appState);
    }
    if (lower.contains('fan') || lower.contains('ceiling fan')) {
      return _handleFanServiceDetails(appState);
    }
    if (lower.contains('fridge') || lower.contains('refrigerator')) {
      return _handleFridgeServiceDetails(appState);
    }
    if (lower.contains('washing machine')) {
      return _handleWashingMachineServiceDetails(appState);
    }

    // 12. TERMS & CONDITIONS
    if (lower.contains('terms') || lower.contains('conditions') || lower.contains('agreement') || lower.contains('rules')) {
      return _handleTermsQuery();
    }

    // 13. PRIVACY POLICY
    if (lower.contains('privacy') || lower.contains('data') || lower.contains('information collection') || lower.contains('personal data')) {
      return _handlePrivacyQuery();
    }

    // 14. CONTACT SUPPORT & ESCALATION
    if (lower.contains('support') || lower.contains('helpdesk') || lower.contains('agent') || lower.contains('human') || lower.contains('call') || lower.contains('complaint')) {
      return _handleContactSupportQuery(appState);
    }

    // 15. DEFAULT SAFE FALLBACK (NO HALLUCINATION)
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "I couldn't find a reliable answer for that in our official service guidelines.\n\n"
          "Would you like to speak directly with BookurTechnician Customer Support?",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickActions: [
        const ChatQuickAction(
          label: 'Contact Support',
          actionType: QuickActionType.contactSupport,
          queryText: 'I need to contact customer support',
        ),
        const ChatQuickAction(
          label: 'Our Services',
          actionType: QuickActionType.ourServices,
          queryText: 'What services do you provide?',
        ),
        const ChatQuickAction(
          label: 'How Booking Works',
          actionType: QuickActionType.howBookingWorks,
          queryText: 'How can I book a service?',
        ),
      ],
      actionCard: const ChatActionCard(
        title: 'Customer Support Helpdesk',
        subtitle: 'Our executive team is available 7 days a week from 8:00 AM – 9:00 PM.',
        buttonLabel: 'Open Support Center',
        routeName: '/support',
      ),
    );
  }

  // ─── HANDLERS ───

  static ChatMessage _handleOurServicesQuery(AppState state) {
    final categories = state.categories.isNotEmpty
        ? state.categories
        : MockData.categoriesList;

    final buffer = StringBuffer();
    buffer.writeln("BookurTechnician provides doorstep technical and home services.\n");
    buffer.writeln("Our available service verticals include:");
    for (final c in categories) {
      buffer.writeln("• ${c.name}");
    }
    buffer.writeln("\nAvailable services can vary by service location.");
    buffer.writeln("Would you like to explore a specific category?");

    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: buffer.toString(),
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickActions: [
        const ChatQuickAction(
          label: 'AC Services',
          actionType: QuickActionType.ourServices,
          queryText: 'What AC services do you provide?',
        ),
        const ChatQuickAction(
          label: 'Laptop Repairs',
          actionType: QuickActionType.ourServices,
          queryText: 'What laptop services do you provide?',
        ),
        const ChatQuickAction(
          label: 'Fan Services',
          actionType: QuickActionType.ourServices,
          queryText: 'What fan services do you provide?',
        ),
        const ChatQuickAction(
          label: 'How Booking Works',
          actionType: QuickActionType.howBookingWorks,
          queryText: 'How can I book a service?',
        ),
      ],
      actionCard: const ChatActionCard(
        title: 'Explore Services Catalog',
        subtitle: 'Browse all verified service options, prices, and inclusions.',
        buttonLabel: 'Explore Services',
        routeName: '/home',
      ),
    );
  }

  static ChatMessage _handleHowBookingWorksQuery() {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "Booking a certified technician with BookurTechnician is simple:\n\n"
          "1. Select a service category (AC, Laptop, Fan, etc.)\n"
          "2. Choose your required service option\n"
          "3. Confirm your service location address\n"
          "4. Select available date and 1-hour time slot\n"
          "5. Review price (Base Cost + ₹99 Booking Fee + 18% GST)\n"
          "6. Complete secure online payment\n"
          "7. Verified technician is assigned to your slot\n"
          "8. Technician arrives with required equipment\n"
          "9. Service is verified and completed with Start OTP\n"
          "10. Rate and review your experience\n\n"
          "Ready to book your technician?",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Book a Doorstep Technician',
        subtitle: 'Choose from 20+ specialized home and appliance services.',
        buttonLabel: 'Book a Service Now',
        routeName: '/home',
      ),
      quickActions: [
        const ChatQuickAction(
          label: 'Service Charges',
          actionType: QuickActionType.serviceCharges,
          queryText: 'How much are the service charges?',
        ),
        const ChatQuickAction(
          label: 'Cancellation Policy',
          actionType: QuickActionType.cancellationPolicy,
          queryText: 'What is your cancellation policy?',
        ),
      ],
    );
  }

  static ChatMessage _handlePricingQuery(String query, AppState state) {
    if (query.contains('booking charge') || query.contains('convenience') || query.contains('fee')) {
      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        text: "The standard BookurTechnician booking convenience charge is ₹99.00 per order.\n\n"
            "According to the official policy, the booking charge and applicable 18% GST are non-refundable as they cover dispatch reservation and administrative allocation.",
        sender: ChatSender.assistant,
        timestamp: DateTime.now(),
        quickActions: [
          const ChatQuickAction(
            label: 'Refund Policy',
            actionType: QuickActionType.refundPolicy,
            queryText: 'How do refunds work?',
          ),
          const ChatQuickAction(
            label: 'Cancellation Policy',
            actionType: QuickActionType.cancellationPolicy,
            queryText: 'What is your cancellation policy?',
          ),
        ],
      );
    }

    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "Service prices depend on the selected service and applicable charges.\n\n"
          "Every booking invoice is calculated transparently:\n"
          "• Service Base Cost (As listed in catalog)\n"
          "• Booking Charge (₹99.00 non-refundable)\n"
          "• Applicable GST / Taxes (18% non-refundable)\n"
          "• Grand Total = Base Cost + ₹99 + GST\n\n"
          "You can view exact itemized prices before confirming checkout.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Check Catalog Prices',
        subtitle: 'View upfront rate cards with all inclusive parts and labor fees.',
        buttonLabel: 'Explore Services',
        routeName: '/home',
      ),
      quickActions: [
        const ChatQuickAction(
          label: 'Cancellation Policy',
          actionType: QuickActionType.cancellationPolicy,
          queryText: 'Can I cancel my booking?',
        ),
        const ChatQuickAction(
          label: 'Refund Policy',
          actionType: QuickActionType.refundPolicy,
          queryText: 'What is your refund policy?',
        ),
      ],
    );
  }

  static ChatMessage _handleCancellationQuery() {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "Eligible bookings can be cancelled according to the official BookurTechnician cancellation policy.\n\n"
          "• Free cancellation is available up to 1 hour before the scheduled service time.\n"
          "• If cancelled within the eligible window, the base service cost is queued for refund processing.\n"
          "• The standard booking charge (₹99) and statutory GST (18%) are non-refundable.\n\n"
          "You can manage active bookings directly from your Booking History.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Booking & Cancellation Policy',
        subtitle: 'Read the full terms regarding cancellation windows and timelines.',
        buttonLabel: 'View Cancellation Policy',
        routeName: '/legal',
        routeArguments: 1, // Terms / Cancellation tab
      ),
      quickActions: [
        const ChatQuickAction(
          label: 'Refund Policy',
          actionType: QuickActionType.refundPolicy,
          queryText: 'How will I receive my refund?',
        ),
        const ChatQuickAction(
          label: 'Contact Support',
          actionType: QuickActionType.contactSupport,
          queryText: 'I need support with cancellation',
        ),
      ],
    );
  }

  static ChatMessage _handleGeneralRefundPolicyQuery() {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "If your booking is eligible for a refund, the refundable amount will be processed according to BookurTechnician's refund policy.\n\n"
          "Key Refund Rules:\n"
          "• Booking charge (₹99) is strictly non-refundable.\n"
          "• GST / statutory taxes (18%) are non-refundable.\n"
          "• Only the eligible base service cost is returned to the original payment source.\n"
          "• Standard refund processing SLA is within 48 hours via banking gateway.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Official Refund Policy',
        subtitle: 'Read the complete refund SLA and payment gateway turnaround terms.',
        buttonLabel: 'View Refund Policy',
        routeName: '/legal',
        routeArguments: 1,
      ),
      quickActions: [
        const ChatQuickAction(
          label: 'How much will I get back?',
          actionType: QuickActionType.refundPolicy,
          queryText: 'How much will I get back for my booking?',
        ),
        const ChatQuickAction(
          label: 'Cancellation Policy',
          actionType: QuickActionType.cancellationPolicy,
          queryText: 'What is your cancellation policy?',
        ),
      ],
    );
  }

  static ChatMessage _handleRefundAmountQuery(AppState state) {
    if (state.activeBooking != null) {
      final b = state.activeBooking!;
      final refundable = b.baseCost > 0 ? b.baseCost : 1899.0;
      final bookingFee = b.visitFee > 0 ? b.visitFee : 99.0;
      final gst = b.gstTax > 0 ? b.gstTax : (refundable + bookingFee) * 0.18;
      final total = b.grandTotal > 0 ? b.grandTotal : (refundable + bookingFee + gst);

      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        text: "Based on your active booking (${b.id}):\n\n"
            "• Total Paid: ₹${total.toStringAsFixed(2)}\n"
            "• Booking Charge (Retained): ₹${bookingFee.toStringAsFixed(2)}\n"
            "• GST Tax (Retained): ₹${gst.toStringAsFixed(2)}\n"
            "• Eligible Refund Amount: ₹${refundable.toStringAsFixed(2)}\n\n"
            "Booking charge and GST are non-refundable. The eligible amount of ₹${refundable.toStringAsFixed(2)} is processed within 48 hours upon approval.",
        sender: ChatSender.assistant,
        timestamp: DateTime.now(),
        actionCard: ChatActionCard(
          title: 'Booking Details (${b.id})',
          subtitle: 'Check tracking and cancellation options.',
          buttonLabel: 'View Booking',
          routeName: '/tracking',
          routeArguments: b.id,
        ),
      );
    }

    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "Refund amounts are calculated strictly from your booking invoice:\n\n"
          "Eligible Refund = Total Paid - (Booking Charge ₹99 + 18% GST)\n\n"
          "Only the base service fee is refundable upon eligible cancellation. If you have an active booking, log in to check your exact refund breakdown.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickActions: [
        const ChatQuickAction(
          label: 'Cancellation Policy',
          actionType: QuickActionType.cancellationPolicy,
          queryText: 'What is your cancellation policy?',
        ),
        const ChatQuickAction(
          label: 'Contact Support',
          actionType: QuickActionType.contactSupport,
          queryText: 'I need help with a refund',
        ),
      ],
    );
  }

  static ChatMessage _handleBookingStatusQuery(AppState state) {
    if (state.activeBooking != null) {
      final b = state.activeBooking!;
      final statusStr = _formatBookingStatus(b.status);
      final tech = b.technicianName.isNotEmpty ? b.technicianName : 'Pending Assignment';

      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        text: "Here is your current booking status:\n\n"
            "• Booking ID: ${b.id}\n"
            "• Current Status: $statusStr\n"
            "• Assigned Technician: $tech\n"
            "• Scheduled Slot: ${b.date} • ${b.timeSlot}\n"
            "• Start OTP: ${b.otpCode.isNotEmpty ? b.otpCode : '4821'}\n\n"
            "You can track your technician live on the map.",
        sender: ChatSender.assistant,
        timestamp: DateTime.now(),
        actionCard: ChatActionCard(
          title: 'Live Technician Tracking',
          subtitle: 'View real-time map location and arrival ETA.',
          buttonLabel: 'Track Technician Live',
          routeName: '/tracking',
          routeArguments: b.id,
        ),
      );
    }

    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "You currently have no active in-progress bookings.\n\n"
          "When you book a service, you can track the status in real time:\n"
          "1. Booking Confirmed 📋\n"
          "2. Technician Assigned 👨🔧\n"
          "3. Technician On The Way 🛵\n"
          "4. Technician Arrived 📍\n"
          "5. Service Started 🛠\n"
          "6. Service Completed ✓",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Book a Service',
        subtitle: 'Schedule a doorstep technician in 60 seconds.',
        buttonLabel: 'Explore Services',
        routeName: '/home',
      ),
    );
  }

  static ChatMessage _handlePaymentInfoQuery() {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "BookurTechnician uses secure 256-bit encrypted online payment processing through verified payment gateways.\n\n"
          "Supported Payment Options:\n"
          "• UPI (Google Pay, PhonePe, Paytm, BHIM)\n"
          "• Credit & Debit Cards (Visa, MasterCard, RuPay)\n"
          "• Net Banking (All major Indian banks)\n\n"
          "⚠️ SECURITY NOTICE:\n"
          "BookurTechnician and our technicians will NEVER ask for your UPI PIN, banking password, OTP, or CVV. Never share sensitive banking details with anyone.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickActions: [
        const ChatQuickAction(
          label: 'Service Charges',
          actionType: QuickActionType.serviceCharges,
          queryText: 'How much are the service charges?',
        ),
        const ChatQuickAction(
          label: 'Contact Support',
          actionType: QuickActionType.contactSupport,
          queryText: 'I had a payment issue',
        ),
      ],
    );
  }

  static ChatMessage _handleTechnicianInfoQuery(AppState state) {
    if (state.activeBooking != null && state.activeBooking!.technicianName.isNotEmpty) {
      final b = state.activeBooking!;
      return ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        text: "For your active booking (${b.id}), your assigned technician is:\n\n"
            "👨🔧 ${b.technicianName}\n"
            "📞 ${b.technicianPhone.isNotEmpty ? b.technicianPhone : '+91 98302-93821'}\n"
            "🛡️ Verified Identity & Police Background Checked\n"
            "🎫 Certified Digital ID Card Badge Holder",
        sender: ChatSender.assistant,
        timestamp: DateTime.now(),
        actionCard: ChatActionCard(
          title: 'Live Tracking & Call',
          subtitle: 'View technician location and contact details.',
          buttonLabel: 'View Assigned Technician',
          routeName: '/tracking',
          routeArguments: b.id,
        ),
      );
    }

    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "BookurTechnician assigns verified, certified technicians based on skill requirements, availability, and your location.\n\n"
          "Our Service Partner Standards:\n"
          "• 100% Background Verified & KYC checked with Government ID\n"
          "• Equipped with official Digital ID Card and verified QR code\n"
          "• Professional toolkit & clean uniforms\n"
          "• 30-Day post-service warranty on all standard repairs",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      quickActions: [
        const ChatQuickAction(
          label: 'Our Services',
          actionType: QuickActionType.ourServices,
          queryText: 'What services do you provide?',
        ),
        const ChatQuickAction(
          label: 'How Booking Works',
          actionType: QuickActionType.howBookingWorks,
          queryText: 'How can I book a service?',
        ),
      ],
    );
  }

  static ChatMessage? _checkBrandSupport(String query) {
    for (final entry in supportedBrands.entries) {
      for (final brand in entry.value) {
        if (query.contains(brand.toLowerCase())) {
          return ChatMessage(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            text: "Yes! BookurTechnician provides specialized repairs and maintenance for $brand devices in supported service areas.\n\n"
                "Our certified technicians use genuine replacement parts and standard diagnostic toolkits.",
            sender: ChatSender.assistant,
            timestamp: DateTime.now(),
            actionCard: const ChatActionCard(
              title: 'Book Brand Service',
              subtitle: 'Select your preferred time slot and doorstep technician.',
              buttonLabel: 'Book Now',
              routeName: '/home',
            ),
            quickActions: [
              const ChatQuickAction(
                label: 'Service Charges',
                actionType: QuickActionType.serviceCharges,
                queryText: 'How much are the service charges?',
              ),
              const ChatQuickAction(
                label: 'How Booking Works',
                actionType: QuickActionType.howBookingWorks,
                queryText: 'How can I book a service?',
              ),
            ],
          );
        }
      }
    }
    return null;
  }

  static ChatMessage _handleAcServiceDetails(AppState state) {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "BookurTechnician provides complete AC solutions:\n\n"
          "• AC Deep Jet Cleaning (₹599) — 45 mins\n"
          "• New AC Installation (₹1,499) — 90 mins\n"
          "• Gas Pressure Check & Refill (₹899)\n"
          "• Water Leakage & PCB Diagnostics (₹499)\n\n"
          "Supported Brands: Daikin, Voltas, LG, Samsung, Blue Star, Hitachi, Carrier, Panasonic, Godrej, Lloyd.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'AC Service & Repair',
        subtitle: 'Flat 20% discount on deep jet cleaning packages.',
        buttonLabel: 'Explore AC Services',
        routeName: '/category',
        routeArguments: 'cat_ac',
      ),
      quickActions: [
        const ChatQuickAction(
          label: 'How Booking Works',
          actionType: QuickActionType.howBookingWorks,
          queryText: 'How can I book an AC service?',
        ),
        const ChatQuickAction(
          label: 'Cancellation Policy',
          actionType: QuickActionType.cancellationPolicy,
          queryText: 'What is your cancellation policy?',
        ),
      ],
    );
  }

  static ChatMessage _handleLaptopServiceDetails(AppState state) {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "BookurTechnician provides doorstep & lab laptop hardware repairs:\n\n"
          "• Screen Replacement (₹3,499) — HD OEM displays with 6m warranty\n"
          "• Keyboard Replacement (₹1,899) — OEM keys\n"
          "• Battery & Charging Port Repair (₹1,299)\n"
          "• Thermal Paste Cleaning & OS Tuning (₹499)\n\n"
          "Supported Brands: Dell, HP, Lenovo, Asus, Acer, Apple MacBook, MSI, Samsung.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Laptop & Hardware Repair',
        subtitle: 'Doorstep diagnosis with verified replacement parts.',
        buttonLabel: 'Explore Laptop Services',
        routeName: '/category',
        routeArguments: 'cat_laptop',
      ),
    );
  }

  static ChatMessage _handleFanServiceDetails(AppState state) {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "BookurTechnician electrical & fan services include:\n\n"
          "• Ceiling Fan Installation (₹299) — 30 mins\n"
          "• Fan Bearing & Noise Repair (₹399)\n"
          "• Regulator & Switch Wiring Fix (₹199)\n\n"
          "Supported Brands: Havells, Orient, Crompton, Usha, Atomberg, Bajaj.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Ceiling Fan Services',
        subtitle: 'Certified electrician at your doorstep within 45 minutes.',
        buttonLabel: 'Explore Fan Services',
        routeName: '/category',
        routeArguments: 'cat_fan',
      ),
    );
  }

  static ChatMessage _handleFridgeServiceDetails(AppState state) {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "Refrigerator diagnostics & repair services:\n\n"
          "• Cooling & Thermostat Repair (₹899)\n"
          "• Compressor Gas Refill & Leak Fix (₹1,499)\n"
          "• Door Gasket Replacement (₹499)\n\n"
          "Supported Brands: LG, Samsung, Whirlpool, Godrej, Haier, Bosch.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Refrigerator Services',
        subtitle: 'Direct doorstep inspection and cooling restoration.',
        buttonLabel: 'Explore Refrigerator Services',
        routeName: '/category',
        routeArguments: 'cat_refrigerator',
      ),
    );
  }

  static ChatMessage _handleWashingMachineServiceDetails(AppState state) {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "Washing machine installation & care services:\n\n"
          "• Inlet Hose & Drain Installation (₹499)\n"
          "• Drum & Motor Vibration Fix (₹799)\n"
          "• PCB Circuit Board Repair (₹1,299)\n\n"
          "Supported Brands: LG, Samsung, IFB, Whirlpool, Bosch, Godrej.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Washing Machine Services',
        subtitle: 'Front load & top load service by verified specialists.',
        buttonLabel: 'Explore Services',
        routeName: '/home',
      ),
    );
  }

  static ChatMessage _handleTermsQuery() {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "BookurTechnician operates under official enterprise Service Terms:\n\n"
          "• Upfront transparent pricing with mandatory ₹99 booking fee and 18% GST.\n"
          "• 30-Day Service Warranty on eligible repair jobs.\n"
          "• Background-checked certified technicians.\n"
          "• Secure payment processing with 48h SLA on eligible refunds.\n\n"
          "Would you like to read the complete legal terms?",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Official Terms & Conditions',
        subtitle: 'Read the latest Admin-published service agreement.',
        buttonLabel: 'Read Full Terms',
        routeName: '/legal',
        routeArguments: 1,
      ),
    );
  }

  static ChatMessage _handlePrivacyQuery() {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "BookurTechnician takes your data privacy seriously:\n\n"
          "• We collect only essential contact and address details to dispatch technicians.\n"
          "• We never store sensitive banking credentials, passwords, or CVVs.\n"
          "• Customer data is encrypted and never sold to third-party advertisers.\n\n"
          "You can review our complete Privacy Policy in the app.",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Official Privacy Policy',
        subtitle: 'Review our data retention and encryption standards.',
        buttonLabel: 'Read Privacy Policy',
        routeName: '/legal',
        routeArguments: 0,
      ),
    );
  }

  static ChatMessage _handleContactSupportQuery(AppState state) {
    final customerInfo = state.userPhone.isNotEmpty ? "${state.userName} (${state.userPhone})" : "Authenticated Customer";
    final bookingId = state.activeBooking?.id ?? "None Active";

    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: "Our dedicated Customer Support Helpdesk is ready to assist you.\n\n"
          "Customer Profile: $customerInfo\n"
          "Active Booking Reference: $bookingId\n"
          "Helpdesk Hotline: +91 99999-88888 (8:00 AM – 9:00 PM)\n"
          "Email: support@bookurtechnician.com\n\n"
          "Would you like to open the Support Center?",
      sender: ChatSender.assistant,
      timestamp: DateTime.now(),
      actionCard: const ChatActionCard(
        title: 'Help & Support Center',
        subtitle: 'Submit a ticket or call an executive for instant help.',
        buttonLabel: 'Open Support Helpdesk',
        routeName: '/support',
      ),
    );
  }

  static String _formatBookingStatus(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Booking Confirmed 📋';
      case BookingStatus.techAssigned:
      case BookingStatus.techAccepted:
        return 'Technician Assigned 👨🔧';
      case BookingStatus.techOnTheWay:
        return 'Technician On The Way 🛵';
      case BookingStatus.techArrived:
        return 'Technician Arrived 📍';
      case BookingStatus.serviceStarted:
        return 'Service Started 🛠';
      case BookingStatus.completed:
        return 'Service Completed ✓';
      case BookingStatus.cancelled:
        return 'Booking Cancelled ✕';
      default:
        return 'In Progress';
    }
  }
}
