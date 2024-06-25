//
//  GoalPasscodeView.swift
//  track
//
//  Created by Richard Hanger on 5/24/24.
//

import SwiftUI

struct GoalPasscodeView: View {
    
    @Binding var goal: Goal
    @State private var isAuthenticated = false
    
    @State var enteredPasscode : String? = nil
    @State var choosePasscode : Bool = false
    @State var confirmPasscode : Bool = false

    @Environment(\.dismiss) private var dismiss

    private func passCodeCallback(password: String) {
        enteredPasscode = password
        //confirmPasscode = true
        print("entered passcode \(String(describing: enteredPasscode))!!")
    }
    
    var body: some View {
        VStack {
            Text("goal pin")
                .font(.title)
                .bold()
                .padding()
            Text("create a pin that is required to change or edit goal")
                .font(.caption)
            Spacer()
            Button {
                goal.goalPasscode = ""
                choosePasscode = true
            } label: {
                if !isAuthenticated {
                    Text("create goal pin")
                        .bold()
                        .padding()
                } else {
                    Text("clear goal pin")
                        .bold()
                        .padding()
                }
            }
            .buttonStyle(.bordered)
            .clipShape(.ellipse)
            Spacer()
            
            if isAuthenticated || !choosePasscode {
                NavigationLink(value: 4) {
                    if goal.goalPasscode.isEmpty {
                        Text("skip")
                            .bold()
                            .padding()
                    } else {
                        Text("continue")
                            .bold()
                            .padding()
                    }
                }
                .buttonStyle(.bordered)
                .clipShape(.ellipse)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
        .background(Color.beige)
        .onChange(of: isAuthenticated) {
            print(" aa passcode to \(String(describing: enteredPasscode?.debugDescription))")
            goal.goalPasscode = enteredPasscode ?? ""
            choosePasscode = false
        }
        .sheet(isPresented: $choosePasscode) {
            let instructions = enteredPasscode == nil ? "enter goal pin" : "confirm goal pin"
            PasscodeView(correctCode: enteredPasscode, isAuthenticated: $isAuthenticated, instructions: instructions, passwordComplete: passCodeCallback(password:))
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 1
                .background(Color.beige)
        }
    }
}

#Preview {
    @State var goal = Goal()
    return GoalPasscodeView(goal: $goal)
}
