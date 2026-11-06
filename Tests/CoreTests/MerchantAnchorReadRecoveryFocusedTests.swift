import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@MainActor final class MerchantAnchorReadRecoveryFocusedTests:XCTestCase {
 @MainActor private final class Journal:MerchantBusinessIntentStore {
  let isDurable=true
  var rows:[MerchantBusinessIntent]=[]
  func intents()throws->[MerchantBusinessIntent]{rows}
  func reserve(_ intent:MerchantBusinessIntent)throws{rows.append(intent)}
  func complete(_ intent:MerchantBusinessIntent)throws{rows.removeAll{$0==intent}}
 }
 @MainActor private final class Wire:MerchantBusinessTestTransport {
  var allowed=true,unknown=false,postThrows=false,anchorFails=false
  var version=1,radius=50
  var malformed=false,denied=false,unconfigured=false
  var receiptAction="ANCHOR_SAVE",receiptType="merchant_redemption_anchor",receiptTarget=7
  var requests:[URLRequest]=[]
  var afterAccess:(()async throws->Void)?
  var afterSave:(()->Void)?
  var afterAnchor:(()async throws->Void)?
  var afterReceipt:(()->Void)?
  func send(_ r:URLRequest)async throws->(Data,Int){requests.append(r);let path=r.url!.path;let value:MerchantBusinessValue
   if path.hasSuffix("/access/me"){try await afterAccess?();value = .object(["active":.bool(allowed),"merchant":.object(["id":.int(31)]),"roleCode":.string("MERCHANT_OWNER"),"permissions":.array([.string("merchant:basic:read"),.string("merchant:profile:write")])])}
   else if path.hasSuffix("/stores"){value = .array([.object(["storeId":.int(31),"locationLat":.number(31),"locationLng":.number(121)])])}
   else if path.hasSuffix("/anchor/save"){let b=try JSONDecoder().decode(MerchantBusinessValue.self,from:r.httpBody!).object!;version+=1;radius=b["radiusM"]!.integer!;afterSave?();if postThrows{throw APIError.notConfigured};value = .object([:])}
   else if path.hasSuffix("/receipt"){let b=try JSONDecoder().decode(MerchantBusinessValue.self,from:r.httpBody!).object!;value = .object(["requestId":b["requestId"]!,"state":.string(unknown ? "UNKNOWN":"APPLIED"),"action":.string(receiptAction),"targetType":.string(receiptType),"targetId":.int(receiptTarget)]);afterReceipt?()}
   else{if denied{throw MerchantBusinessFailure.denied};if malformed{throw MerchantBusinessFailure.malformed};if anchorFails{throw APIError.notConfigured};value = unconfigured ? .object(["configured":.bool(false),"enforced":.bool(false),"wifiCount":.int(0)]):.object(["configured":.bool(true),"enforced":.bool(false),"version":.int(version),"anchorLat":.number(31),"anchorLng":.number(121),"radiusM":.int(radius),"wifiCount":.int(2)]);try await afterAnchor?()}
   return(try JSONEncoder().encode(MerchantBusinessValue.object(["code":.int(200),"data":value])),200)
  }
 }
 private func flow(_ w:Wire,_ j:Journal?=nil,account:Int=21,token:@escaping()->String?={"token"},current:@escaping()->Bool={true},unauthorized:@escaping()->Void={})throws->MerchantDeskAnchorFlow {
  let service=try MerchantBusinessService(configuration:.init(baseURL:URL(string:"https://anchor.example")!),readTransport:w)
  let access=try MerchantBusinessAccess(["active":.bool(true),"merchant":.object(["id":.int(31)]),"roleCode":.string("MERCHANT_OWNER"),"permissions":.array([.string("merchant:basic:read"),.string("merchant:profile:write")])])
  return .init(service:service,transport:w,journal:j ?? Journal(),scope:.init(realm:service.realm,accountID:account,epoch:1),access:access,token:token,current:current,approved:{true},unauthorized:unauthorized)
 }

 func testFirstReadFailureHasNoOriginalIdentityOrWrite()async throws{
  let w=Wire(),j=Journal(),f=try flow(w,j);w.malformed=true;await f.load()
  XCTAssertEqual(f.readState,.failed);XCTAssertNil(f.knownRequestID);XCTAssertFalse(f.accepted);XCTAssertTrue(j.rows.isEmpty)
  w.malformed=false;await f.load();XCTAssertTrue(f.loaded);XCTAssertFalse(w.requests.contains{$0.url!.path.hasSuffix("/anchor/save")})
 }
 func testStrictReceiptSurvivesIndependentCurrentFailureWithoutCompletingSlot()async throws{
  let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();w.afterReceipt={w.malformed=true}
  await f.save(latitude:31,longitude:121,radius:80)
  let id=try XCTUnwrap(j.rows.first?.requestID);XCTAssertEqual(f.knownRequestID,id);XCTAssertFalse(f.accepted);XCTAssertFalse(f.loaded)
  await f.load();XCTAssertEqual(f.knownRequestID,id);XCTAssertEqual(j.rows.count,1)
  w.malformed=false;w.afterReceipt=nil;await f.recover(id);XCTAssertTrue(f.accepted);XCTAssertTrue(j.rows.isEmpty)
  XCTAssertEqual(w.requests.filter{$0.url!.path.hasSuffix("/anchor/save")}.count,1)
 }
 func testPreviouslyCompletedResultSurvivesLaterNetworkAndFormatErrors()async throws{
  let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();await f.save(latitude:31,longitude:121,radius:80)
  let id=try XCTUnwrap(f.knownRequestID);w.anchorFails=true;await f.load();XCTAssertEqual(f.knownRequestID,id);XCTAssertFalse(f.loaded)
  w.anchorFails=false;w.malformed=true;await f.load();XCTAssertEqual(f.knownRequestID,id);XCTAssertTrue(j.rows.isEmpty)
 }
 func testCurrentDenialRetiresKnownHistoryButPreservesDiskSlot()async throws{
  let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();w.afterReceipt={w.denied=true};await f.save(latitude:31,longitude:121,radius:80)
  XCTAssertEqual(f.readState,.denied);XCTAssertNil(f.knownRequestID);XCTAssertTrue(f.pending.isEmpty);XCTAssertEqual(j.rows.count,1);XCTAssertFalse(f.canSave)
 }
 func testUnknownIsNeverMadeKnownByOrdinaryCurrent()async throws{
  let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();w.unknown=true;await f.save(latitude:31,longitude:121,radius:80)
  let id=j.rows[0].requestID;await f.load();XCTAssertNil(f.knownRequestID);XCTAssertFalse(f.accepted);XCTAssertEqual(f.pending.first?.requestID,id)
 }
 func testStrictOriginalMatcherStillRejectsWrongActionTypeAndTarget()async throws{
  for mode in 0..<3{let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();if mode==0{w.receiptAction="OTHER"};if mode==1{w.receiptType="pms_store"};if mode==2{w.receiptTarget=0};await f.save(latitude:31,longitude:121,radius:80);XCTAssertNil(f.knownRequestID);XCTAssertEqual(j.rows.count,1)}
 }
 func testLeavingAndReopeningSameOwnerDoesNotRetainMemoryReceipt()async throws{
  let w=Wire(),f=try flow(w);await f.load();await f.save(latitude:31,longitude:121,radius:80);XCTAssertNotNil(f.knownRequestID);f.suspend();await f.load();XCTAssertNil(f.knownRequestID)
 }
 func testNewCredentialClearsKnownHistoryBeforeReadFailure()async throws{
  let w=Wire();var token="token";let f=try flow(w,token:{token});await f.load();await f.save(latitude:31,longitude:121,radius:80);token="new";w.malformed=true;await f.load();XCTAssertNil(f.knownRequestID)
 }
 func testOldSameOwnerAccessDenialCannotClearNewVisit()async throws{
  let w=Wire(),f=try flow(w);w.afterAccess={w.afterAccess=nil;f.suspend();await f.load();throw MerchantBusinessFailure.denied};await f.load();XCTAssertTrue(f.loaded);XCTAssertEqual(f.readState,.loaded)
 }
 func testNormalReadRemainsEditableWithoutMintingRequest()async throws{
  let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();XCTAssertTrue(f.canSave);XCTAssertTrue(j.rows.isEmpty);XCTAssertNil(f.knownRequestID)
 }
 func testUnconfiguredAnchorKeepsExplicitEmptyWiFiSemantics()async throws{
  let w=Wire(),j=Journal(),f=try flow(w,j);w.unconfigured=true;await f.load();XCTAssertTrue(f.loaded);XCTAssertFalse(f.configured);XCTAssertNil(f.version);XCTAssertTrue(j.rows.isEmpty)
  await f.save(latitude:31,longitude:121,radius:30);let request=try XCTUnwrap(w.requests.first{$0.url!.path.hasSuffix("/anchor/save")});let fields=try JSONDecoder().decode(MerchantBusinessValue.self,from:request.httpBody!).object!
  XCTAssertEqual(fields["wifiBssids"],.array([]));XCTAssertNil(fields["preserveWifi"]);XCTAssertNil(fields["expectedVersion"])
 }

}
