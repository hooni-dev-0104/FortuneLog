package com.fortunelog.engine;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class EngineApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(EngineApiApplication.class, args);
    }
}
