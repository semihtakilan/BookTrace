//
//  Registrations.swift
//  BookTrace
//
//  Created by Batuhan Baran on 30.07.2026.
//

import FactoryKit
import NetworkRegistration

extension Container: @retroactive AutoRegistering {

    public func autoRegister() {
        NetworkRegistrations.register()

        Container.shared.homeService.register {
            HomeServiceLive()
        }
    }
}
