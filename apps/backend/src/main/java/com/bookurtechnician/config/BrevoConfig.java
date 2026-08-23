package com.bookurtechnician.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConfigurationProperties(prefix = "app.brevo")
public class BrevoConfig {
    private String apiKey;
    private String senderEmail;
    private String senderName;
    private Long otpTemplateId;

    public String getApiKey() { return apiKey; }
    public void setApiKey(String apiKey) { this.apiKey = apiKey; }

    public String getSenderEmail() { return senderEmail; }
    public void setSenderEmail(String senderEmail) { this.senderEmail = senderEmail; }

    public String getSenderName() { return senderName; }
    public void setSenderName(String senderName) { this.senderName = senderName; }

    public Long getOtpTemplateId() { return otpTemplateId; }
    public void setOtpTemplateId(Long otpTemplateId) { this.otpTemplateId = otpTemplateId; }
}
