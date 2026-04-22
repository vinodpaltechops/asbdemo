package com.asbdemo.orders;

import com.azure.identity.DefaultAzureCredentialBuilder;
import com.azure.messaging.servicebus.ServiceBusClientBuilder;
import com.azure.messaging.servicebus.ServiceBusSenderClient;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ServiceBusConfig {

    private ServiceBusSenderClient sender;

    @Bean
    public ServiceBusSenderClient serviceBusSenderClient(
            @Value("${servicebus.namespace-fqdn}") String fqdn,
            @Value("${servicebus.queue-name}") String queueName) {
        this.sender = new ServiceBusClientBuilder()
                .fullyQualifiedNamespace(fqdn)
                .credential(new DefaultAzureCredentialBuilder().build())
                .sender()
                .queueName(queueName)
                .buildClient();
        return this.sender;
    }

    @PreDestroy
    void close() {
        if (sender != null) sender.close();
    }
}
