package com.asbdemo.orders;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;

import com.azure.messaging.servicebus.ServiceBusMessage;
import com.azure.messaging.servicebus.ServiceBusSenderClient;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
public class OrderPublisher {

    private static final Logger log = LoggerFactory.getLogger(OrderPublisher.class);

    private final ServiceBusSenderClient sender;
    private final ObjectMapper mapper;

    public OrderPublisher(ServiceBusSenderClient sender, ObjectMapper mapper) {
        this.sender = sender;
        this.mapper = mapper;
    }

    public void publish(OrderEvent event) {
        try {
            byte[] body = mapper.writeValueAsBytes(event);
            ServiceBusMessage msg = new ServiceBusMessage(body)
                    .setContentType(MediaType.APPLICATION_JSON_VALUE)
                    .setMessageId(event.orderId());
            sender.sendMessage(msg);
            log.info("Published order v3 orderId={} amount={} customer={}",
                    event.orderId(), event.amount(), event.customer());
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Failed to serialize OrderEvent", e);
        }
    }
}
