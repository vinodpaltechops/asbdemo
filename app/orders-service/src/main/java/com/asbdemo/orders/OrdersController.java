package com.asbdemo.orders;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/orders")
public class OrdersController {

    private final OrderPublisher publisher;
    private final Counter publishedCounter;

    public OrdersController(OrderPublisher publisher, MeterRegistry registry) {
        this.publisher = publisher;
        this.publishedCounter = Counter.builder("orders_published_total")
                .description("Orders published to Service Bus")
                .register(registry);
    }

    @PostMapping
    public ResponseEntity<Map<String, String>> create(@RequestBody CreateOrderRequest req) {
        OrderEvent event = new OrderEvent(
                UUID.randomUUID().toString(),
                req.amount(),
                req.customer(),
                Instant.now());
        publisher.publish(event);
        publishedCounter.increment();
        return ResponseEntity.accepted().body(Map.of("orderId", event.orderId()));
    }

    public record CreateOrderRequest(
            @NotNull @Positive BigDecimal amount,
            @NotBlank String customer
    ) {}
}
