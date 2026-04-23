package com.asbdemo.payments;

import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.messaging.servicebus.ServiceBusClientBuilder;
import com.azure.messaging.servicebus.ServiceBusProcessorClient;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ServiceBusProcessorConfig {

    private static final Logger log = LoggerFactory.getLogger(ServiceBusProcessorConfig.class);

    private ServiceBusProcessorClient processor;

    @Bean
    public ServiceBusProcessorClient processorClient(
            @Value("${servicebus.namespace-fqdn}") String fqdn,
            @Value("${servicebus.queue-name}") String queue,
            ObjectMapper mapper,
            MeterRegistry registry) {

        Counter processed = Counter.builder("orders_processed_total")
                .description("Orders received from Service Bus")
                .register(registry);
        Counter failed = Counter.builder("orders_failed_total")
                .description("Orders that failed processing")
                .register(registry);

        this.processor = new ServiceBusClientBuilder()
                .fullyQualifiedNamespace(fqdn)
                .credential(new DefaultAzureCredentialBuilder().build())
                .processor()
                .queueName(queue)
                .maxConcurrentCalls(4)
                .processMessage(ctx -> {
                    try {
                        OrderEvent event = mapper.readValue(
                                ctx.getMessage().getBody().toBytes(), OrderEvent.class);
                        log.info("Processed order orderId={} amount={} customer={}",
                                event.orderId(), event.amount(), event.customer());
                        processed.increment();
                        ctx.complete();
                    } catch (Exception e) {
                        log.error("Failed to process message messageId={}",
                                ctx.getMessage().getMessageId(), e);
                        failed.increment();
                        ctx.abandon();
                    }
                })
                .processError(err ->
                        log.error("Service Bus processor error source={}",
                                err.getErrorSource(), err.getException()))
                .buildProcessorClient();

        return this.processor;
    }

    @Bean
    public ApplicationRunner processorStarter(ServiceBusProcessorClient client) {
        return args -> {
            log.info("Starting Service Bus processor");
            client.start();
        };
    }

    @PreDestroy
    void stop() {
        if (processor != null) processor.close();
    }
}
