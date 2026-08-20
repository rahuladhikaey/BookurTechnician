package com.bookurtechnician.auth.service;

import com.bookurtechnician.config.BrevoConfig;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class BrevoEmailService {

    private final BrevoConfig brevoConfig;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    private static final String BREVO_API_URL = "https://api.brevo.com/v3/smtp/email";

    @Async
    public void sendOtpEmail(String recipientEmail, String recipientName, String otp) {
        if (brevoConfig.getApiKey() == null || brevoConfig.getApiKey().isBlank()) {
            log.warn("[DEV MODE] Brevo API Key not configured. Simulated OTP for {}: {}", recipientEmail, otp);
            return;
        }

        try {
            Map<String, Object> payload = Map.of(
                    "sender", Map.of(
                            "name", brevoConfig.getSenderName() != null ? brevoConfig.getSenderName() : "BookurTechnician",
                            "email", brevoConfig.getSenderEmail() != null ? brevoConfig.getSenderEmail() : "noreply@asaliswad.com"
                    ),
                    "to", List.of(
                            Map.of(
                                    "email", recipientEmail,
                                    "name", recipientName != null && !recipientName.isBlank() ? recipientName : "Valued Customer"
                            )
                    ),
                    "subject", "Your BookurTechnician Verification Code: " + otp,
                    "htmlContent", buildOtpHtmlTemplate(recipientName, otp)
            );

            String requestBody = objectMapper.writeValueAsString(payload);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(BREVO_API_URL))
                    .header("Content-Type", "application/json")
                    .header("api-key", brevoConfig.getApiKey())
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                log.info("Brevo OTP email dispatched successfully to {}", recipientEmail);
            } else {
                log.error("Brevo API returned error status {}: {}", response.statusCode(), response.body());
            }
        } catch (Exception e) {
            log.error("Failed to send Brevo OTP email to {}: {}", recipientEmail, e.getMessage());
        }
    }

    @Async
    public void sendEndServiceOtpEmail(String recipientEmail, String recipientName, String bookingCode, String endOtp) {
        if (brevoConfig.getApiKey() == null || brevoConfig.getApiKey().isBlank()) {
            log.warn("[DEV MODE] Brevo API Key not configured. Simulated End OTP for Booking {}: {}", bookingCode, endOtp);
            return;
        }

        try {
            Map<String, Object> payload = Map.of(
                    "sender", Map.of(
                            "name", brevoConfig.getSenderName() != null ? brevoConfig.getSenderName() : "BookurTechnician",
                            "email", brevoConfig.getSenderEmail() != null ? brevoConfig.getSenderEmail() : "noreply@asaliswad.com"
                    ),
                    "to", List.of(
                            Map.of(
                                    "email", recipientEmail,
                                    "name", recipientName != null && !recipientName.isBlank() ? recipientName : "Valued Customer"
                            )
                    ),
                    "subject", "Service Completion Code (" + bookingCode + "): " + endOtp,
                    "htmlContent", buildEndOtpHtmlTemplate(recipientName, bookingCode, endOtp)
            );

            String requestBody = objectMapper.writeValueAsString(payload);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(BREVO_API_URL))
                    .header("Content-Type", "application/json")
                    .header("api-key", brevoConfig.getApiKey())
                    .POST(HttpRequest.BodyPublishers.ofString(requestBody))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                log.info("Brevo End Service OTP email dispatched successfully to {} for booking {}", recipientEmail, bookingCode);
            } else {
                log.error("Brevo API returned error status {}: {}", response.statusCode(), response.body());
            }
        } catch (Exception e) {
            log.error("Failed to send End Service OTP email to {}: {}", recipientEmail, e.getMessage());
        }
    }

    private String buildOtpHtmlTemplate(String name, String otp) {
        return """
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <style>
                body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #F8FAFC; margin: 0; padding: 24px; }
                .card { max-width: 520px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; border: 1px solid #E2E8F0; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.04); }
                .header { text-align: center; border-bottom: 2px solid #EEF3FF; padding-bottom: 20px; }
                .brand-title { color: #2146A8; font-size: 22px; font-weight: 800; letter-spacing: -0.5px; margin: 0; }
                .brand-sub { color: #64748B; font-size: 13px; margin-top: 4px; }
                .otp-box { background: #EEF3FF; border: 2px dashed #2146A8; border-radius: 12px; padding: 18px; text-align: center; margin: 28px 0; }
                .otp-code { font-size: 34px; font-weight: 900; letter-spacing: 8px; color: #17357F; font-family: monospace; }
                .note { color: #64748B; font-size: 13px; line-height: 1.6; }
                .footer { text-align: center; margin-top: 28px; font-size: 12px; color: #94A3B8; }
              </style>
            </head>
            <body>
              <div class="card">
                <div class="header">
                  <h1 class="brand-title">BOOKURTECHNICIAN</h1>
                  <p class="brand-sub">Expert Help. Just a Booking Away.</p>
                </div>
                <p style="font-size: 15px; color: #1E293B; margin-top: 24px;">Hello <strong>%s</strong>,</p>
                <p class="note">Please use the following 6-digit verification code to complete your security verification. This code is valid for <strong>5 minutes</strong>.</p>
                <div class="otp-box">
                  <div class="otp-code">%s</div>
                </div>
                <p class="note">If you did not request this verification code, please disregard this email or contact support if you suspect unauthorized access.</p>
                <div class="footer">
                  © 2026 BookurTechnician India. All rights reserved.
                </div>
              </div>
            </body>
            </html>
            """.formatted(name != null && !name.isBlank() ? name : "Partner / Customer", otp);
    }

    private String buildEndOtpHtmlTemplate(String name, String bookingCode, String otp) {
        return """
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="utf-8">
              <style>
                body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #F8FAFC; margin: 0; padding: 24px; }
                .card { max-width: 540px; margin: 0 auto; background: #FFFFFF; border-radius: 16px; border: 1px solid #E2E8F0; padding: 32px; box-shadow: 0 4px 14px rgba(0,0,0,0.05); }
                .header { text-align: center; border-bottom: 2px solid #ECFDF5; padding-bottom: 20px; }
                .brand-title { color: #1E3A8A; font-size: 22px; font-weight: 800; margin: 0; }
                .brand-sub { color: #059669; font-size: 13px; font-weight: 700; margin-top: 4px; }
                .badge { display: inline-block; background: #FEF3C7; color: #92400E; font-size: 12px; font-weight: 800; padding: 4px 12px; border-radius: 20px; margin-top: 12px; }
                .otp-box { background: #F0FDF4; border: 2px dashed #16A34A; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0; }
                .otp-code { font-size: 36px; font-weight: 900; letter-spacing: 8px; color: #166534; font-family: monospace; }
                .disclaimer { background: #FEF2F2; border-left: 4px solid #EF4444; padding: 12px 16px; border-radius: 6px; font-size: 12.5px; color: #991B1B; margin-top: 18px; line-height: 1.5; }
                .footer { text-align: center; margin-top: 28px; font-size: 12px; color: #94A3B8; }
              </style>
            </head>
            <body>
              <div class="card">
                <div class="header">
                  <h1 class="brand-title">BOOKURTECHNICIAN</h1>
                  <p class="brand-sub">Service in Progress • Booking #%s</p>
                  <span class="badge">Valid for 24 Hours</span>
                </div>
                <p style="font-size: 15px; color: #1E293B; margin-top: 24px;">Hello <strong>%s</strong>,</p>
                <p style="color: #475569; font-size: 13.5px; line-height: 1.6;">Your technician has started work on your service booking. Once the work is fully finished and inspected to your satisfaction, please share this <strong>4-digit Completion OTP</strong> with the technician to mark the job complete:</p>
                <div class="otp-box">
                  <div class="otp-code">%s</div>
                </div>
                <div class="disclaimer">
                  <strong>Safety Disclaimer:</strong> Please share this completion code ONLY after the service has been satisfactorily inspected. Do not share this code in advance.
                </div>
                <div class="footer">
                  © 2026 BookurTechnician India. All rights reserved.
                </div>
              </div>
            </body>
            </html>
            """.formatted(bookingCode, name != null && !name.isBlank() ? name : "Valued Customer", otp);
    }
}
