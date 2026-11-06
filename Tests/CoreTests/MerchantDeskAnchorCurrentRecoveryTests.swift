import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@MainActor final class MerchantDeskAnchorCurrentRecoveryTests:XCTestCase {
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
  var requests:[URLRequest]=[]
  var afterAccess:(()async throws->Void)?
  var afterSave:(()->Void)?
  var afterAnchor:(()async throws->Void)?
  var afterReceipt:(()->Void)?
  func send(_ r:URLRequest)async throws->(Data,Int){requests.append(r);let path=r.url!.path;let value:MerchantBusinessValue
   if path.hasSuffix("/access/me"){try await afterAccess?();value = .object(["active":.bool(allowed),"merchant":.object(["id":.int(31)]),"roleCode":.string("MERCHANT_OWNER"),"permissions":.array([.string("merchant:basic:read"),.string("merchant:profile:write")])])}
   else if path.hasSuffix("/stores"){value = .array([.object(["storeId":.int(31),"locationLat":.number(31),"locationLng":.number(121)])])}
   else if path.hasSuffix("/anchor/save"){let b=try JSONDecoder().decode(MerchantBusinessValue.self,from:r.httpBody!).object!;version+=1;radius=b["radiusM"]!.integer!;afterSave?();if postThrows{throw APIError.notConfigured};value = .object([:])}
   else if path.hasSuffix("/receipt"){let b=try JSONDecoder().decode(MerchantBusinessValue.self,from:r.httpBody!).object!;value = .object(["requestId":b["requestId"]!,"state":.string(unknown ? "UNKNOWN":"APPLIED"),"action":.string("ANCHOR_SAVE"),"targetType":.string("merchant_redemption_anchor"),"targetId":.int(7)]);afterReceipt?()}
   else{if anchorFails{throw APIError.notConfigured};value = .object(["configured":.bool(true),"enforced":.bool(false),"version":.int(version),"anchorLat":.number(31),"anchorLng":.number(121),"radiusM":.int(radius),"wifiCount":.int(2)]);try await afterAnchor?()}
   return(try JSONEncoder().encode(MerchantBusinessValue.object(["code":.int(200),"data":value])),200)
  }
 }
 private func flow(_ w:Wire,_ j:Journal?=nil,account:Int=21,token:@escaping()->String?={"token"},current:@escaping()->Bool={true},unauthorized:@escaping()->Void={})throws->MerchantDeskAnchorFlow {
  let service=try MerchantBusinessService(configuration:.init(baseURL:URL(string:"https://anchor.example")!),readTransport:w)
  let access=try MerchantBusinessAccess(["active":.bool(true),"merchant":.object(["id":.int(31)]),"roleCode":.string("MERCHANT_OWNER"),"permissions":.array([.string("merchant:basic:read"),.string("merchant:profile:write")])])
  return .init(service:service,transport:w,journal:j ?? Journal(),scope:.init(realm:service.realm,accountID:account,epoch:1),access:access,token:token,current:current,approved:{true},unauthorized:unauthorized)
 }
 func testNormalReadUsesFreshAuthorityAroundEachOriginalReader()async throws{let w=Wire(),f=try flow(w);await f.load();XCTAssertTrue(f.loaded);XCTAssertEqual(f.radius,50);XCTAssertEqual(w.requests.filter{$0.url!.path.hasSuffix("/access/me")}.count,4)}
 func testRevokeDuringCurrentReadClearsCurrent()async throws{let w=Wire(),f=try flow(w);w.afterAnchor={w.allowed=false};await f.load();XCTAssertFalse(f.loaded);XCTAssertNil(f.radius);XCTAssertFalse(f.canSave)}
 func testChangedTokenRejectsLateCurrent()async throws{let w=Wire();var token="token";let f=try flow(w,token:{token});w.afterAnchor={token="other"};await f.load();XCTAssertFalse(f.loaded);XCTAssertNil(f.latitude)}
 func testBackgroundLateCurrentCannotRepopulate()async throws{let w=Wire(),f=try flow(w);w.afterAnchor={f.suspend()};await f.load();XCTAssertFalse(f.loaded);XCTAssertFalse(f.isCurrent)}
 func testNewLoadBeatsOldDeniedError()async throws{let w=Wire(),f=try flow(w);w.afterAnchor={w.afterAnchor=nil;w.version=2;w.radius=80;await f.load();throw MerchantBusinessFailure.denied};await f.load();XCTAssertTrue(f.loaded);XCTAssertEqual(f.version,2);XCTAssertEqual(f.radius,80);XCTAssertFalse(f.issue)}
 func testSavePreservesOriginalWiFiAndCASPayload()async throws{let w=Wire(),f=try flow(w);await f.load();await f.save(latitude:31,longitude:121,radius:80);let request=w.requests.first{$0.url!.path.hasSuffix("/anchor/save")}!;let body=try JSONDecoder().decode(MerchantBusinessValue.self,from:request.httpBody!).object!;XCTAssertEqual(body["preserveWifi"],.bool(true));XCTAssertEqual(body["expectedVersion"],.int(1));XCTAssertNil(body["wifiBssids"]);XCTAssertTrue(f.accepted);XCTAssertEqual(f.radius,80)}
 func testUnknownRetainsOriginalRequestWithoutResend()async throws{let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();w.unknown=true;await f.save(latitude:31,longitude:121,radius:80);let id=f.pending.first!.requestID;await f.recover(id);XCTAssertEqual(j.rows.count,1);XCTAssertEqual(w.requests.filter{$0.url!.path.hasSuffix("/anchor/save")}.count,1)}
 func testCurrentFailureAfterReceiptKeepsRecoveryIdentity()async throws{let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();w.afterReceipt={w.anchorFails=true};await f.save(latitude:31,longitude:121,radius:80);XCTAssertEqual(j.rows.count,1);XCTAssertFalse(f.loaded);w.afterReceipt=nil;w.anchorFails=false;await f.recover(j.rows[0].requestID);XCTAssertTrue(j.rows.isEmpty);XCTAssertEqual(f.radius,80)}
 func testRestartRecoversOriginalLostPostResponse()async throws{let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();w.postThrows=true;await f.save(latitude:31,longitude:121,radius:90);let id=j.rows[0].requestID;f.suspend();let restored=try flow(w,j);await restored.load();XCTAssertEqual(restored.pending.first?.requestID,id);await restored.recover(id);XCTAssertTrue(j.rows.isEmpty);XCTAssertEqual(restored.radius,90)}
 func testNewAccountCannotReadOldJournal()async throws{let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();w.postThrows=true;await f.save(latitude:31,longitude:121,radius:90);let other=try flow(w,j,account:22);await other.load();XCTAssertTrue(other.pending.isEmpty);XCTAssertEqual(j.rows.count,1)}
 func testOriginRetiredHidesSourceAndDoesNotDispatch()async throws{let w=Wire();var current=true;let f=try flow(w,current:{current});await f.load();current=false;XCTAssertFalse(f.isCurrent);await f.save(latitude:31,longitude:121,radius:80);XCTAssertFalse(w.requests.contains{$0.url!.path.hasSuffix("/anchor/save")})}
 func testChangedCredentialOld401CannotInvokeUnauthorized()async throws{let w=Wire();var token="token",revoked=0;let f=try flow(w,token:{token},unauthorized:{revoked+=1});w.afterAccess={token="new";throw APIError.unauthorized};await f.load();XCTAssertEqual(revoked,0);XCTAssertFalse(f.isCurrent);XCTAssertFalse(f.loaded)}
 func testCurrent401StillRetiresAndNotifies()async throws{let w=Wire();var revoked=0;let f=try flow(w,unauthorized:{revoked+=1});w.afterAccess={throw APIError.unauthorized};await f.load();XCTAssertEqual(revoked,1);XCTAssertFalse(f.isCurrent)}
 func testQueuedReloadCannotReactivateExitedVisit()async throws{let w=Wire(),f=try flow(w);var visit=MerchantAnchorVisitAdmission();visit.appear();let captured=visit.revision;let queued:()async->Void={guard visit.permits(captured,active:true) else{return};await f.load()};visit.disappear();f.suspend();await queued();XCTAssertTrue(w.requests.isEmpty);XCTAssertFalse(f.isCurrent)}
 func testQueuedRecoveryCannotStartAfterExit()async throws{let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();w.unknown=true;await f.save(latitude:31,longitude:121,radius:80);let id=j.rows[0].requestID;var visit=MerchantAnchorVisitAdmission();visit.appear();let captured=visit.revision;let count=w.requests.count;let queued:()async->Void={guard visit.permits(captured,active:true) else{return};await f.recover(id)};visit.disappear();f.suspend();await queued();XCTAssertEqual(w.requests.count,count);XCTAssertEqual(j.rows.count,1)}
 func testQueuedConfirmationCannotDispatchAfterExit()async throws{let w=Wire(),f=try flow(w);await f.load();var visit=MerchantAnchorVisitAdmission();visit.appear();let captured=visit.revision;var admitted=0;let queued:()async->Void={guard visit.permits(captured,active:true) else{return};admitted+=1;await f.save(latitude:31,longitude:121,radius:80)};visit.disappear();await queued();XCTAssertEqual(admitted,0);XCTAssertFalse(w.requests.contains{$0.url!.path.hasSuffix("/anchor/save")})}
 func testReappearanceDoesNotAdmitOldQueuedVisit() {var visit=MerchantAnchorVisitAdmission();visit.appear();let old=visit.revision;visit.disappear();visit.appear();XCTAssertFalse(visit.permits(old,active:true));XCTAssertTrue(visit.permits(visit.revision,active:true))}
 func testPhaseInvalidationRetiresQueuedResume() {var visit=MerchantAnchorVisitAdmission();visit.appear();let old=visit.revision;visit.invalidate();XCTAssertFalse(visit.permits(old,active:true));XCTAssertFalse(visit.permits(visit.revision,active:false));XCTAssertTrue(visit.permits(visit.revision,active:true))}
 func testCancelledQueuedTaskCannotAdmit() {var visit=MerchantAnchorVisitAdmission();visit.appear();XCTAssertFalse(visit.permits(visit.revision,active:true,cancelled:true))}
 func testExitAfterDispatchPreservesOriginalJournalForRestart()async throws{let w=Wire(),j=Journal(),f=try flow(w,j);await f.load();w.afterSave={f.suspend()};await f.save(latitude:31,longitude:121,radius:80);let id=try XCTUnwrap(j.rows.first?.requestID);w.afterSave=nil;let restored=try flow(w,j);await restored.load();await restored.recover(id);XCTAssertTrue(j.rows.isEmpty);XCTAssertTrue(restored.accepted);XCTAssertEqual(w.requests.filter{$0.url!.path.hasSuffix("/anchor/save")}.count,1)}
}
