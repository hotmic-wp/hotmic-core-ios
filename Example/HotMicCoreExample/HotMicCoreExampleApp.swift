import SwiftUI

@main
struct HotMicCoreExampleApp: App {
    static let defaultAPIKey = "90598599-fe2a-435f-b074-e494f2f5c60b"
    static let defaultAccessToken = "eyJhbGciOiJIUzI1NiJ9.eyJpZGVudGl0eSI6eyJ1c2VyX2lkIjoiM2Q1NTY3YzItNjAzYy00YjA4LWI5MTctN2U5ZjA1YzhlYmI1IiwiZGlzcGxheV9uYW1lIjoidGVzdGVyMSIsInByb2ZpbGVfcGljIjoiaHR0cHM6Ly91aS1hdmF0YXJzLmNvbS9hcGkvP25hbWU9dGVzdCZiYWNrZ3JvdW5kPTBEQ0FENiZjb2xvcj1mZmYiLCJiYWRnZSI6Imh0dHBzOi8vaG90bWljLWNvbnRlbnQuczMudXMtd2VzdC0xLmFtYXpvbmF3cy5jb20vYmFkZ2VzLzEwX2JhZGdlLnBuZz9jMjUxZmVjZS1jMDhmLTQ4YTAtOTMxZS03MGNmZThlYTdlZDQifSwiaWF0IjoxNjU3NjU4NTU1LCJleHAiOjE4MjE3MjQwMTR9.dXzoaMkWN8rp6bZ9Z-Zhit5c4rqoWTWRHIVHm2fKluk"

    var body: some Scene {
        WindowGroup {
            StreamsView()
        }
    }
}
