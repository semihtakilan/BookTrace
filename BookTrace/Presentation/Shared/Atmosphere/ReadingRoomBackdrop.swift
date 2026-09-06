//
//  ReadingRoomBackdrop.swift
//  Atmosphere
//
//  Created by Semih TAKILAN on 06.09.2026.
//

import Kingfisher
import Models
import SwiftUI

/// The cover provides the room's colors and light; the genre provides its
/// texture. Two books in the same genre retain their own visual identity.
struct ReadingRoomBackdrop: View {
    let book: BookReference
    var isActive = true

    @Environment(\.bookPalette) private var palette
    @Environment(\.bookAmbience) private var ambience

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                AmbienceBackdrop(ambience: ambience, palette: palette, isActive: isActive)

                if let url = book.coverURL {
                    KFImage(url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height * 0.72)
                        .clipped()
                        .blur(radius: 54, opaque: false)
                        .opacity(0.2)
                        .mask {
                            LinearGradient(colors: [.clear, .white, .clear],
                                           startPoint: .top, endPoint: .bottom)
                        }
                        .blendMode(.screen)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
