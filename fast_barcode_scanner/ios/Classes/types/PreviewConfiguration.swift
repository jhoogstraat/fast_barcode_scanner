//
//  PreviewConfiguration.swift
//  fast_barcode_scanner
//
//  Created by Joshua Hoogstraat on 27.06.21.
//

struct PreviewConfiguration {
    let width: Int32
    let height: Int32
    let orientation: Int
    let textureId: Int64
    
    var dict: [String: Any] {
        ["width": height,
         "height": width,
         "orientation": orientation,
         "textureId": textureId]
    }
    
}
