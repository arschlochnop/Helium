//
//  WidgetPreviewsView.swift
//  Helium UI
//
//  创建者: lemin
//  创建时间: 2023/10/16
//

import Foundation
import SwiftUI

/// 小部件预览视图
/// 用于显示各种类型小部件的预览效果，包括日期、时间、网络状态、温度、电池等
/// 支持动态更新预览内容
struct WidgetPreviewsView: View {
    @Binding var widget: WidgetIDStruct
    @State var text: String = ""
    @State var image: Image?
    @State var previewColor: Color = .primary

    var body: some View {
        HStack {
            ZStack {
                Image(uiImage: UIImage(named: "wallpaper")!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.5)
                    .frame(width: 125, height: 50)
                    .cornerRadius(12)
                    .clipped()
                ZStack {
                    if image == nil {
                        Text(text)
                            .padding(.vertical, 5)
                            .foregroundColor(previewColor)
                            .minimumScaleFactor(0.01)
                    } else {
                        Text(image!)
                            .padding(.vertical, 5)
                            .foregroundColor(previewColor)
                            .minimumScaleFactor(0.01)
                    }
                }
                .frame(width: 125, height: 50)
            }
            .padding(.trailing, 5)
        }
        .onAppear {
            updatePreview()
        }
        .onChange(of: widget.modified) { nv in
            if nv {
                updatePreview()
            }
        }
    }

    /// 更新预览内容
    /// 根据不同的小部件类型(widget.module)更新预览显示的内容：
    /// - 日期时间：根据设定的格式显示当前日期或时间
    /// - 网络：显示网络上传/下载速度
    /// - 温度：显示温度值(支持华氏/摄氏)
    /// - 电池：显示电池相关信息(功率/电流/百分比)
    /// - 文本：显示自定义文本
    /// - 天气：显示天气预览
    /// - 当前容量：显示容量百分比
    /// - 充电符号：显示充电图标
    /// - 网页：显示网页预览
    func updatePreview() {
        switch (widget.module) {
        case .dateWidget, .timeWidget:
            let dateFormat: String = widget.config["dateFormat"] as? String ?? (widget.module == .dateWidget ? NSLocalizedString("E MMM dd", comment:"") : "hh:mm")
            let dateFormatter = DateFormatter()
            let newDateFormat = LunarDate.getChineseCalendar(with: Date(), format: dateFormat)
            dateFormatter.dateFormat = newDateFormat
            let locale = UserDefaults.standard.string(forKey: "dateLocale", forPath: USER_DEFAULTS_PATH) ?? "en_US"
            dateFormatter.locale = Locale(identifier: locale)
            text = dateFormatter.string(from: Date())
            // 安全检查
            if (text == "") {
                text = NSLocalizedString("ERROR", comment:"")
            }
        case .network:
            let isUp: Bool = widget.config["isUp"] as? Bool ?? false
            let speedIcon: Int = widget.config["speedIcon"] as? Int ?? 0
            text = "\(isUp ? (speedIcon == 0 ? "▲" : "↑") : (speedIcon == 0 ? "▼" : "↓")) 30 KB/s"
        case .temperature:
            text = widget.config["useFahrenheit"] as? Bool ?? false ? "78.84ºF" : "26.02ºC"
        case .battery:
            let batteryValue: Int = widget.config["batteryValueType"] as? Int ?? 0
            switch (batteryValue) {
            case 0:
                text = "0 W"
            case 1:
                text = "0 mA"
            case 2:
                text = "0 mA"
            case 3:
                text = "25"
            default:
                text = "???"
            }
        case .textWidget:
            text = widget.config["text"] as? String ?? NSLocalizedString("Unknown", comment:"")
            break;
        case .weather:
            text = NSLocalizedString("Weather Preview", comment:"")
            break;
        case .currentCapacity:
            text = "50\(widget.config["showPercentage"] as? Bool ?? true ? "%" : "")"
        case .chargeSymbol:
            image = widget.config["filled"] as? Bool ?? true ? Image(systemName: "bolt.fill") : Image(systemName: "bolt")
        case .webWidget:
            // 获取配置的URL，如果没有则显示默认文本
            let url = widget.config["url"] as? String
            let showUrl = widget.config["showUrl"] as? Bool ?? false
            if let url = url, showUrl {
                text = url
            } else {
                text = NSLocalizedString("Web Page", comment: "")
            }
        }
        widget.modified = false
    }
}
