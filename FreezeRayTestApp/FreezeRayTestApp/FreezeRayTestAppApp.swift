//
//  FreezeRayTestAppApp.swift
//  FreezeRayTestApp
//
//  Created by Geordie Kaytes on 10/10/25.
//

import SwiftUI
import SwiftData

@main
struct FreezeRayTestAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: AppSchemaV3.self)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrations.self,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
