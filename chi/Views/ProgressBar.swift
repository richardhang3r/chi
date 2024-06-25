//
//  ProgressBar.swift
//  track
//
//  Created by Richard Hanger on 5/23/24.
//
//
//  ProgressBar.swift
//  bet
//
//  Created by Richard Hanger on 11/17/23.
//

import SwiftUI

struct ProgressBar: View {
    var progress: Double
    var include_text: Bool
    var color: Color
    
    var divisor: Double = 0
    var total: Double = 0
    
    init(value: Double, total: Double,include_text: Bool, color: Color = Color.green) {
        
        self.divisor = value
        self.total = total
        
        if (total == 0) {
            self.progress = 0
        } else {
            self.progress = min(value/total,1.0)
        }
        
        self.include_text = include_text
        self.color = color
    }
    
    init(progress: Double, include_text: Bool, color: Color = Color.green) {
        self.progress = min(progress,1.0)
        self.include_text = include_text
        self.color = color
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(0.3)
                        .foregroundColor(Color.gray)
                    
                    Rectangle()
                        .frame(width: min(CGFloat(self.progress) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                        .foregroundColor(color)
                }
                .cornerRadius(10.0)
                
                if (include_text) {
                    //Text(String(format: "%.0f/%.0f",divisor,total))
                    Text(String(format: "%.0f%%", progress*100))
                }
            }
            
        }
    }
}


struct ProgressView_Previews: PreviewProvider {
    
    
    static var previews: some View {
        Group {
            ProgressBar(progress: 0.6, include_text: false)
            ProgressBar(progress: 0.3, include_text: true)
        }
    }
}
