import SwiftUI

struct MerchantAnchorReadRecoveryPresentation:View {
    let state:String
    let busy:Bool
    var body:some View {
        if busy {
            ProgressView{
                if state=="loading"{Text("loading",tableName:"MerchantAnchorReadRecovery")}
                else{Text("working",tableName:"MerchantAnchorReadRecovery")}
            }
        } else {
            switch state {
            case "failed":MerchantOperationsReadNotice(text: Text("failed",tableName:"MerchantAnchorReadRecovery"), symbol: "exclamationmark.circle")
            case "notConfigured":MerchantOperationsReadNotice(text: Text("notConfigured",tableName:"MerchantAnchorReadRecovery"), symbol: "network.slash")
            case "denied":MerchantOperationsReadNotice(text: Text("denied",tableName:"MerchantAnchorReadRecovery"), symbol: "lock")
            default:EmptyView()
            }
        }
    }
}

struct MerchantOperationsReadNotice: View {
    let text: Text
    let symbol: String
    var body: some View {
        MerchantM02Notice(message: text, symbol: symbol)
    }
}
