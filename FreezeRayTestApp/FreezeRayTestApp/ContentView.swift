//
//  ContentView.swift
//  FreezeRayTestApp
//
//  Created by Geordie Kaytes on 10/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var users: [DataV3.User]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(users) { user in
                    NavigationLink {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(user.name ?? "Unknown")
                                .font(.title)

                            if let email = user.email {
                                Label(email, systemImage: "envelope")
                            }

                            if let createdAt = user.createdAt {
                                Label(
                                    createdAt.formatted(date: .abbreviated, time: .shortened),
                                    systemImage: "calendar"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            if let posts = user.posts, !posts.isEmpty {
                                Divider()
                                Text("Posts: \(posts.count)")
                                    .font(.headline)
                            }
                        }
                        .padding()
                    } label: {
                        VStack(alignment: .leading) {
                            Text(user.name ?? "Unknown")
                                .font(.headline)
                            if let email = user.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteUsers)
            }
            .navigationTitle("Users")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addUser) {
                        Label("Add User", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select a user")
        }
    }

    private func addUser() {
        withAnimation {
            let newUser = DataV3.User(
                name: "User \(users.count + 1)",
                email: "user\(users.count + 1)@example.com",
                createdAt: Date()
            )
            modelContext.insert(newUser)
        }
    }

    private func deleteUsers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(users[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: DataV3.User.self, inMemory: true)
}
