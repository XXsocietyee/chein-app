import XCTest
@testable import QuestifyCore

@MainActor enum WorkshopPurchasedTestData {
    static let item: [String: Any] = ["licenseId":"WKO_0000000000000000000000000000000b","moduleId":11,"purchasedVersionId":"synthetic-version","contentHash":String(repeating:"a",count:64),"status":"ACTIVE","acquiredAt":"2026-10-05T00:00:00Z","termsVersion":"terms-1","termsHash":String(repeating:"b",count:64),"commercialUse":"PROHIBITED","adaptation":"LOCAL_ADAPTATION","translation":"PROHIBITED","updates":"EXACT_PURCHASED_VERSION","redistribution":"PROHIBITED","allowedRegions":["110101"],"themeLimit":["unlimited":false,"maximum":1],"merchantLimit":["unlimited":false,"maximum":0],"runLimit":["unlimited":false,"maximum":0],"acquisition":"PAID","buyerKind":"INDIVIDUAL","useDuration":"PERPETUAL_PURCHASED_VERSION","contentUseStatus":"PRIVATE_DRAFT_INSTALL_AVAILABLE","purchaseActionStatus":"EXACT_VERSION_PURCHASED"]
    static let header: [String: Any] = ["schema":"workshop-purchased-v2","scope":"INDIVIDUAL","checkedAt":"2026-10-05T00:00:00Z"]
    static func page(_ rows: [[String:Any]] = [item], next: Int64? = nil) -> [String:Any] { var data=header;data["items"]=rows;data["hasMore"]=next != nil;if let next { data["nextBeforeOrderLineId"]=next };return data }
    static func detail(_ value:[String:Any] = item)->[String:Any]{ value }
    static func envelope(_ object:[String:Any]) throws -> Data {try JSONSerialization.data(withJSONObject:["code":200,"data":object])}
    static func decode<T:Decodable>(_ value:[String:Any]) throws -> T {try JSONDecoder().decode(T.self,from:JSONSerialization.data(withJSONObject:value))}
}
@MainActor final class WorkshopPurchasedContractsTests: XCTestCase {
    func testExplicitPurchasedDurationDoesNotDependOnExpiryFieldOrSubscription() throws {
        let item:WorkshopPurchasedItem=try WorkshopPurchasedTestData.decode(WorkshopPurchasedTestData.item)
        XCTAssertEqual(item.purchasedVersionId,"synthetic-version");XCTAssertEqual(item.status,.active);XCTAssertFalse(item.permitsPurchase);XCTAssertFalse(item.permitsContentUse)
        for key in ["useDuration","acquisition","termsHash"] { var object=WorkshopPurchasedTestData.item;object.removeValue(forKey:key);XCTAssertThrowsError(try WorkshopPurchasedTestData.decode(object) as WorkshopPurchasedItem) }
    }
    func testFreeExpiredUnknownRightsAndExtraProtectedFieldsCannotMasqueradeAsPurchased() throws {
        for pair in [("acquisition","FREE"),("useDuration","SUBSCRIPTION"),("status","EXPIRED"),("status","UNKNOWN"),("redistribution","ALLOWED"),("purchaseActionStatus","ENABLED"),("contentUseStatus","AUTHORIZED"),("sourceJSON","private answer")] {
            var value=WorkshopPurchasedTestData.item;value[pair.0]=pair.1;XCTAssertThrowsError(try WorkshopPurchasedTestData.decode(value) as WorkshopPurchasedItem)
        }
    }
    func testFrozenSuspendedAndRevokedRightsRemainExplicit() throws {
        for status in ["ACTIVE","SUSPENDED","REVOKED"] { var data=WorkshopPurchasedTestData.item;data["status"]=status;let item:WorkshopPurchasedItem=try WorkshopPurchasedTestData.decode(data);XCTAssertEqual(item.status.rawValue,status);XCTAssertEqual(item.merchantLimit.maximum,0) }
    }
    func testExactPageDetailAndPaginationBounds() throws {
        let page:WorkshopPurchasedPage=try WorkshopPurchasedTestData.decode(WorkshopPurchasedTestData.page());XCTAssertEqual(page.items.count,1);XCTAssertNil(page.nextBeforeOrderLineId)
        let detail:WorkshopPurchasedDetail=try WorkshopPurchasedTestData.decode(WorkshopPurchasedTestData.detail());XCTAssertEqual(detail.item.id,"WKO_0000000000000000000000000000000b");XCTAssertEqual(detail.checkedAt,"—")
        XCTAssertThrowsError(try WorkshopPurchasedTestData.decode(WorkshopPurchasedTestData.page([WorkshopPurchasedTestData.item,WorkshopPurchasedTestData.item])) as WorkshopPurchasedPage)
        XCTAssertThrowsError(try WorkshopPurchasedTestData.decode(WorkshopPurchasedTestData.page(next:1)) as WorkshopPurchasedPage)
        var extra=WorkshopPurchasedTestData.detail();extra["owner"]=7;XCTAssertThrowsError(try WorkshopPurchasedTestData.decode(extra) as WorkshopPurchasedDetail)
    }
    func testLimitsIdentifiersRegionAndHashFailures() throws {
        for pair:(String,Any) in [("licenseId","w18-paid-01"),("licenseId","w18-paid-9223372036854775808"),("contentHash",String(repeating:"A",count:64)),("allowedRegions",["r","r"]),("themeLimit",["unlimited":true,"maximum":1]),("themeLimit",["unlimited":false,"maximum":-1])] {
            var value=WorkshopPurchasedTestData.item;value[pair.0]=pair.1;XCTAssertThrowsError(try WorkshopPurchasedTestData.decode(value) as WorkshopPurchasedItem)
        }
    }
    func testPurchasedApprovalBindsFullContextIncludingNestedRole() throws {
        let session=try PlayExperienceSession(accountID:7,epoch:1,namespace:"synthetic",token:"synthetic")
        let context=RuntimeDependencyContext(market:.china,baseURL:URL(string:"https://example.com/native")!,role:"merchant",session:session)
        let approval=try WorkshopPurchasedReadApproval(context:context,expiresAt:.distantFuture);XCTAssertTrue(approval.matches(context))
        let changed=RuntimeDependencyContext(market:.china,baseURL:context.baseURL,role:"merchant",session:try .init(accountID:7,epoch:1,namespace:"synthetic",token:"synthetic",role:"merchant"))
        XCTAssertFalse(approval.matches(changed))
    }
}
