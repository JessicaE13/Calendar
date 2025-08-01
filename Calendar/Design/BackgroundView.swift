//
//  BackgroundView.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
//

import SwiftUI

struct BackgroundView: View {
    var body: some View {
        Color("Background").opacity(0.7)
            .ignoresSafeArea(edges: .all)
    }
}

#Preview {
    BackgroundView()
}
