import Combine
import Foundation

/// UI visit witness only, not permission or cancellation of an already-dispatched original request.
public struct MerchantAnchorVisitAdmission {
    public private(set) var revision=UUID()
    public private(set) var visible=false
    public init() {}
    public mutating func appear(){visible=true;revision=UUID()}
    public mutating func invalidate(){revision=UUID()}
    public mutating func disappear(){visible=false;revision=UUID()}
    public func permits(_ captured:UUID,active:Bool,cancelled:Bool=false)->Bool {
        visible && revision==captured && active && !cancelled
    }
}

/// Configuration of the original F4 anchor only. Never verifies a visit or grants redemption.
@MainActor public final class MerchantDeskAnchorFlow: ObservableObject {
    public static let savePath="api/merchant/desk/anchor/save"
    @Published public private(set) var storeLatitude:Double?
    @Published public private(set) var storeLongitude:Double?
    @Published public private(set) var latitude:Double?
    @Published public private(set) var longitude:Double?
    @Published public private(set) var radius:Int?
    @Published public private(set) var version:Int?
    @Published public private(set) var configured=false
    @Published public private(set) var loaded=false
    @Published public private(set) var wifiCount=0
    @Published public private(set) var pending:[MerchantBusinessIntent]=[]
    @Published public private(set) var accepted=false
    @Published public private(set) var issue=false
    public enum ReadState:String,Equatable {case idle,loading,loaded,failed,notConfigured,denied}
    @Published public private(set) var readState:ReadState = .idle
    /// Strictly verified original identity, independent of current and journal completion.
    @Published public private(set) var knownRequestID:String?
    @Published public private(set) var knownTargetID:Int?
    private var historyCredential:String?
    @Published public private(set) var busy=false
    private let service:MerchantBusinessService
    private let transport:any HTTPTransport
    private let journal:any MerchantBusinessIntentStore
    private let scope:MerchantBusinessScope
    private let access:MerchantBusinessAccess
    private let token:()->String?
    private let current:()->Bool
    private let approved:()->Bool
    private let unauthorized:()->Void
    private var active=true
    private var generation=UUID()
    public init(service:MerchantBusinessService,transport:any HTTPTransport,journal:any MerchantBusinessIntentStore,scope:MerchantBusinessScope,access:MerchantBusinessAccess,token:@escaping ()->String?,current:@escaping ()->Bool,approved:@escaping ()->Bool,unauthorized:@escaping ()->Void){
        self.service=service;self.transport=transport;self.journal=journal;self.scope=scope;self.access=access
        self.token=token;self.current=current;self.approved=approved;self.unauthorized=unauthorized
    }
    public func suspend(){active=false;generation=UUID();storeLatitude=nil;storeLongitude=nil;latitude=nil;longitude=nil;radius=nil;version=nil;configured=false;loaded=false;wifiCount=0;pending=[];accepted=false;knownRequestID=nil;knownTargetID=nil;historyCredential=nil;readState = .idle;issue=false;busy=false}
    private func ensure(_ g:UUID,_ credential:String)throws{guard active,current(),token()==credential,generation==g,!Task.isCancelled else{throw CancellationError()}}
    private func journalRead()throws{pending=try journal.intents().filter{$0.realm==scope.realm && $0.accountID==scope.accountID && $0.merchantID==access.merchantID && $0.target.hasPrefix("anchor-config:")}}
    private func run(_ work:(UUID,String)async throws->Void)async{
        guard active,current(),!busy,let token=token() else{return};let g=generation;busy=true;issue=false
        defer{if generation==g{busy=false}}
        do{try journalRead();try await work(g,token)}catch{
            guard generation==g else{return}
            guard current(),self.token()==token else{suspend();return}
            if error as? APIError == .unauthorized{suspend();unauthorized();return}
            if error as? MerchantBusinessFailure == .denied{suspend();readState = .denied;issue=true;return}
            if !approved(){knownRequestID=nil;knownTargetID=nil;historyCredential=nil}
            storeLatitude=nil;storeLongitude=nil;latitude=nil;longitude=nil;radius=nil;version=nil;configured=false;loaded=false;wifiCount=0;accepted=false
            readState = error as? APIError == .notConfigured ? .notConfigured:.failed
            issue=true
        }
    }
    private func number(_ value:MerchantBusinessValue?)->Double?{guard let text=value?.numberText,let n=Double(text),n.isFinite else{return nil};return n}
    private func readCurrent(_ query:MerchantDeskRead,_ g:UUID,_ credential:String)async throws->MerchantBusinessValue {
        let fresh=try await service.access(token:credential);try ensure(g,credential)
        guard fresh==access else{throw MerchantBusinessFailure.denied};try fresh.require(query.permissions)
        let value=try await service.read(query,access:fresh,token:credential);try ensure(g,credential)
        let after=try await service.access(token:credential);try ensure(g,credential)
        guard after==fresh else{throw MerchantBusinessFailure.denied};try after.require(query.permissions)
        return value
    }
    private func refresh(_ g:UUID,_ token:String)async throws{
        let stores=try await readCurrent(.stores,g,token);try ensure(g,token)
        guard case .array(let rows)=stores,let store=rows.compactMap({$0.object}).first(where:{$0["storeId"]?.integer==access.merchantID}) else{throw MerchantBusinessFailure.malformed}
        let value=try await readCurrent(.anchor,g,token);try ensure(g,token)
        guard let row=value.object,let configured=row["configured"]?.bool,row["enforced"]?.bool==false else{throw MerchantBusinessFailure.malformed}
        if configured{guard let v=row["version"]?.integer,v>0,let r=row["radiusM"]?.integer,(30...500).contains(r),number(row["anchorLat"]) != nil,number(row["anchorLng"]) != nil else{throw MerchantBusinessFailure.malformed}}
        storeLatitude=number(store["locationLat"]);storeLongitude=number(store["locationLng"])
        self.configured=configured;version=row["version"]?.integer;latitude=number(row["anchorLat"]);longitude=number(row["anchorLng"]);radius=row["radiusM"]?.integer;wifiCount=row["wifiCount"]?.integer ?? 0;loaded=true;readState = .loaded
    }
    public func load()async{
        let known = active && current() && approved() && historyCredential==token() ? knownRequestID:nil
        let target=known == nil ? nil:knownTargetID
        suspend();active=true;knownRequestID=known;knownTargetID=target;historyCredential=known == nil ? nil:token();readState = .loading
        await run{g,t in try await refresh(g,t)}
    }
    public var hasKnownResult:Bool{active && current() && approved() && knownRequestID != nil && historyCredential==token()}
    public var isCurrent:Bool{active && current()}
    public var canSave:Bool{active && current() && approved() && loaded && journal.isDurable && !busy && pending.isEmpty && access.allows("merchant:profile:write")}
    public func save(latitude:Double,longitude:Double,radius:Int)async{
        guard canSave,latitude.isFinite,longitude.isFinite,(-90...90).contains(latitude),(-180...180).contains(longitude),latitude != 0 || longitude != 0,(30...500).contains(radius) else{return}
        let expected=version;let preserve=configured
        await run{g,t in
            let fresh=try await service.access(token:t);try ensure(g,t)
            guard fresh.merchantID==access.merchantID,fresh.role==access.role,approved() else{throw MerchantBusinessFailure.denied};try fresh.require(["merchant:profile:write"])
            let record=MerchantBusinessIntent(scope:scope,merchantID:access.merchantID,target:"anchor-config:\(expected ?? 0)",requestID:"anchor-"+UUID().uuidString.lowercased())
            var body:MerchantBusinessObject=["anchorLat":.number(Decimal(latitude)),"anchorLng":.number(Decimal(longitude)),"radiusM":.int(radius),"requestId":.string(record.requestID)]
            if let expected{body["expectedVersion"] = .int(expected)}
            if preserve{body["preserveWifi"] = .bool(true)}else{body["wifiBssids"] = .array([])}
            let request=try service.makeRequest(.json(Self.savePath,body),token:t)
            try journal.reserve(record);try journalRead();try ensure(g,t);guard approved() else{throw MerchantBusinessFailure.stale}
            let (_,status)=try await transport.send(request);try ensure(g,t)
            if status==401{throw APIError.unauthorized};if status==403{throw MerchantBusinessFailure.denied}
            // Regardless of POST response, only the original receipt proves acceptance.
            try await recover(record,g,t)
        }
    }
    public func recover(_ id:String)async{await run{g,t in guard let record=pending.first(where:{$0.requestID==id}) else{return};try await recover(record,g,t)}}
    private func recover(_ record:MerchantBusinessIntent,_ g:UUID,_ token:String)async throws{
        let result=try await readCurrent(.receipt(requestID:record.requestID),g,token);try ensure(g,token)
        guard let row=result.object,row["requestId"]?.string==record.requestID,row["state"]?.string=="APPLIED",row["action"]?.string=="ANCHOR_SAVE",row["targetType"]?.string=="merchant_redemption_anchor",let id=row["targetId"]?.integer,id>0 else{throw MerchantBusinessFailure.unknown}
        knownRequestID=record.requestID;knownTargetID=id;historyCredential=token
        try await refresh(g,token) // Current configuration is separate from historical acceptance.
        try ensure(g,token);try journal.complete(record);try journalRead();accepted=true
    }
}
