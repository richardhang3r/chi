//
//  PasscodeView.swift
//  PasscodeLockScreen
//
//  Created by Dhruv Sharma on 05/02/24.
//

import SwiftUI

struct PasscodeView: View {
    
    let correctCode : String?
    @Binding var isAuthenticated: Bool
    var instructions : String = "enter pin"
    var passwordComplete: ((_ enteredPass: String) -> Void)? = nil
    
    
    @State var color = Color.primary
    @Environment(\.dismiss) private var dismiss
    @State private var passcode = ""

    
    var body: some View {
        VStack(spacing: 48){
            VStack(spacing: 24){
                Text(instructions)
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                
                Text("pin needed to change or edit goal")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            } .padding(.top)
            
            // indicator view
            PasscodeIndicatorView(passcode: $passcode, color: color)
            Spacer()
            //numberpad view
            NumberPadView(passcode: $passcode)
        }.onChange(of: passcode){
            verifyPasscode()
        }
    }
    private func verifyPasscode(){
        guard passcode.count == 4 else{ return }
        Task{
            if let correctPin = correctCode {
                color = passcode == correctPin ? Color.green : Color.red
            }

            try? await Task.sleep(nanoseconds: 150_000_000)
            if let correctPin = correctCode {
                //try? await Task.sleep(nanoseconds: 125_000_000)
                isAuthenticated = passcode == correctPin
                passcode = ""
                color = Color.primary
            } else if let passwordCallback = passwordComplete {
                passwordCallback(passcode)
                passcode = ""
            }
        }
    }
}

#Preview {
    PasscodeView(correctCode: "1111" , isAuthenticated: .constant(false), instructions: "enter pin")
}

struct PasscodeCopyView: View {
    
    
    let correctCode : String
    @Binding var isAuthenticated: Bool
    
    var passwordComplete: ((_ enteredPass: String) -> Void)? = nil
    
    var instructions : String = "Enter Passcode"
    @State private var passcode = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 48){
            VStack(spacing: 24){
                Text(instructions)
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                
                Text("enter your 4-digit pin to protect goal editing")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            } .padding(.top)
            
            // indicator view
            PasscodeIndicatorView(passcode: $passcode)
            Spacer()
            //numberpad view
            NumberPadView(passcode: $passcode)
        }.onChange(of: passcode){
            verifyPasscode()
        }
    }
    private func verifyPasscode(){
        guard passcode.count == 4 else{ return }
        if let passwordCallback = passwordComplete {
            passwordCallback(passcode)
        } else {
            Task{
                try? await Task.sleep(nanoseconds: 125_000_000)
                isAuthenticated = passcode == correctCode
                passcode = ""
                dismiss()
            }
        }
    }
}
