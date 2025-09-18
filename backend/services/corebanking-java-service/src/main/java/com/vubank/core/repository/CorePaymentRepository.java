package com.vubank.core.repository;

import com.vubank.core.model.CorePayment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface CorePaymentRepository extends JpaRepository<CorePayment, Long> {
    
    Optional<CorePayment> findByTxnRef(UUID txnRef);
    
    Optional<CorePayment> findByCbsId(UUID cbsId);
    
    boolean existsByTxnRef(UUID txnRef);
}