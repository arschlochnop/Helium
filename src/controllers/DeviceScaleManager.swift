//
//  DeviceScaleManager.swift
//
//
//  Created by lemin on 12/15/23.
//

import Foundation
import SwiftUI

struct PresetStruct: Identifiable {
    var id = UUID()

    var width: Double
    var offsetX: Double
    var offsetY: Double
}

enum Preset: String, CaseIterable {
    case above = "Above Status Bar"
    case below = "Below Status Bar"
}

class DeviceScaleManager {
    static let shared = DeviceScaleManager()

    // 获取设备名称
    private func getDeviceName() -> String {
        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModelIdentifier
        }

        var sysinfo = utsname()
        uname(&sysinfo) // ignore return value
        let deviceModel = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters)

        return deviceModel ?? ""
    }

    // 获取设备尺寸
    /*
     尺寸:
     0 = 无刘海
     1 = 小刘海
     2 = 大刘海
     3 = 动态岛屿
     */
    private func getDeviceSize() -> Int {
        let deviceModel: String = getDeviceName()

        // 获取刘海尺寸
        if (deviceModel.starts(with: "iPhone14")) {
            // 小刘海
            return 1
        } else if (
            deviceModel.starts(with: "iPhone10,3")
            || deviceModel.starts(with: "iPhone10,6")
            || deviceModel.starts(with: "iPhone11")
            || deviceModel.starts(with: "iPhone12")
            || deviceModel.starts(with: "iPhone13")
        ) {
            // 大刘海
            return 2
        } else if (
            deviceModel.starts(with: "iPhone15")
            || deviceModel.starts(with: "iPhone16")
        ) {
            // 动态岛屿
            return 3
        }
        return 0
    }
}
