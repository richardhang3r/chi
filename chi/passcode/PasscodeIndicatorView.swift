//
//  PasscodeIndicatorView.swift
//  PasscodeLockScreen
//
//  Created by Dhruv Sharma on 05/02/24.
//

import SwiftUI

struct PasscodeIndicatorView: View {
    @Binding var passcode: String
    var color: Color = Color.primary
    var body: some View {
        HStack(spacing: 32){
            ForEach(0 ..< 4){ index in
                Circle()
                    .fill(passcode.count > index ? color : Color(UIColor.systemBackground))
                    .frame(width:20,height: 20)
                    .overlay{
                        Circle()
                            .stroke(Color(UIColor.label),lineWidth: 0.0)
                    }
            }
        }
    }
}

#Preview {
    PasscodeIndicatorView(passcode: .constant(""))
}
