//
//  SlowMigrationView.swift
//  WWDC
//
//  Created by Guilherme Rambo on 18/07/20.
//  Copyright © 2020 Guilherme Rambo. All rights reserved.
//

import SwiftUI

struct SlowMigrationView: View {
    var body: some View {
        VStack {
            Text("Migration in progress")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .padding(.bottom)
            Text("WWDC is running a one-time update of your local database. This may take several seconds.")
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .frame(width: 300, height: 100)
        .padding([.leading, .trailing, .bottom])
        .offset(x: 0, y: -8)
    }
}

// swiftlint:disable:next type_name
struct SlowMigrationView_Previews: PreviewProvider {
    static var previews: some View {
        SlowMigrationView()
    }
}
