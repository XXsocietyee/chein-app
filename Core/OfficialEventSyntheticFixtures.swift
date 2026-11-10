#if DEBUG
/// Synthetic records only: no real accounts, remote artwork, coordinates or credentials.
public enum OfficialEventSyntheticFixtures {
    public static let eventJSON = #"""
    {"id":71,"title":"Synthetic city lights","subtitle":"Offline official event","city":"Example city","status":3,"story":"An original synthetic event story for native UI verification.","participants":12,"signed":true,"myProgress":2,"contractVersion":2,"activityStart":"2030-01-01 10:00:00","activityEnd":1893549600000,"paused":false,"eligible":false,"roamEnabled":true,"bannerEnabled":"1","category":"city_light","rewardJson":"{\"settleBadge\":true,\"settleXp\":25}","missions":[{"missionCode":"sample-arrival","title":"Sample arrival task","description":"Arrival verification is unavailable in this read-only module.","missionType":"ARRIVAL","complete":false,"canVerifyArrival":true},{"missionCode":"sample-theme","title":"Sample theme task","missionType":"THEME_VERIFIED_FINISH","complete":true,"binding":{"bindingType":"THEME","sourceRefId":"501"}}],"collective":{"enabled":true,"current":12,"threshold":100,"pct":12,"reached":false}}
    """#
    public static let eventsJSON = #"""
    [{"id":71,"title":"Synthetic city lights","subtitle":"Offline official event","city":"Example city","status":3},{"id":72,"title":"Synthetic next chapter","status":1},{"id":73,"title":"Synthetic past event","status":5},{"id":74,"title":"Synthetic registration event","status":2}]
    """#
    public static let inboxJSON = #"""
    [{"partyId":81,"title":"Synthetic organizer invitation","partyType":"OFFICIAL","eventTitle":"Synthetic city lights","status":"INVITED"},{"partyId":82,"partyName":"Synthetic merchant invitation","partyType":"MERCHANT","status":"ACCEPTED"},{"partyId":83,"responsibilitySummary":"Synthetic club invitation","partyType":"CLUB","status":"ACTIVE"},{"partyId":84,"title":"Synthetic unknown invitation","partyType":"FUTURE","state":"INVITED"}]
    """#
    public static let publishedJSON = #"""
    {"events":[{"id":71,"title":"Synthetic published event","status":3}],"broadcasts":[{"id":91,"title":"Synthetic notice","content":"A synthetic notice for read-only inspection.","reach":7}]}
    """#
    public static let statsJSON = #"""
    {"reach":7,"reads":4,"clicks":2,"sourceLabel":"Synthetic","enabled":true,"unmappedMetric":9,"internalObject":{"ignored":true},"history":[1,2],"nullValue":null}
    """#
}

/// Detail-page bytes for OfficialEventDetailPageState. No account, URL, or credential.
public enum OfficialEventDetailFixtureData {
    public static let content = OfficialEventSyntheticFixtures.eventJSON
    public static let unknown = #"{"id":71,"title":"Synthetic incomplete facts"}"#
    public static let empty = "{}"
    public static let literalZero = #"{"id":71,"title":"Synthetic zero","status":3,"participants":0,"signed":true,"myProgress":0}"#
    public static let countedTasks = #"{"id":71,"title":"Synthetic counted","status":3,"participants":0,"signed":true,"contractVersion":2,"missions":[{}]}"#
}

/// DEBUG bytes for the official invitation inbox. No transport, host, token, or credential.
public enum OfficialInboxFixtureData {
    public static let content = Data(OfficialEventSyntheticFixtures.inboxJSON.utf8)
    public static let empty = Data("[]".utf8)
    public static let zeroCapacity = Data(#"[{"partyId":86,"title":"Synthetic zero capacity","partyType":"MERCHANT","status":"INVITED","capacity":0}]"#.utf8)
    public static let unknownCapacity = Data(#"[{"partyId":85,"title":"Synthetic unknown capacity","partyType":"MERCHANT","status":"INVITED","capacity":"UNKNOWN"}]"#.utf8)
    public static let unreadable = Data(#"{"not":"a list"}"#.utf8)
}

/// Synthetic page bytes for pages/activity/official-mine/index.
/// Debug builds only. No account, credential, coordinate, or live route.
public enum OfficialMinePageFixtureData {
    public static let ready = OfficialEventSyntheticFixtures.publishedJSON
    public static let empty = #"{"events":[],"broadcasts":[]}"#
    public static let missingReach = #"{"events":[{"id":71,"title":"Synthetic published event","status":3}],"broadcasts":[{"id":91,"title":"Synthetic notice"}]}"#
    public static let zeroReach = #"{"events":[],"broadcasts":[{"id":91,"title":"Synthetic notice","reachedCount":0}]}"#
    public static let unknownReach = #"{"events":[],"broadcasts":[{"id":91,"title":"Synthetic notice","reachedCount":"UNKNOWN"}]}"#
    public static let negativeReach = #"{"events":[],"broadcasts":[{"id":91,"title":"Synthetic notice","reachedCount":-3}]}"#
}
#endif
