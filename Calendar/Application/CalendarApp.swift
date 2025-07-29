//
//  CalendarApp.swift
//  Calendar
//
//  Created by Jessica Estes on 7/4/25.
//

import SwiftUI

@main
struct CalendarApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.font, .custom("Mulish-Regular", size: 17, relativeTo: .body))
        }
    }
}



#Preview {
    ContentView()
}
