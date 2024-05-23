//
//  Data+UrlBase64.swift
//  react-native-starling
//
//  Created by Viktor Strate Kløvedal on 06/11/2023.
//

import Foundation

extension Data {
    func urlSafeBase64() -> String {
        return self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }
    
    init?(urlSafeBase64String: String) {
        let string = urlSafeBase64String
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        self.init(base64Encoded: string)
    }
}
