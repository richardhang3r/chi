//
//  SelectGoalValue.swift
//  chi
//
//  Created by Richard Hanger on 6/3/24.
//

//
//  BlockedAppsView.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//

import SwiftUI
import FamilyControls
import DeviceActivity
import ManagedSettings

struct ScreentimeAppView: View {
    @State var disabled : Bool = false
    @State private var selection : FamilyActivitySelection
    @State private var apps_selected : Int
    @State private var categories : Int
    @State private var websites : Int
    @State private var somethingSelected : Bool = false
    @State private var is_presented : Bool = false
    @State private var app_token_array : [ApplicationToken] = []
    @State private var category_array : [ActivityCategoryToken] = []
    @State private var web_array : [WebDomainToken] = []
    private let filter: DeviceActivityFilter
    
    @State private var member = FamilyControlsMember.individual

    struct category_token : Identifiable {
        var id = UUID()
        var token : ActivityCategoryToken
        var name :  String
        var total_duration : TimeInterval = 0
    }
    struct web_token : Identifiable {
        var id = UUID()
        var token : WebDomainToken
        var name :  String
        var total_duration : TimeInterval = 0
    }
    
    struct app_token : Identifiable {
        var id = UUID()
        var token : ApplicationToken
        var name :  String
        var num_pickups : Int = 0
        var num_notifications : Int = 0
        var total_duration : TimeInterval = 0
    }
    
    struct token_info {
        var categories : [category_token]  = [category_token]()
        var app_tokens : [app_token] = [app_token]()
        var web_tokens : [web_token] = [web_token]()
    }
    
    func saveSelection(selection: FamilyActivitySelection) {
        // Used to encode codable to UserDefaults
        let encoder = PropertyListEncoder()
        if let data : Data = try? encoder.encode(selection) {
            MyUserDefaults.screenTimeSelection = data
        }
    }
    
    /**
     Load tokens into identifiable array.  Todo: explore more efficient ways to do this
     */
    func load_app_tokens(selection : FamilyActivitySelection) -> token_info  {
        var tokens : token_info = token_info()
        for app in selection.applications {
            tokens.app_tokens.append(app_token(token: app.token!, name: app.localizedDisplayName ?? "unknown"))
        }
        for category in selection.categories {
            tokens.categories.append(category_token(token: category.token!, name: category.localizedDisplayName ?? "unknown"))
        }
        for web_domain in selection.webDomains {
            tokens.web_tokens.append(web_token(token: web_domain.token!, name: web_domain.domain ?? "unknown"))
        }
        return tokens
    }
    
    init(disabled: Bool = false) {
        let decoder = PropertyListDecoder()
        let data : Data? = MyUserDefaults.screenTimeSelection
        let sel : FamilyActivitySelection
        if (data != nil) {
            sel = try! decoder.decode(FamilyActivitySelection.self, from: data!)
        } else {
            sel = FamilyActivitySelection()
        }
        _selection = State(initialValue: sel)
        self._apps_selected = State(initialValue: (sel.applicationTokens.count))
        self._websites = State(initialValue: (sel.webDomainTokens.count))
        self._categories = State(initialValue: (sel.categoryTokens.count))

        filter = DeviceActivityFilter(
            segment: .hourly(), users:.all,devices: .init([.iPhone]),
            applications: sel.applicationTokens,
            categories: sel.categoryTokens,
            webDomains: sel.webDomainTokens)
    }
    
    let columns = [GridItem(.adaptive(minimum: 75), spacing: 50)]
    var body: some View {
        VStack {
            Text("apps to block")
                .font(.title)
                .padding()
            Spacer()
            VStack(alignment: .leading) {
                HStack {
                    Text("blocked: ")
                    if (apps_selected > 0
                        || categories > 0
                        || websites > 0) {
                        if (apps_selected > 0) {
                            Text("\(apps_selected) apps")
                        }
                        if categories > 0 {
                            Text("\(categories) categories")
                        }
                        if websites > 0 {
                            Text("\(websites) websites")
                        }
                    } else {
                        Text("none")
                    }
                    Spacer()
                    Button(action: {
                        is_presented = true
                    }, label: {
                        Image(systemName: "plusminus")
                    })
                    .disabled(disabled)
                    .familyActivityPicker(isPresented: $is_presented,
                                          selection: $selection)
                    .onChange(of: selection) { oldValue, newValue in
                        saveSelection(selection: selection)
                        apps_selected = selection.applicationTokens.count
                        categories = selection.categoryTokens.count
                        websites = selection.webDomainTokens.count
                        app_token_array = Array(selection.applicationTokens)
                        web_array = Array(selection.webDomainTokens)
                        category_array = Array(selection.categoryTokens)
                        somethingSelected = (apps_selected > 0
                                             || categories > 0
                                             || websites > 0)

                    }
                }
                .padding(.horizontal,50)
                HStack {
                    Spacer()
                    let tokens = load_app_tokens(selection: selection)
                    ForEach(tokens.categories) { category in
                        Label(category.token)
                            .alignmentGuide(.leading, computeValue: { dimension in
                                0
                            })
                    }
                    ForEach(tokens.app_tokens) { app in
                        Label(app.token).alignmentGuide(.leading, computeValue: { dimension in
                            0
                        })
                        .labelStyle(.iconOnly)
                    }
                    ForEach(tokens.web_tokens) { web in
                        Label(web.token)
                            .alignmentGuide(.leading, computeValue: { dimension in
                                0
                            })
                    }
                    Spacer()
                }
            }
            Spacer()
            if somethingSelected == false {
                Text("nothing selected")
                    .font(.callout)
                    .foregroundStyle(Color.red)
            }
            NavigationLink(value: 3) {
                Text("next")
                    .padding()
            }
            .buttonStyle(.bordered)
            //.disabled(somethingSelected == false)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
        .background(Color.beige)
        .onAppear(perform: {
            Task {
                await requestAuthorization()
            }
            app_token_array = Array(selection.applicationTokens)
            somethingSelected = (apps_selected > 0
                                 || categories > 0
                                 || websites > 0)

        })
    }
    
    
    
}

func requestAuthorization() async {
    do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    } catch {
        print("Failed to enroll Aniyah with error: \(error)")
    }
}

#Preview {
    ScreentimeAppView(disabled: false)
}

struct BlockedAppsView: View {
    @State var disabled : Bool
    @State private var showLocked : Bool = false
    @State private var isPickerPresented : Bool = false
    @State private var selection : FamilyActivitySelection
    @State private var app_token_array : [ApplicationToken] = []

    struct category_token : Identifiable {
        var id = UUID()
        var token : ActivityCategoryToken
        var name :  String
        var total_duration : TimeInterval = 0
    }
    struct web_token : Identifiable {
        var id = UUID()
        var token : WebDomainToken
        var name :  String
        var total_duration : TimeInterval = 0
    }
    
    struct app_token : Identifiable {
        var id = UUID()
        var token : ApplicationToken
        var name :  String
        var num_pickups : Int = 0
        var num_notifications : Int = 0
        var total_duration : TimeInterval = 0
    }
    
    struct token_info {
        var categories : [category_token]  = [category_token]()
        var app_tokens : [app_token] = [app_token]()
        var web_tokens : [web_token] = [web_token]()
    }
    
    func saveSelection(selection: FamilyActivitySelection) {
        // Used to encode codable to UserDefaults
        let encoder = PropertyListEncoder()
        if let data : Data = try? encoder.encode(selection) {
            MyUserDefaults.screenTimeSelection = data
        }
    }
    
    /**
     Load tokens into identifiable array.  Todo: explore more efficient ways to do this
     */
    func load_app_tokens(selection : FamilyActivitySelection) -> token_info  {
        var tokens : token_info = token_info()
        for app in selection.applications {
            tokens.app_tokens.append(app_token(token: app.token!, name: app.localizedDisplayName ?? "unknown"))
        }
        for category in selection.categories {
            tokens.categories.append(category_token(token: category.token!, name: category.localizedDisplayName ?? "unknown"))
        }
        for web_domain in selection.webDomains {
            tokens.web_tokens.append(web_token(token: web_domain.token!, name: web_domain.domain ?? "unknown"))
        }
        return tokens
    }
    
    init(disabled: Bool = false) {
        let decoder = PropertyListDecoder()
        let data : Data? = MyUserDefaults.screenTimeSelection
        let sel : FamilyActivitySelection
        if (data != nil) {
            sel = try! decoder.decode(FamilyActivitySelection.self, from: data!)
        } else {
            sel = FamilyActivitySelection()
        }
        _selection = State(initialValue: sel)
        self.disabled = disabled
        print("disabeld: \(disabled) self:\(self.disabled)")
    }
    
    var body: some View {
        Button {
            if disabled {
                showLocked = true
            } else {
                isPickerPresented = true
            }
            print("clicked! \(disabled)")
        } label: {
            if (app_token_array.isEmpty) {
                Text("configure blocked apps")
            } else {
                VStack {
                    HStack {
                        let tokens = load_app_tokens(selection: selection)
                        ForEach(tokens.categories) { category in
                            Label(category.token)
                                .labelStyle(.iconOnly)
                        }
                        ForEach(tokens.app_tokens) { app in
                            Label(app.token)
                                .labelStyle(.iconOnly)
                        }
                        ForEach(tokens.web_tokens) { web in
                            Label(web.token)
                                .labelStyle(.iconOnly)
                        }
                    }
                    .shadow(radius: 10)
                    if showLocked {
                        Text("locked")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
        }
        .padding()
        .familyActivityPicker(isPresented: $isPickerPresented,
                              selection: $selection)
        .onChange(of: selection) { oldValue, newValue in
            saveSelection(selection: selection)
            app_token_array = Array(selection.applicationTokens)
        }
        .onAppear(perform: {
            app_token_array = Array(selection.applicationTokens)
        })
    }
}
