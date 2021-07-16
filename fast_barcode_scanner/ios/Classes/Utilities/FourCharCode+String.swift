import Foundation

extension FourCharCode {
    func toString() -> String {
        String(cString: [
            CChar(self >> 24 & 0xFF),
            CChar(self >> 16 & 0xFF),
            CChar(self >> 8 & 0xFF),
            CChar(self & 0xFF),
            0
        ])
    }
}
