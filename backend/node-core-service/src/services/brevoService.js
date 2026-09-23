// Forwarded to EmailJS service
const emailService = require('./emailService');

module.exports = {
  deriveNameFromEmail: emailService.deriveNameFromEmail,
  sendOtpEmail: emailService.sendOtpEmail,
  sendTransactionalEmail: emailService.sendEmailJsEmail,
};
