package com.vubank.payment.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hazelcast.core.HazelcastInstance;
import com.hazelcast.map.IMap;
import com.vubank.payment.model.PaymentRequest;
import com.vubank.payment.model.TransactionState;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Service
public class HazelcastTransactionStateService {

    private static final Logger logger = LoggerFactory.getLogger(HazelcastTransactionStateService.class);
    private static final String TRANSACTION_STATES_MAP = "transaction-states";
    private static final String BALANCE_CACHE_MAP = "balance-cache";
    private static final String IDEMPOTENCY_LOCKS_MAP = "idempotency-locks";

    private final HazelcastInstance hazelcastInstance;
    private final ObjectMapper objectMapper;

    public HazelcastTransactionStateService(HazelcastInstance hazelcastInstance) {
        this.hazelcastInstance = hazelcastInstance;
        this.objectMapper = new ObjectMapper();
        objectMapper.findAndRegisterModules(); // Register JSR-310 module for OffsetDateTime
    }

    public void saveTransactionState(TransactionState state) {
        try {
            IMap<String, String> statesMap = hazelcastInstance.getMap(TRANSACTION_STATES_MAP);
            String stateJson = objectMapper.writeValueAsString(state);
            statesMap.put(state.getTxnRef(), stateJson);
            logger.debug("Saved transaction state for txnRef: {}", state.getTxnRef());
        } catch (JsonProcessingException e) {
            logger.error("Failed to serialize transaction state for txnRef: {}", state.getTxnRef(), e);
            throw new RuntimeException("Failed to save transaction state", e);
        }
    }

    public TransactionState getTransactionState(String txnRef) {
        try {
            IMap<String, String> statesMap = hazelcastInstance.getMap(TRANSACTION_STATES_MAP);
            String stateJson = statesMap.get(txnRef);
            
            if (stateJson == null) {
                logger.debug("Transaction state not found for txnRef: {}", txnRef);
                return null;
            }

            TransactionState state = objectMapper.readValue(stateJson, TransactionState.class);
            logger.debug("Retrieved transaction state for txnRef: {}", txnRef);
            return state;
        } catch (JsonProcessingException e) {
            logger.error("Failed to deserialize transaction state for txnRef: {}", txnRef, e);
            throw new RuntimeException("Failed to retrieve transaction state", e);
        }
    }

    public void updateTransactionStatus(String txnRef, TransactionState.Status status, String failureReason) {
        TransactionState state = getTransactionState(txnRef);
        if (state != null) {
            state.setStatus(status);
            state.setUpdatedAt(OffsetDateTime.now());
            
            if (failureReason != null) {
                state.setFailureReason(failureReason);
            }
            
            // Set specific timestamps based on status
            switch (status) {
                case VALIDATED:
                    state.setValidatedAt(OffsetDateTime.now());
                    break;
                case IN_PROGRESS:
                    state.setInProgressAt(OffsetDateTime.now());
                    break;
                case SUCCESS:
                    state.setProcessedAt(OffsetDateTime.now());
                    break;
                default:
                    break;
            }
            
            saveTransactionState(state);
            logger.debug("Updated transaction status for txnRef: {} to {}", txnRef, status);
        } else {
            logger.warn("Cannot update transaction status - state not found for txnRef: {}", txnRef);
        }
    }

    public TransactionState createInitialState(String txnRef, PaymentRequest paymentRequest) {
        TransactionState state = new TransactionState(txnRef);
        state.setTransactionRef(txnRef);
        state.setStatus(TransactionState.Status.RECEIVED);
        state.setCreatedAt(OffsetDateTime.now());
        state.setUpdatedAt(OffsetDateTime.now());
        state.setAmount(paymentRequest.getAmount());
        state.setPayeeName(paymentRequest.getPayeeName());
        state.setFromAccountNo(paymentRequest.getFromAccountNo());
        state.setToAccountNo(paymentRequest.getToAccountNo());
        state.setPayerAccount(paymentRequest.getFromAccountNo());
        state.setPayeeAccount(paymentRequest.getToAccountNo());
        state.setIfscCode(paymentRequest.getIfscCode());
        state.setIfsc(paymentRequest.getIfscCode());
        state.setComments(paymentRequest.getComments());
        
        return state;
    }

    public void updateTransactionWithCoreBankingResponse(String txnRef, String cbsId, String response) {
        TransactionState state = getTransactionState(txnRef);
        if (state != null) {
            state.setCbsId(cbsId);
            state.setCoreBankingResponse(response);
            state.setUpdatedAt(OffsetDateTime.now());
            
            if (cbsId != null && !cbsId.trim().isEmpty()) {
                state.setStatus(TransactionState.Status.SUCCESS);
                state.setProcessedAt(OffsetDateTime.now());
            }
            
            saveTransactionState(state);
            logger.debug("Updated transaction with CoreBanking response for txnRef: {}, cbsId: {}", txnRef, cbsId);
        } else {
            logger.warn("Cannot update CoreBanking response - state not found for txnRef: {}", txnRef);
        }
    }

    public boolean tryLockTransaction(String idempotencyKey) {
        try {
            IMap<String, String> lockMap = hazelcastInstance.getMap(IDEMPOTENCY_LOCKS_MAP);
            String lockKey = "lock:txn:" + idempotencyKey;
            String lockValue = "LOCKED:" + System.currentTimeMillis();
            
            // Try to acquire lock with TTL
            String existingLock = lockMap.putIfAbsent(lockKey, lockValue);
            boolean acquired = (existingLock == null);
            
            if (acquired) {
                logger.debug("Acquired lock for idempotency key: {}", idempotencyKey);
            } else {
                logger.debug("Failed to acquire lock for idempotency key: {} (already exists)", idempotencyKey);
            }
            
            return acquired;
        } catch (Exception e) {
            logger.error("Error acquiring lock for idempotency key: {}", idempotencyKey, e);
            return false;
        }
    }

    public void releaseLock(String idempotencyKey) {
        try {
            IMap<String, String> lockMap = hazelcastInstance.getMap(IDEMPOTENCY_LOCKS_MAP);
            String lockKey = "lock:txn:" + idempotencyKey;
            lockMap.remove(lockKey);
            logger.debug("Released lock for idempotency key: {}", idempotencyKey);
        } catch (Exception e) {
            logger.warn("Failed to release lock for idempotency key: {} - {}", idempotencyKey, e.getMessage());
        }
    }

    public void cacheAccountBalance(String accountNumber, BigDecimal balance) {
        try {
            IMap<String, String> balanceMap = hazelcastInstance.getMap(BALANCE_CACHE_MAP);
            String balanceKey = "bal:" + accountNumber;
            balanceMap.put(balanceKey, balance.toString());
            logger.debug("Cached balance for account {}: {}", accountNumber, balance);
        } catch (Exception e) {
            logger.warn("Failed to cache balance for account: {} - {}", accountNumber, e.getMessage());
        }
    }

    // Additional methods required by PaymentController
    public void releaseLockTransaction(String idempotencyKey) {
        releaseLock(idempotencyKey);
    }

    public BigDecimal getAccountBalance(String accountNumber) {
        try {
            IMap<String, String> balanceMap = hazelcastInstance.getMap(BALANCE_CACHE_MAP);
            String balanceKey = "bal:" + accountNumber;
            String cachedBalance = balanceMap.get(balanceKey);
            
            if (cachedBalance != null) {
                return new BigDecimal(cachedBalance);
            }
            
            // Simulate a balance check - in real implementation, this would call external service
            BigDecimal simulatedBalance = new BigDecimal("10000.00");
            cacheAccountBalance(accountNumber, simulatedBalance);
            logger.debug("Simulated balance for account {}: {}", accountNumber, simulatedBalance);
            
            return simulatedBalance;
        } catch (Exception e) {
            logger.error("Failed to get balance for account: {}", accountNumber, e);
            // Return a default balance if there's an error
            return new BigDecimal("0.00");
        }
    }
}