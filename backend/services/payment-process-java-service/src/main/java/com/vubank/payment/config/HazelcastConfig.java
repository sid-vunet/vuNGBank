package com.vubank.payment.config;

import com.hazelcast.config.*;
import com.hazelcast.core.Hazelcast;
import com.hazelcast.core.HazelcastInstance;
import com.hazelcast.spring.context.SpringAware;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class HazelcastConfig {

    @Value("${hazelcast.cluster.name:vubank-payment-cluster}")
    private String clusterName;

    @Value("${hazelcast.network.port:5701}")
    private int networkPort;

    @Value("${hazelcast.network.port-auto-increment:true}")
    private boolean portAutoIncrement;

    @Value("${hazelcast.multicast.enabled:true}")
    private boolean multicastEnabled;

    @Value("${hazelcast.tcp-ip.enabled:false}")
    private boolean tcpIpEnabled;

    @Value("#{'${hazelcast.tcp-ip.members:}'.split(',')}")
    private List<String> tcpIpMembers;

    @Bean
    public HazelcastInstance hazelcastInstance() {
        Config config = new Config();
        config.setClusterName(clusterName);
        
        // Instance name for identification
        config.setInstanceName("vubank-payment-hazelcast");
        
        // Network configuration
        NetworkConfig networkConfig = config.getNetworkConfig();
        networkConfig.setPort(networkPort);
        networkConfig.setPortAutoIncrement(portAutoIncrement);
        
        // Join configuration - prefer multicast for simplicity in containers
        JoinConfig joinConfig = networkConfig.getJoin();
        
        if (multicastEnabled) {
            MulticastConfig multicastConfig = joinConfig.getMulticastConfig();
            multicastConfig.setEnabled(true);
            multicastConfig.setMulticastGroup("224.2.2.3");
            multicastConfig.setMulticastPort(54327);
        } else {
            joinConfig.getMulticastConfig().setEnabled(false);
        }
        
        if (tcpIpEnabled) {
            TcpIpConfig tcpIpConfig = joinConfig.getTcpIpConfig();
            tcpIpConfig.setEnabled(true);
            tcpIpMembers.stream()
                .filter(member -> !member.trim().isEmpty())
                .forEach(tcpIpConfig::addMember);
        } else {
            joinConfig.getTcpIpConfig().setEnabled(false);
        }

        // Disable other join mechanisms
        joinConfig.getAutoDetectionConfig().setEnabled(false);
        joinConfig.getAwsConfig().setEnabled(false);
        joinConfig.getGcpConfig().setEnabled(false);
        joinConfig.getAzureConfig().setEnabled(false);
        joinConfig.getKubernetesConfig().setEnabled(false);
        joinConfig.getEurekaConfig().setEnabled(false);

        // Configure transaction state map
        MapConfig transactionMapConfig = new MapConfig("transaction-states");
        transactionMapConfig.setTimeToLiveSeconds(172800); // 48 hours
        transactionMapConfig.setMaxIdleSeconds(86400); // 24 hours idle
        transactionMapConfig.setEvictionConfig(new EvictionConfig()
            .setEvictionPolicy(EvictionPolicy.LRU)
            .setMaxSizePolicy(MaxSizePolicy.PER_NODE)
            .setSize(10000));
        config.addMapConfig(transactionMapConfig);

        // Configure balance cache map
        MapConfig balanceMapConfig = new MapConfig("balance-cache");
        balanceMapConfig.setTimeToLiveSeconds(300); // 5 minutes
        balanceMapConfig.setMaxIdleSeconds(600); // 10 minutes idle
        balanceMapConfig.setEvictionConfig(new EvictionConfig()
            .setEvictionPolicy(EvictionPolicy.LRU)
            .setMaxSizePolicy(MaxSizePolicy.PER_NODE)
            .setSize(5000));
        config.addMapConfig(balanceMapConfig);

        // Configure idempotency locks map
        MapConfig lockMapConfig = new MapConfig("idempotency-locks");
        lockMapConfig.setTimeToLiveSeconds(3600); // 1 hour
        lockMapConfig.setMaxIdleSeconds(1800); // 30 minutes idle
        lockMapConfig.setEvictionConfig(new EvictionConfig()
            .setEvictionPolicy(EvictionPolicy.LRU)
            .setMaxSizePolicy(MaxSizePolicy.PER_NODE)
            .setSize(1000));
        config.addMapConfig(lockMapConfig);

        // Management center configuration (optional)
        config.getManagementCenterConfig().setConsoleEnabled(false);

        // Enable Spring integration (removed setSpringAware as it doesn't exist in this version)

        // Serialization configuration for better performance
        SerializationConfig serializationConfig = config.getSerializationConfig();
        serializationConfig.setEnableCompression(true);

        return Hazelcast.newHazelcastInstance(config);
    }
}