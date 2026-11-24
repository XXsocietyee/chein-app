import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct MerchantMarketingConsentOriginalGrant:Equatable,Hashable {
 public let merchantID:Int,ownerID:Int,channel:String,optedIn:Bool
 public init(merchantID:Int,ownerID:Int,channel:ComplianceMarketingChannel,optedIn:Bool)throws{
  guard merchantID>0,ownerID>0 else{throw APIError.invalidConfiguration};self.merchantID=merchantID;self.ownerID=ownerID;self.channel=channel.rawValue;self.optedIn=optedIn
 }
}
/// Independent exact endpoint scope, default nil at host. Never enables campaign dispatch or generic compliance writes.
public struct MerchantMarketingConsentOriginalApproval:Equatable {
 public let revision:UUID,baseURL:URL,namespace:String,accountID:Int,grants:Set<MerchantMarketingConsentOriginalGrant>,allowsAllValidRows:Bool
 public init(baseURL:URL,namespace:String,accountID:Int,grants:Set<MerchantMarketingConsentOriginalGrant> = [],revision:UUID=UUID(),allowsAllValidRows:Bool=false)throws{
  _ = try OperationEndpointApproval(baseURL:baseURL,namespace:namespace,accountID:accountID,paths:[MerchantMarketingConsentOriginalClient.path,MerchantMarketingConsentOriginalClient.resultPath])
  self.baseURL=baseURL;self.namespace=namespace;self.accountID=accountID;self.grants=grants;self.revision=revision;self.allowsAllValidRows=allowsAllValidRows
 }
 public func matches(_ c:RuntimeDependencyContext)->Bool{c.market == .china && c.baseURL.absoluteString.utf8.elementsEqual(baseURL.absoluteString.utf8) && c.session.namespace.utf8.elementsEqual(namespace.utf8) && c.session.accountID==accountID}
 public func permits(_ row:ComplianceMarketingConsent,_ channel:ComplianceMarketingChannel,_ optedIn:Bool)->Bool{
  if allowsAllValidRows && row.valid { return true }
  return grants.contains{ $0.merchantID==row.merchantRowId && $0.ownerID==row.merchantOwnerMemberId && $0.channel==channel.rawValue && $0.optedIn==optedIn }
 }
}
public struct MerchantMarketingConsentOriginalTarget:Equatable {
 public let merchantID:Int,ownerID:Int,channel:ComplianceMarketingChannel
 public init?(intent:CompliancePendingOperation){
  let p=intent.operation.split(separator:"|",omittingEmptySubsequences:false)
  guard p.count==4,p[0]=="marketing",let m=Int(p[1]),m>0,String(m)==String(p[1]),let o=Int(p[2]),o>0,String(o)==String(p[2]),let c=ComplianceMarketingChannel(rawValue:String(p[3])),MerchantMarketingConsentOriginalClient.validRequestID(intent.requestID) else{return nil}
  merchantID=m;ownerID=o;channel=c
 }
}
public struct MerchantMarketingConsentOriginalReceipt:Decodable,Equatable,Identifiable {
 public let receiptVersion:Int,actorId:Int,merchantRowId:Int,merchantOwnerMemberId:Int,channel:String,requestId:String,outcome:String
 public let consentId:Int?,eventType:String?,recordedAt:Int64?
 public var id:String{requestId+"|"+String(merchantRowId)+"|"+String(merchantOwnerMemberId)+"|"+channel}
 public var recorded:Bool{outcome=="RECORDED"}
 public func validate(_ intent:CompliancePendingOperation,session:ComplianceSession)throws{
  guard let target=MerchantMarketingConsentOriginalTarget(intent:intent),intent.scope==session.journalScope,receiptVersion==1,actorId==session.accountID,merchantRowId==target.merchantID,merchantOwnerMemberId==target.ownerID,channel==target.channel.rawValue,requestId.utf8.elementsEqual(intent.requestID.utf8) else{throw ComplianceFailure.readbackMismatch}
  if outcome=="NOT_OBSERVED"{guard consentId==nil,eventType==nil,recordedAt==nil else{throw ComplianceFailure.malformed};return}
  guard recorded,let expected=intent.marketingOptedIn,eventType==(expected ? "OPT_IN":"OPT_OUT"),(consentId ?? 0)>0,(recordedAt ?? 0)>0 else{throw ComplianceFailure.readbackMismatch}
 }
}
@MainActor public final class MerchantMarketingConsentOriginalClient {
 /// Original request IDs also include legacy non-UUID references; keep their exact format.
 public nonisolated static func validRequestID(_ value: String) -> Bool {
  value.utf8.count <= 64 && value.range(of: #"\A[A-Za-z0-9._:-]+\z"#, options: .regularExpression) != nil
 }
 public nonisolated static let path="api/merchant/crm/marketing-consents",resultPath=path+"/result"
 public let context:RuntimeDependencyContext,approval:MerchantMarketingConsentOriginalApproval
 private let transport:any HTTPTransport,current:()->RuntimeDependencyContext?,stillApproved:()->Bool
 private let unauthorized:()->Void
 private var sent:Set<String> = []
 public init(context:RuntimeDependencyContext,approval:MerchantMarketingConsentOriginalApproval,transport:any HTTPTransport,current:@escaping()->RuntimeDependencyContext?,stillApproved:@escaping()->Bool,onUnauthorized:@escaping()->Void = {}){self.context=context;self.approval=approval;self.transport=transport;self.current=current;self.stillApproved=stillApproved;self.unauthorized=onUnauthorized}
 public var isCurrent:Bool{ContentDraftContextFence.matches(current(), context) && current()?.session.role.utf8.elementsEqual(context.session.role.utf8) == true && context.role.utf8.elementsEqual(context.session.role.utf8) && approval.matches(context) && stillApproved()}
 public func matches(_ session:ComplianceSession)->Bool{isCurrent && session.accountID==context.session.accountID && session.epoch==context.session.epoch && session.namespace.utf8.elementsEqual(context.session.namespace.utf8) && session.market=="CN"}
 public func canWrite(_ row:ComplianceMarketingConsent,_ channel:ComplianceMarketingChannel,_ optedIn:Bool)->Bool{isCurrent && row.valid && approval.permits(row,channel,optedIn)}
 private func check(_ session:ComplianceSession)throws{guard matches(session) else{throw ComplianceFailure.unavailable};try Task.checkCancellation()}
 private func request(_ path:String,query:[String:String]=[:],body:[String:Any]?=nil)throws->URLRequest{
  var c=URLComponents(url:context.baseURL.appendingPathComponent(path),resolvingAgainstBaseURL:false)!;if !query.isEmpty{c.queryItems=query.sorted{$0.key<$1.key}.map{URLQueryItem(name:$0.key,value:$0.value)}}
  guard let url=c.url else{throw ComplianceFailure.invalidInput};var r=URLRequest(url:url);r.httpMethod=body==nil ? "GET":"POST";r.cachePolicy = .reloadIgnoringLocalCacheData;r.timeoutInterval=20;r.httpShouldHandleCookies=false
  r.setValue(context.session.token,forHTTPHeaderField:"Authorization");r.setValue("application/json",forHTTPHeaderField:"Accept")
  if let body{r.httpBody=try JSONSerialization.data(withJSONObject:body,options:.sortedKeys);r.setValue("application/json",forHTTPHeaderField:"Content-Type")};return r
 }
 private struct Envelope<T:Decodable>:Decodable{let code:Int;let data:T?}
 private func send<T:Decodable>(_ request:URLRequest,session:ComplianceSession,as:T.Type)async throws->T{
  try check(session);guard Self.accepts(request,context:context,approval:approval) else{throw ComplianceFailure.unavailable}
  let(data,status)=try await transport.send(request)
  // Retired or cancelled authentication responses cannot affect the new viewer.
  try check(session)
  if status==401{unauthorized();throw APIError.unauthorized};if status==403{throw MerchantBusinessFailure.denied}
  guard data.count<=2*1024*1024,let raw=String(data:data,encoding:.utf8),(try? ContentDraftJSON.parse(raw)) != nil else{throw ComplianceFailure.malformed}
  let e=try JSONDecoder().decode(Envelope<T>.self,from:data);if e.code==401{unauthorized();throw APIError.unauthorized};if e.code==403{throw MerchantBusinessFailure.denied}
  guard (200..<300).contains(status),e.code==200,let value=e.data else{throw ComplianceFailure.unresolved};try check(session);return value
 }
 public func list(session:ComplianceSession)async throws->[ComplianceMarketingConsent]{
  let rows:[ComplianceMarketingConsent]=try await send(request(Self.path),session:session,as:[ComplianceMarketingConsent].self)
  guard rows.allSatisfy(\.valid),Set(rows.map(\.merchantRowId)).count==rows.count else{throw ComplianceFailure.malformed};return rows
 }
 public func result(_ intent:CompliancePendingOperation,session:ComplianceSession)async throws->MerchantMarketingConsentOriginalReceipt{
  guard let target=MerchantMarketingConsentOriginalTarget(intent:intent),intent.marketingRealm?.utf8.elementsEqual(context.baseURL.absoluteString.utf8) == true else{throw ComplianceFailure.unresolved}
  let r:MerchantMarketingConsentOriginalReceipt=try await send(request(Self.resultPath,query:["merchantRowId":String(target.merchantID),"merchantOwnerMemberId":String(target.ownerID),"channel":target.channel.rawValue,"requestId":intent.requestID]),session:session,as:MerchantMarketingConsentOriginalReceipt.self)
  try r.validate(intent,session:session);return r
 }
 public func write(_ row:ComplianceMarketingConsent,channel:ComplianceMarketingChannel,optedIn:Bool,intent:CompliancePendingOperation,session:ComplianceSession)async throws{
  try check(session);guard canWrite(row,channel,optedIn),intent.scope==session.journalScope,intent.operation==row.operation(channel),intent.marketingOptedIn==optedIn,intent.marketingRealm?.utf8.elementsEqual(context.baseURL.absoluteString.utf8) == true,MerchantMarketingConsentOriginalClient.validRequestID(intent.requestID),!sent.contains(intent.requestID) else{throw ComplianceFailure.unresolved}
  let r=try request(Self.path,body:["merchantRowId":row.merchantRowId,"merchantOwnerMemberId":row.merchantOwnerMemberId,"channel":channel.rawValue,"optedIn":optedIn,"requestId":intent.requestID]);sent.insert(intent.requestID)
  // Original append-only writer response is not latest boolean proof. Exact GET is mandatory after this one dispatch.
  _ = try await send(r,session:session,as:MerchantBusinessValue.self)
 }
 public static func accepts(_ request:URLRequest,context:RuntimeDependencyContext,approval:MerchantMarketingConsentOriginalApproval)->Bool{
  guard approval.matches(context), !request.httpShouldHandleCookies, request.value(forHTTPHeaderField:"Accept")=="application/json", request.value(forHTTPHeaderField:"Authorization").map({ Data($0.utf8) }) == Data(context.session.token.utf8),request.value(forHTTPHeaderField:"Cookie")==nil,request.value(forHTTPHeaderField:"Proxy-Authorization")==nil,request.httpBodyStream==nil,let url=request.url,var parts=URLComponents(url:url,resolvingAgainstBaseURL:false),parts.fragment==nil else{return false}
  if request.httpMethod=="GET",request.httpBody==nil{
   if url==context.baseURL.appendingPathComponent(path){return true}
   guard let q=parts.queryItems,q.count==4,Set(q.map(\.name))==Set(["merchantRowId","merchantOwnerMemberId","channel","requestId"]) else{return false};parts.query=nil
   guard parts.url==context.baseURL.appendingPathComponent(resultPath) else{return false}
   for key in ["merchantRowId","merchantOwnerMemberId"]{guard let raw=q.first(where:{$0.name==key})?.value,let id=Int(raw),id>0,String(id)==raw else{return false}}
   guard let channel=q.first(where:{$0.name=="channel"})?.value,ComplianceMarketingChannel(rawValue:channel) != nil,let uuid=q.first(where:{$0.name=="requestId"})?.value,MerchantMarketingConsentOriginalClient.validRequestID(uuid) else{return false};return true
  }
  guard request.httpMethod=="POST",url==context.baseURL.appendingPathComponent(path),let data=request.httpBody,let raw=String(data:data,encoding:.utf8),(try? ContentDraftJSON.parse(raw)) != nil,
   let o=try? JSONDecoder().decode(MerchantBusinessValue.self,from:data).object,Set(o.keys)==Set(["merchantRowId","merchantOwnerMemberId","channel","optedIn","requestId"]),
   let merchant=try? o.mbInt("merchantRowId",minimum:1),let owner=try? o.mbInt("merchantOwnerMemberId",minimum:1),let channel=o.mbText("channel"),let c=ComplianceMarketingChannel(rawValue:channel),let choice=o["optedIn"]?.bool,let uuid=o.mbText("requestId"),MerchantMarketingConsentOriginalClient.validRequestID(uuid),
   let grant=try? MerchantMarketingConsentOriginalGrant(merchantID:merchant,ownerID:owner,channel:c,optedIn:choice),(approval.allowsAllValidRows || approval.grants.contains(grant)),let expected=try? JSONSerialization.data(withJSONObject:["merchantRowId":merchant,"merchantOwnerMemberId":owner,"channel":channel,"optedIn":choice,"requestId":uuid],options:.sortedKeys) else{return false}
  return data==expected && request.value(forHTTPHeaderField:"Content-Type")=="application/json"
 }
}

/// Read-only projection of pages/shezhi/marketing/index. It does not send a request,
/// grant a channel, or mark a route live. Unknown quantities stay an em dash, never 0.
public enum ShezhiMarketingIndexReadPhase: Equatable {
    case loading
    case empty
    case error(key: String)
    case unknown
    case ready
}

public struct ShezhiMarketingIndexPreferenceLine: Equatable {
    public let merchantText: String
    public let ownerText: String
    public let nameText: String
    public let inAppText: String
    public let couponText: String
    public let inAppUnresolved: Bool
    public let couponUnresolved: Bool
}

public struct ShezhiMarketingIndexReceiptLine: Equatable {
    public let requestText: String
    public let merchantText: String
    public let ownerText: String
    public let recordText: String
    public let recordedAtText: String
    public let outcomeKey: String
    public let channelKey: String
    public let eventKey: String
}

public struct ShezhiMarketingIndexPageModel: Equatable {
    /// Missing and UNKNOWN quantities use this mark. They are never shown as 0.
    public static let unknownMark = "—"
    /// Existing list contract. The leading slash matches the reviewed catalog key.
    public static let listPath = "/api/merchant/crm/marketing-consents"
    /// Original-result GET. Hidden here until that exact path is already live.
    public static let resultPath = "/api/merchant/crm/marketing-consents/result"
    public let phase: ShezhiMarketingIndexReadPhase
    public let merchantCountText: String
    /// Nil when nothing is unresolved. An unresolved or unloaded current list is an em dash, never 0.
    public let unresolvedText: String?
    public let preferences: [ShezhiMarketingIndexPreferenceLine]
    public let receipts: [ShezhiMarketingIndexReceiptLine]
    public let emptyKey: String
    public let loadingKey: String
    public let unknownKey: String
    public let unconfirmedKey: String
    public let errorKey: String?

    public init(state: ComplianceState) {
        emptyKey = "compliance.marketing.empty"
        loadingKey = "compliance.loading"
        unknownKey = "compliance.marketing.unknown"
        unconfirmedKey = "marketingOriginal.current.unconfirmed"
        let trimmedError = state.error?.trimmingCharacters(in: .whitespacesAndNewlines)
        let reportedError = (trimmedError?.isEmpty == false) ? trimmedError : nil
        if state.busy {
            phase = .loading
            errorKey = nil
        } else if let reportedError {
            phase = .error(key: reportedError)
            errorKey = reportedError
        } else if !state.marketingUnresolved.isEmpty || !state.marketingLoaded {
            phase = .unknown
            errorKey = nil
        } else if state.marketing.isEmpty {
            phase = .empty
            errorKey = nil
        } else {
            phase = .ready
            errorKey = nil
        }
        if state.marketingLoaded && !state.busy {
            merchantCountText = Self.countText(state.marketing.count)
            preferences = state.marketing.map { row in
                ShezhiMarketingIndexPreferenceLine(
                    merchantText: Self.identifierText(row.merchantRowId),
                    ownerText: Self.identifierText(row.merchantOwnerMemberId),
                    nameText: Self.nameText(row.merchantName),
                    inAppText: Self.optedInText(row.inAppOptedIn),
                    couponText: Self.optedInText(row.couponOptedIn),
                    inAppUnresolved: state.marketingUnresolved.contains(row.operation(.inApp)),
                    couponUnresolved: state.marketingUnresolved.contains(row.operation(.coupon))
                )
            }
        } else {
            merchantCountText = Self.unknownMark
            preferences = []
        }
        if !state.marketingLoaded || !state.marketingUnresolved.isEmpty {
            unresolvedText = Self.unknownMark
        } else {
            unresolvedText = nil
        }
        receipts = state.marketingOriginalResults.map(Self.receiptLine)
    }

    /// True only when the reviewed catalog already admits the list route. This does not mark it live.
    public var offersListRoute: Bool { Self.routeIsLive(Self.listPath) }

    /// True only when the reviewed catalog already admits the result route. It does not today.
    public var offersResultRoute: Bool { Self.routeIsLive(Self.resultPath) }

    public static func routeIsLive(_ path: String) -> Bool {
        ChinaReviewedRouteCapability.mark(for: path) == .liveInProduction
            && ChinaReviewedRouteCapability.admitsChinaProductionCall(path)
    }

    public static func outcomeKey(_ value: String) -> String {
        switch value {
        case "RECORDED": return "marketingOriginal.outcome.recorded"
        case "NOT_OBSERVED": return "marketingOriginal.outcome.notObserved"
        default: return "marketingOriginal.outcome.unknown"
        }
    }

    public static func eventKey(_ value: String?) -> String {
        switch value {
        case "OPT_IN": return "marketingOriginal.event.optIn"
        case "OPT_OUT": return "marketingOriginal.event.optOut"
        default: return "marketingOriginal.event.unknown"
        }
    }

    public static func channelKey(_ value: String) -> String {
        switch value {
        case "IN_APP": return "marketingOriginal.channel.inApp"
        case "COUPON": return "marketingOriginal.channel.coupon"
        default: return "marketingOriginal.channel.unknown"
        }
    }

    /// A canonical non-negative integer stays as written, including "0".
    /// UNKNOWN, blank, padded zeros, and non-integers stay an em dash.
    public static func countText(_ raw: String?) -> String {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return unknownMark }
        if text.uppercased() == "UNKNOWN" { return unknownMark }
        if text == "0" { return "0" }
        guard let first = text.utf8.first, first != 48, text.utf8.allSatisfy({ (48...57).contains($0) }) else { return unknownMark }
        return text
    }

    public static func countText(_ value: Int) -> String {
        guard value >= 0 else { return unknownMark }
        return String(value)
    }

    /// A positive identifier stays decimal. Zero, negative, and nil are unknown, never "0".
    public static func identifierText(_ value: Int?) -> String {
        guard let value, value > 0 else { return unknownMark }
        return String(value)
    }

    public static func identifierText(_ value: Int64?) -> String {
        guard let value, value > 0 else { return unknownMark }
        return String(value)
    }

    /// Nil is unknown. A known false stays the word false, never 0.
    public static func optedInText(_ value: Bool?) -> String {
        switch value {
        case nil: return unknownMark
        case true?: return "true"
        case false?: return "false"
        }
    }

    public static func nameText(_ value: String?) -> String {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return unknownMark }
        if text.uppercased() == "UNKNOWN" { return unknownMark }
        return text
    }

    /// A server-sent request id stays verbatim, including "0". Blank and UNKNOWN stay an em dash.
    public static func requestText(_ value: String?) -> String {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return unknownMark }
        if text.uppercased() == "UNKNOWN" { return unknownMark }
        return text
    }

    public static func receiptLine(_ receipt: MerchantMarketingConsentOriginalReceipt) -> ShezhiMarketingIndexReceiptLine {
        ShezhiMarketingIndexReceiptLine(
            requestText: requestText(receipt.requestId),
            merchantText: identifierText(receipt.merchantRowId),
            ownerText: identifierText(receipt.merchantOwnerMemberId),
            recordText: identifierText(receipt.consentId),
            recordedAtText: identifierText(receipt.recordedAt),
            outcomeKey: outcomeKey(receipt.outcome),
            channelKey: channelKey(receipt.channel),
            eventKey: eventKey(receipt.eventType)
        )
    }
}

extension AccountComplianceCoordinator {
    /// Existing coordinator state only. Reading this does not load or write marketing consent.
    public var shezhiMarketingIndexPage: ShezhiMarketingIndexPageModel {
        ShezhiMarketingIndexPageModel(state: state)
    }
}
