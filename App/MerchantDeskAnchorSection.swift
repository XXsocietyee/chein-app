import SwiftUI
import MapKit

struct MerchantDeskAnchorAcceptance:Equatable {
    let context:RuntimeDependencyContext
    let revision:UUID
    let configureExistingStore:Bool
    @MainActor func permits(_ request:URLRequest,transport:any HTTPTransport)->Bool {
        guard configureExistingStore,context.market == .china,let data=request.httpBody,data.count<=2048,
              let fields=try? JSONDecoder().decode(MerchantBusinessValue.self,from:data).object,
              let latText=fields["anchorLat"]?.numberText,let lat=Double(latText),lat.isFinite,(-90...90).contains(lat),
              let lngText=fields["anchorLng"]?.numberText,let lng=Double(lngText),lng.isFinite,(-180...180).contains(lng),lat != 0 || lng != 0,
              let radius=fields["radiusM"]?.integer,(30...500).contains(radius),
              let id=fields["requestId"]?.string,id.hasPrefix("anchor-"),UUID(uuidString:String(id.dropFirst(7))) != nil else{return false}
        let common:Set<String>=["anchorLat","anchorLng","radiusM","requestId"]
        if fields["preserveWifi"]?.bool == true {
            guard Set(fields.keys)==common.union(["preserveWifi","expectedVersion"]),let v=fields["expectedVersion"]?.integer,v>0 else{return false}
        } else {
            guard Set(fields.keys)==common.union(["wifiBssids"]),fields["wifiBssids"] == .array([]) else{return false}
        }
        guard let api=try? APIConfiguration(baseURL:context.baseURL),let expected=try? MerchantBusinessService(configuration:api,readTransport:transport).makeRequest(.json(MerchantDeskAnchorFlow.savePath,fields),token:context.session.token) else{return false}
        return request.httpMethod==expected.httpMethod && request.url==expected.url && request.httpBody==expected.httpBody
            && request.allHTTPHeaderFields==expected.allHTTPHeaderFields && request.httpBodyStream==nil && !request.httpShouldHandleCookies
    }
}
@MainActor struct MerchantDeskAnchorSection:View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    @ObservedObject var flow:MerchantDeskAnchorFlow
    @State private var position:MapCameraPosition = CYMapRegion.defaultPosition
    @State private var picked:CLLocationCoordinate2D?
    @State private var renderedCenter:CLLocationCoordinate2D?
    @State private var radius=30
    @State private var acknowledged=false
    @State private var confirm=false
    private struct Frozen {let latitude:Double,longitude:Double,radius:Int,version:Int?,configured:Bool}
    @State private var frozen:Frozen?
    @State private var editorGeneration=UUID()
    @State private var visit=MerchantAnchorVisitAdmission()
    private var store:CLLocationCoordinate2D? {
        guard let lat=flow.storeLatitude,let lng=flow.storeLongitude,CLLocationCoordinate2DIsValid(.init(latitude:lat,longitude:lng)),lat != 0 || lng != 0 else{return nil}
        return .init(latitude:lat,longitude:lng)
    }
    var body:some View {
        Section {
            Text("merchant.desk.anchor.boundary",tableName:"MerchantDeskSkuSupply").cyText(.bodyCompact)
            ForEach(flow.isCurrent ? flow.pending:[],id:\.requestID){record in Button{let captured=visit.revision;Task{await recover(record.requestID,visit:captured)}}label:{Text("merchant.desk.anchor.recover",tableName:"MerchantDeskSkuSupply")}.disabled(flow.busy)}
            MerchantAnchorReadRecoveryPresentation(state:flow.readState.rawValue,busy:flow.busy)
            if flow.hasKnownResult,let request=flow.knownRequestID {
                VStack(alignment:.leading){
                    Text("known",tableName:"MerchantAnchorReadRecovery").cyText(.cardTitle)
                    Text("original.anchor",tableName:"MerchantAnchorReadRecovery").cyText(.meta)
                    Text(verbatim:"\(flow.knownTargetID.map { "#\($0)" } ?? "—") · \(request)").cyText(.meta).textSelection(.enabled)
                }.accessibilityElement(children:.combine)
            } else if !flow.pending.isEmpty,flow.issue,flow.readState != .denied {
                Text("unknown",tableName:"MerchantAnchorReadRecovery")
            }
            if flow.isCurrent,flow.accepted{Text("merchant.desk.anchor.accepted",tableName:"MerchantDeskSkuSupply")}
            if flow.isCurrent,flow.loaded {
                if !flow.configured{Text("unconfigured",tableName:"MerchantAnchorReadRecovery")}
                if !flow.canSave,!flow.busy{Text("readonly",tableName:"MerchantAnchorReadRecovery").cyText(.bodyCompact)}
                if let version=flow.version{Text("merchant.desk.anchor.version \(version)",tableName:"MerchantDeskSkuSupply")}
                Text("merchant.desk.anchor.wifi \(flow.wifiCount)",tableName:"MerchantDeskSkuSupply")
                if let store {
                    MapReader { proxy in
                        Map(position:$position) {
                            Marker(coordinate:store){Text("merchant.desk.anchor.store",tableName:"MerchantDeskSkuSupply")}
                            if let lat=flow.latitude,let lng=flow.longitude{Marker(coordinate:.init(latitude:lat,longitude:lng)){Text("merchant.desk.anchor.saved",tableName:"MerchantDeskSkuSupply")}}
                            if let picked{Marker(coordinate:picked){Text("merchant.desk.anchor.selected",tableName:"MerchantDeskSkuSupply")}}
                        }.frame(height:240)
                        .mapStyle(.standard(elevation:.flat,emphasis:.muted))
                        .environment(\.colorScheme,.light)
                        .background { CYMapPlaceholder(fog:false) }
                        .onAppear { position = .region(CYMapRegion.region(center:store,span:0.01)) }
                        .onMapCameraChange(frequency:.onEnd){context in renderedCenter=context.region.center}
                        .accessibilityAddTraits(.allowsDirectInteraction)
                        .onTapGesture { point in
                            guard !flow.busy,let coordinate=proxy.convert(point,from:.local),CLLocationCoordinate2DIsValid(coordinate) else{return}
                            picked=coordinate;acknowledged=false;frozen=nil;confirm=false
                        }
                    }
                    if let renderedCenter,CLLocationCoordinate2DIsValid(renderedCenter){
                        Button{guard !flow.busy else{return};picked=renderedCenter;acknowledged=false;frozen=nil;confirm=false}label:{Label("d7.imMap.useCenter",systemImage:"scope")}
                            .disabled(flow.busy).frame(minHeight:CYSpacing.minTouchTarget).accessibilityIdentifier("merchant.desk.anchor.useCenter")
                    }
                    Stepper(value:$radius,in:30...500,step:10){Text("merchant.desk.anchor.radius \(radius)",tableName:"MerchantDeskSkuSupply")}.disabled(flow.busy)
                    Toggle(isOn:$acknowledged){Text("merchant.desk.anchor.attest",tableName:"MerchantDeskSkuSupply")}.disabled(flow.busy)
                    Button{guard let picked else{return};frozen=Frozen(latitude:picked.latitude,longitude:picked.longitude,radius:radius,version:flow.version,configured:flow.configured);confirm=true}label:{Text("merchant.desk.anchor.save",tableName:"MerchantDeskSkuSupply")}.disabled(!flow.canSave || picked==nil || !acknowledged)
                } else {Text("merchant.desk.anchor.missingStore",tableName:"MerchantDeskSkuSupply")}
            }
            Button{let captured=visit.revision;Task{await reload(captured)}}label:{Text("merchant.desk.anchor.refresh",tableName:"MerchantDeskSkuSupply")}.disabled(flow.busy)
        } header: {Text("merchant.desk.anchor.title",tableName:"MerchantDeskSkuSupply")}
        .onAppear{visit.appear();let captured=visit.revision;Task{await reload(captured)}}
        .onDisappear{visit.disappear();clear();flow.suspend()}
        .onChange(of:scenePhase){_,phase in
            visit.invalidate();clear();flow.suspend()
            if visit.visible,phase == .active{let captured=visit.revision;Task{await reload(captured)}}
        }
        .cySheet(isPresented:$confirm,onDismiss:{frozen=nil}){
            CYConfirmSheet(
                title:String(localized:LocalizedStringResource("merchant.desk.anchor.confirm",table:"MerchantDeskSkuSupply",locale:locale)),
                message:{
                    let base=String(localized:LocalizedStringResource("confirmation.anchor",table:"MerchantAnchorReadRecovery",locale:locale))
                    if let draft=frozen{return "\(base)\n\(draft.latitude), \(draft.longitude) · \(draft.radius) m"}
                    return base
                }(),
                confirmTitle:String(localized:LocalizedStringResource("merchant.desk.anchor.save",table:"MerchantDeskSkuSupply",locale:locale)),
                onConfirm:{
                    let captured=visit.revision
                    guard admitted(captured),let draft=frozen,acknowledged,flow.canSave,flow.version==draft.version,flow.configured==draft.configured else{clear();return}
                    clear();let g=editorGeneration
                    Task{
                        guard admitted(captured),g==editorGeneration,flow.canSave,flow.version==draft.version,flow.configured==draft.configured else{return}
                        await flow.save(latitude:draft.latitude,longitude:draft.longitude,radius:draft.radius)
                        populate(g,visit:captured)
                    }
                }
            )
            .cyDomainSheet(detents:[.half])
            .themeDomain(.merchant)
        }
        .onChange(of:confirm){_,shown in if !shown{frozen=nil}}
        .onChange(of:radius){_,_ in frozen=nil;confirm=false}
    }
    private func clear(){editorGeneration=UUID();picked=nil;acknowledged=false;frozen=nil;confirm=false;radius=30}
    private func admitted(_ captured:UUID)->Bool{visit.permits(captured,active:scenePhase == .active,cancelled:Task.isCancelled)}
    private func populate(_ g:UUID,visit captured:UUID){guard admitted(captured),g==editorGeneration,scenePhase == .active,flow.isCurrent,flow.loaded else{return};radius=flow.radius ?? 30;frozen=nil;confirm=false;picked=nil;acknowledged=false}
    private func reload(_ captured:UUID)async{
        guard admitted(captured) else{return}
        clear();let g=editorGeneration
        await flow.load()
        populate(g,visit:captured)
    }
    private func recover(_ requestID:String,visit captured:UUID)async{
        guard admitted(captured),flow.isCurrent else{return}
        clear();let g=editorGeneration
        await flow.recover(requestID)
        populate(g,visit:captured)
    }
}

private struct MerchantAnchorDestinationKey: EnvironmentKey {
    static let defaultValue: ((MerchantBusinessAccess) -> AnyView?) = { _ in nil }
}
extension EnvironmentValues {
    var merchantAnchorDestination: (MerchantBusinessAccess) -> AnyView? {
        get { self[MerchantAnchorDestinationKey.self] }
        set { self[MerchantAnchorDestinationKey.self] = newValue }
    }
}
@MainActor struct SessionMerchantAnchorView: View {
    let access: MerchantBusinessAccess
    @EnvironmentObject private var session: AppSession
    @State private var flow: MerchantDeskAnchorFlow?
    var body: some View {
        List {
            if let flow { MerchantDeskAnchorSection(flow: flow) }
            else { MerchantAnchorReadRecoveryPresentation(state: "notConfigured", busy: false) }
        }
        .navigationTitle(Text("merchant.desk.anchor.title", tableName: "MerchantDeskSkuSupply")).navigationBarTitleDisplayMode(.inline)
        .task(id: session.currentRuntimeDependencyContext) {
            flow?.suspend()
            flow = session.makeMerchantDeskAnchorFlow(access: access)
        }
        .onDisappear { flow?.suspend() }
        .cyDomainScreen(.merchant)
    }
}
