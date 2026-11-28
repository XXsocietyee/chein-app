import XCTest
@testable import QuestifyCore

/// MP `publishkit/components/reward-selector`: decode `api/coupon/mypublishlist` and split 优惠券 / 体验卡.
final class RewardCouponSelectionTests: XCTestCase {
    func testDecodesArrayAndRowsAndSplitsPasses() throws {
        let array = Data(#"{"code":200,"data":[{"id":5,"name":"满50减10","couponType":1},{"id":"9","name":"到店体验","couponType":3,"description":"一次"}]}"#.utf8)
        let options = try RewardCouponSelectionContract.decode(array, status: 200)
        XCTAssertEqual(options.map(\.id), [5, 9])
        XCTAssertEqual(RewardCouponSelectionContract.visible(options, kind: .pass).map(\.id), [9])
        XCTAssertEqual(RewardCouponSelectionContract.visible(options, kind: .coupon).map(\.id), [5])
        XCTAssertEqual(options[1].detail, "一次")
        let page = Data(#"{"code":"200","data":{"rows":[{"id":7,"name":"A","couponType":0}]}}"#.utf8)
        XCTAssertEqual(try RewardCouponSelectionContract.decode(page, status: 200).map(\.id), [7])
    }

    func testFailureIsNotAnEmptyList() {
        let failed = Data(#"{"code":500,"msg":"x"}"#.utf8)
        XCTAssertThrowsError(try RewardCouponSelectionContract.decode(failed, status: 200)) {
            XCTAssertEqual($0 as? RewardCouponSelectionError, .failed)
        }
        XCTAssertThrowsError(try RewardCouponSelectionContract.decode(Data("{}".utf8), status: 401)) {
            XCTAssertEqual($0 as? RewardCouponSelectionError, .signedOut)
        }
    }

    func testOpensOnTheTabOfTheSelectedCoupon() {
        let options = [RewardCouponOption(id: 1, name: "A", detail: nil, couponType: 1),
                       RewardCouponOption(id: 2, name: "B", detail: nil, couponType: 3)]
        XCTAssertEqual(RewardCouponSelectionContract.initialKind(options, selected: 2, current: .coupon), .pass)
        XCTAssertEqual(RewardCouponSelectionContract.initialKind(options, selected: nil, current: .coupon), .coupon)
        XCTAssertEqual(RewardCouponSelectionContract.fields, ["is_select": "1"])
    }
}
