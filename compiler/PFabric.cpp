#include <map>
#include <string>
#include <iostream>
#include <sstream>
#include <cassert>
#include <pcap.h>
#include <netinet/ether.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <iomanip>
#include "PFabric.h"
#include "util.h"

std::map<std::string, int> FlowRemainingSizeTable;

StrategyPFabric SchedStrategyPFabric(){
    StrategyPFabric strategyPFabric = new StrategyPFabric_;
    strategyPFabric->palce_holder = 0;
    return strategyPFabric;
}

void initFlowRemainingSizeHandler(unsigned char* user, const struct pcap_pkthdr* pkthdr, const unsigned char* packet) {
    std::string flowId = getFlowId(user, pkthdr, packet);

    if(FlowRemainingSizeTable.find(flowId) == FlowRemainingSizeTable.end()){
        FlowRemainingSizeTable[flowId] = pkthdr->len;
    }else{
        FlowRemainingSizeTable[flowId] += pkthdr->len;
    }
}

void pFabricInitFlowRemainingSize(const char* pcap_file){
    char errbuf[PCAP_ERRBUF_SIZE];
    pcap_t* pcap_handle;

    // 打开 pcap 文件
    pcap_handle = pcap_open_offline(pcap_file, errbuf);
    if (pcap_handle == nullptr) {
        std::cerr << "Error opening pcap file: " << errbuf << std::endl;
        return;
    }

    // 以数据包为单位处理 pcap 文件
    if (pcap_loop(pcap_handle, 0, initFlowRemainingSizeHandler, nullptr) < 0) {
        std::cerr << "Error in pcap_loop: " << pcap_geterr(pcap_handle) << std::endl;
        pcap_close(pcap_handle);
        return;
    }

    // 关闭 pcap 文件
    pcap_close(pcap_handle);
    
    return;
}

int calPFabricPriority(unsigned char* user, const struct pcap_pkthdr* pkthdr, const unsigned char* packet) {
    std::string flowId = getFlowId(user, pkthdr, packet);

    assert(FlowRemainingSizeTable.find(flowId) != FlowRemainingSizeTable.end());

    int priority = FlowRemainingSizeTable[flowId];

    assert(priority > 0);

    FlowRemainingSizeTable[flowId] -= pkthdr->len;

    return priority;
}
