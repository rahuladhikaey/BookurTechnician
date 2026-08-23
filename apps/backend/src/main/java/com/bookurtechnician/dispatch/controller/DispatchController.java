package com.bookurtechnician.dispatch.controller;

import com.bookurtechnician.auth.security.UserPrincipal;
import com.bookurtechnician.common.response.ApiResponse;
import com.bookurtechnician.dispatch.entity.BookingProposal;
import com.bookurtechnician.dispatch.repository.BookingProposalRepository;
import com.bookurtechnician.dispatch.service.DispatchService;
import com.bookurtechnician.technician.entity.TechnicianProfile;
import com.bookurtechnician.technician.repository.TechnicianProfileRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/dispatch")
public class DispatchController {

    private final DispatchService dispatchService;
    private final BookingProposalRepository proposalRepository;
    private final TechnicianProfileRepository technicianProfileRepository;

    public DispatchController(DispatchService dispatchService,
                              BookingProposalRepository proposalRepository,
                              TechnicianProfileRepository technicianProfileRepository) {
        this.dispatchService = dispatchService;
        this.proposalRepository = proposalRepository;
        this.technicianProfileRepository = technicianProfileRepository;
    }

    @GetMapping("/proposals/pending")
    @PreAuthorize("hasRole('TECHNICIAN')")
    public ResponseEntity<ApiResponse<List<BookingProposal>>> getPendingProposals(
            @AuthenticationPrincipal UserPrincipal principal) {
        TechnicianProfile profile = technicianProfileRepository.findByUserId(principal.getId())
                .orElseThrow(() -> new RuntimeException("Technician profile not found"));

        List<BookingProposal> pending = proposalRepository.findByTechnicianIdAndStatus(profile.getId(), "PENDING");
        return ResponseEntity.ok(ApiResponse.success(pending));
    }

    @PostMapping("/proposals/{proposalId}/accept")
    @PreAuthorize("hasRole('TECHNICIAN')")
    public ResponseEntity<ApiResponse<BookingProposal>> acceptProposal(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID proposalId) {
        BookingProposal accepted = dispatchService.acceptProposal(principal.getId(), proposalId);
        return ResponseEntity.ok(ApiResponse.success(accepted, "Job accepted successfully."));
    }

    @PostMapping("/proposals/{proposalId}/reject")
    @PreAuthorize("hasRole('TECHNICIAN')")
    public ResponseEntity<ApiResponse<Void>> rejectProposal(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID proposalId,
            @RequestBody(required = false) ProposalRejectDto dto) {
        String reason = dto != null ? dto.getReason() : "Declined by technician";
        dispatchService.rejectProposal(principal.getId(), proposalId, reason);
        return ResponseEntity.ok(ApiResponse.success(null, "Proposal declined."));
    }

    public static class ProposalRejectDto {
        private String reason;

        public ProposalRejectDto() {}
        public ProposalRejectDto(String reason) { this.reason = reason; }

        public String getReason() { return reason; }
        public void setReason(String reason) { this.reason = reason; }
    }
}
