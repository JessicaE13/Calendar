//
//  BackgroundView.swift
//  Calendar
//
//  Created by Jessica Estes on 7/29/25.
//

import SwiftUI

struct BackgroundView: View {
    var body: some View {
        Color("Background")
            .ignoresSafeArea(edges: .all)
    }
}

#Preview {
    BackgroundView()
}
