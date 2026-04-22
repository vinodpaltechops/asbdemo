package com.asbdemo.orders;

import java.math.BigDecimal;
import java.time.Instant;

public record OrderEvent(
        String orderId,
        BigDecimal amount,
        String customer,
        Instant createdAt
) {}
