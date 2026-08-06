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

    init(url: URL?, width: CGFloat? = nil, height: CGFloat, contentMode: SwiftUI.ContentMode) {
        self.url = url
        self.width = width
        self.height = height
        self.contentMode = contentMode
    }

    var body: some View {
        KFImage(url)
            .placeholder { Color.gray.opacity(0.2) }
            .resizable()
            .aspectRatio(contentMode: contentMode)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
