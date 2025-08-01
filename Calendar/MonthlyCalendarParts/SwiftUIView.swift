//
//  SwiftUIView.swift
//  Calendar
//
//  Created by Jessica Estes on 8/1/25.
//

import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        Rectangle()
            .frame(width: 300, height: 300)
        
        Rectangle()
            .frame(width: 300, height: 50)
        Rectangle()
            .frame(width: 300, height: 50)
        Rectangle()
            .frame(width: 300, height: 50)
        Rectangle()
            .frame(width: 300, height: 50)
        Rectangle()
            .frame(width: 300, height: 50)
    }
}

#Preview {
    SwiftUIView()
}
