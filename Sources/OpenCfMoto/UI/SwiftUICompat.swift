// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - SwiftUI Compatibility Layer

import SwiftUI

#if swift(<5.7)
extension Font {
    /// Compatibility fallback for older Swift toolchains (Swift < 5.7)
    public func bold() -> Font {
        return self
    }
}
#endif
