import SwiftData
import Foundation

// MARK: - Schema V1 Models

extension DataV1 {
    @Model
    final class User {
        var name: String?
        var createdAt: Date?

        init(name: String? = nil, createdAt: Date? = nil) {
            self.name = name
            self.createdAt = createdAt
        }
    }
}

// MARK: - Schema V2 Models

extension DataV2 {
    @Model
    final class User {
        var name: String?
        var email: String?  // Added in V2
        var createdAt: Date?

        init(name: String? = nil, email: String? = nil, createdAt: Date? = nil) {
            self.name = name
            self.email = email
            self.createdAt = createdAt
        }
    }
}

// MARK: - Schema V3 Models

extension DataV3 {
    @Model
    final class User {
        var name: String?
        var email: String?
        var createdAt: Date?

        var posts: [Post]?  // Relationship added in V3

        init(name: String? = nil, email: String? = nil, createdAt: Date? = nil) {
            self.name = name
            self.email = email
            self.createdAt = createdAt
        }
    }

    @Model
    final class Post {
        var title: String?
        var content: String?
        var createdAt: Date?

        var author: User?  // Relationship

        init(title: String? = nil, content: String? = nil, createdAt: Date? = nil) {
            self.title = title
            self.content = content
            self.createdAt = createdAt
        }
    }
}

// MARK: - Namespaces

enum DataV1 {}
enum DataV2 {}
enum DataV3 {}
