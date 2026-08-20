package com.bookurtechnician.notification.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.*;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.util.Base64;
import java.util.Map;

@Service
@Slf4j
public class FcmNotificationService {

    @Value("${app.firebase.credentials-json-base64:}")
    private String firebaseCredentialsBase64;

    private boolean initialized = false;

    @PostConstruct
    public void init() {
        try {
            if (FirebaseApp.getApps().isEmpty()) {
                if (firebaseCredentialsBase64 != null && !firebaseCredentialsBase64.trim().isEmpty()) {
                    byte[] decoded = Base64.getDecoder().decode(firebaseCredentialsBase64.trim());
                    GoogleCredentials credentials = GoogleCredentials.fromStream(new ByteArrayInputStream(decoded));
                    FirebaseOptions options = FirebaseOptions.builder()
                            .setCredentials(credentials)
                            .build();
                    FirebaseApp.initializeApp(options);
                    initialized = true;
                    log.info("Firebase Admin SDK successfully initialized from Base64 credentials.");
                } else {
                    log.warn("[FCM DEV MODE] Firebase credentials not configured. Push notifications will be simulated.");
                }
            } else {
                initialized = true;
            }
        } catch (Exception e) {
            log.error("Failed to initialize Firebase Admin SDK: {}", e.getMessage());
        }
    }

    /**
     * Dispatches a high-priority loud incoming job alert to a partner technician.
     */
    public void sendJobAlert(String fcmToken,
                             String proposalId,
                             String bookingId,
                             String serviceType,
                             String customerName,
                             String customerAddress,
                             String distanceKm,
                             String payout,
                             int timeoutSeconds) {
        if (fcmToken == null || fcmToken.trim().isEmpty()) {
            log.warn("Cannot send FCM job alert: technician has no registered FCM token.");
            return;
        }

        if (!initialized) {
            log.info("[SIMULATED FCM] Sending Loud Job Alert to token {}: Service={}, Payout=Rs.{}, Distance={}km, Timeout={}s",
                    fcmToken, serviceType, payout, distanceKm, timeoutSeconds);
            return;
        }

        try {
            // Android high-priority loud notification configuration
            AndroidConfig androidConfig = AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .setTtl(timeoutSeconds * 1000L)
                    .setNotification(AndroidNotification.builder()
                            .setChannelId("job_alerts_channel")
                            .setSound("incoming_job_ringtone")
                            .setDefaultSound(false)
                            .setDefaultVibrateTimings(false)
                            .setPriority(AndroidNotification.Priority.MAX)
                            .setVisibility(AndroidNotification.Visibility.PUBLIC)
                            .setTitle("🔔 New Job Alert - ₹" + payout)
                            .setBody(serviceType + " (" + distanceKm + " km away) • " + customerAddress)
                            .build())
                    .build();

            // High priority APNs config for iOS
            ApnsConfig apnsConfig = ApnsConfig.builder()
                    .putHeader("apns-priority", "10")
                    .setAps(Aps.builder()
                            .setSound("incoming_job_ringtone.wav")
                            .setContentAvailable(true)
                            .build())
                    .build();

            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle("New Job Request: ₹" + payout)
                            .setBody(serviceType + " near " + customerAddress)
                            .build())
                    .putAllData(Map.of(
                            "type", "NEW_JOB_ALERT",
                            "proposalId", proposalId != null ? proposalId : "",
                            "bookingId", bookingId != null ? bookingId : "",
                            "serviceType", serviceType != null ? serviceType : "Service Request",
                            "customerName", customerName != null ? customerName : "Customer",
                            "customerAddress", customerAddress != null ? customerAddress : "",
                            "distanceKm", distanceKm != null ? distanceKm : "0.0",
                            "payout", payout != null ? payout : "0",
                            "timeoutSeconds", String.valueOf(timeoutSeconds)
                    ))
                    .setAndroidConfig(androidConfig)
                    .setApnsConfig(apnsConfig)
                    .build();

            String response = FirebaseMessaging.getInstance().send(message);
            log.info("Successfully dispatched High-Priority FCM Job Alert message ID: {}", response);
        } catch (Exception e) {
            log.error("Failed to dispatch FCM Job Alert to token {}: {}", fcmToken, e.getMessage());
        }
    }
}
