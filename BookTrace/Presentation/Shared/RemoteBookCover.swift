//
//  RemoteBookCover.swift
//  BookTrace
//

import Kingfisher
import SwiftUI

struct RemoteBookCover: View {
    let url: URL?
    let width: CGFloat?
    let height: CGFloat
    let contentMode: SwiftUI.ContentMode
    let fallbackTitle: String?
    let fallbackAuthor: String?

    init(
        url: URL?,
        width: CGFloat? = nil,
        height: CGFloat,
        contentMode: SwiftUI.ContentMode,
        fallbackTitle: String? = nil,
        fallbackAuthor: String? = nil
    ) {
        self.url = url
        self.width = width
        self.height = height
        self.contentMode = contentMode
        self.fallbackTitle = fallbackTitle
        self.fallbackAuthor = fallbackAuthor
    }

    var body: some View {
        KFImage(url)
            .placeholder {
                fallbackView
            }
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            // If the URL is genuinely nil or fails, KFImage will still show placeholder.
            // But if url is nil, KFImage alone might not render at all or render empty. 
            // So we explicitly show fallback if URL is nil.
            .overlay {
                if url == nil {
                    fallbackView
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
    }

    @ViewBuilder
    private var fallbackView: some View {
        ZStack {
            LinearGradient(
                colors: [.accentColor.opacity(0.6), .accentColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 6) {
                if let fallbackTitle = fallbackTitle {
                    Text(fallbackTitle)
                        .font(.system(size: height > 150 ? 16 : 12, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .lineLimit(4)
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: height > 150 ? 40 : 24))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if let fallbackAuthor = fallbackAuthor, !fallbackAuthor.isEmpty {
                    Text(fallbackAuthor)
                        .font(.system(size: height > 150 ? 12 : 10, weight: .medium, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Add a subtle book spine effect
            HStack {
                Rectangle()
                    .fill(Color.black.opacity(0.1))
                    .frame(width: 4)
                Spacer()
            }
        }
    }
}
