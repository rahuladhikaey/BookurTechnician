package com.bookurtechnician.booking.controller;

import com.bookurtechnician.auth.security.UserPrincipal;
import com.bookurtechnician.booking.dto.BookingDtos;
import com.bookurtechnician.booking.service.BookingService;
import com.bookurtechnician.common.response.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/bookings")
@RequiredArgsConstructor
public class BookingController {

    private final BookingService bookingService;

    @PostMapping
    public ResponseEntity<ApiResponse<BookingDtos.BookingResponse>> createBooking(
            @AuthenticationPrincipal UserPrincipal principal,
            @Valid @RequestBody BookingDtos.CreateBookingRequest request) {
        BookingDtos.BookingResponse response = bookingService.createBooking(principal.getId(), request);
        return ResponseEntity.ok(ApiResponse.success(response, "Booking created and confirmed successfully"));
    }

    @GetMapping("/my-bookings")
    public ResponseEntity<ApiResponse<List<BookingDtos.BookingResponse>>> getMyBookings(
            @AuthenticationPrincipal UserPrincipal principal) {
        List<BookingDtos.BookingResponse> bookings = bookingService.getCustomerBookings(principal.getId());
        return ResponseEntity.ok(ApiResponse.success(bookings));
    }

    @PatchMapping("/{bookingId}/status")
    public ResponseEntity<ApiResponse<BookingDtos.BookingResponse>> updateStatus(
            @PathVariable UUID bookingId,
            @Valid @RequestBody BookingDtos.UpdateBookingStatusRequest request) {
        BookingDtos.BookingResponse response = bookingService.updateBookingStatus(bookingId, request);
        return ResponseEntity.ok(ApiResponse.success(response, "Booking status updated to " + request.getStatus()));
    }
}
