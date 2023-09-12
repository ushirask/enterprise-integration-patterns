import ballerina/http;
import ballerina/mqtt;

type RoutingEntry record {|
    string deviceId;
    int roomNo;
    boolean dimmable;
|};

type SwitchRequest record {|
    int roomNo;
    State state;
|};

enum State {
    ON,
    OFF,
    DIM
}

final http:Client deviceClient = check new ("http://api.devices.com.balmock.io");
map<RoutingEntry> routingTable = {};

service /bulbs on new http:Listener(8080) {

    resource function post switch(SwitchRequest switchRequest) returns error? {
        RoutingEntry? entry = routingTable[switchRequest.roomNo.toString()];
        if entry == () {
            return error("Invalid room");
        }
        if switchRequest.state == DIM && !entry.dimmable {
            return error("Bulb is not dimmable");
        }
        json _ = check deviceClient->/[entry.deviceId]/[switchRequest.state];
    }
}

listener mqtt:Listener mqttSubscriber = check new (mqtt:DEFAULT_URL, "routermqttlistener", "bulb/config");

service on mqttSubscriber {
    remote function onMessage(mqtt:Message message, mqtt:Caller caller) returns error? {
        RoutingEntry entry = check (check string:fromBytes(message.payload)).fromJsonStringWithType();
        routingTable[entry.roomNo.toString()] = entry;
        check caller->complete();
    }
}
