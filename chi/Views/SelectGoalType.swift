//
//  SelectGoalType.swift
//  chi
//
//  Created by Richard Hanger on 6/3/24.
//

import SwiftUI

struct SelectGoalType: View {
    @Binding var goal : Goal
    @State var selectedType: GoalType? = nil
    @State var target: Int = 0
    @State var permissionGranted: Bool = false
    @State var requetingPermission: Bool = false
    @State var targetDouble: Double = 0
    var body: some View {
        VStack {
            ZStack {
                if requetingPermission {
                    ProgressView("Requesting Permission...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
                List {
                    ForEach(GoalType.allCases, id: \.self) { type in
                        if selectedType == nil || selectedType == type {
                            if (type.isSupported) {
                                Button {
                                    if selectedType == type {
                                        selectedType = nil
                                    } else {
                                        selectedType = type
                                        target = Int(type.defaultValue)
                                        goal.type = type
                                        goal.target = type.defaultValue
                                        if goal.type.supportHealthKit {
                                            requetingPermission = true
                                            HealthData.requestHealthDataAccessIfNeeded(dataTypes: [goal.type.healthIdentifier.rawValue]) {success in
                                                DispatchQueue.main.async {
                                                    requetingPermission = false
                                                    permissionGranted = success
                                                    print("permission granted to \(success) \(permissionGranted)")
                                                }
                                            }
                                        } else {
                                            permissionGranted = true
                                        }
                                    }
                                } label: {
                                    HStack
                                    {
                                        Spacer()
                                        Image(systemName: type.iconName)
                                        Text("\(type.title)")
                                        Spacer()
                                    }
                                    .padding()
                                }
                            }
                        }
                    }
                    //.background(Color(uiColor: UIColor.darkGray))
                    .listRowBackground(Color(uiColor: UIColor.clear))
                    .clipShape(.capsule)
                    if let type = selectedType {
                        VStack {
                            Text("\(type.description) target")
                                .font(.headline)
                            Picker("Select a target value", selection: $target) {
                                ForEach(Array(stride(from: type.minValue, through: type.maxValue, by:  type.increment)), id: \.self) { number in
                                    Text("\(number)")
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .onChange(of: target) {
                                goal.target = Double(target)
                            }
                        }
                        .listRowBackground(Color(uiColor: UIColor.clear))
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .listStyle(.insetGrouped)
                .listRowSpacing(15)
            }
            NavigationLink(value: 2) {
                Text("next")
                    .padding()
            }
            .disabled(selectedType == nil || permissionGranted == false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
        .background(Color.beige)
        .navigationTitle("goal type")
        .buttonStyle(.bordered)
    }
}
/*
 permissionGranted = false
 HealthData.requestHealthDataAccessIfNeeded(dataTypes: [goal.type.healthIdentifier.rawValue]) {success in
     DispatchQueue.main.async {
         permissionGranted = success
         print("permission granted to \(success) \(permissionGranted)")
     }
 }
 */

#Preview {
    @State var goal = Goal()
    return SelectGoalType(goal: $goal)
}
