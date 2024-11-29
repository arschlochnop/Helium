//
//  WidgetManager.swift
//
//  小组件管理器
//  Created by lemin on 10/16/23.
//

import Foundation
import SwiftUI

/// 小组件类型枚举
/// 每个类型都有一个唯一的原始值用于存储和识别
enum WidgetModule: Int, CaseIterable {
    case dateWidget = 1      // 日期小组件
    case timeWidget = 5      // 时间小组件
    case network = 2         // 网络小组件
    case battery = 4         // 电池小组件
    case currentCapacity = 7 // 当前电量
    case chargeSymbol = 8    // 充电符号
    case temperature = 3     // 温度小组件
    case textWidget = 6      // 文本小组件
    case weather = 9         // 天气小组件
    case webWidget = 10      // 网页小组件
}

/// 小组件标识结构
/// 用于唯一标识每个小组件实例及其配置
struct WidgetIDStruct: Identifiable, Equatable {
    static func == (lhs: WidgetIDStruct, rhs: WidgetIDStruct) -> Bool {
        return (lhs.id == rhs.id)
    }

    var id = UUID()
    var module: WidgetModule        // 小组件类型
    var config: [String: Any]       // 小组件配置
    var modified: Bool = false      // 修改状态标记
}

/// 模糊效果详细信息结构
struct BlurDetailsStruct: Identifiable, Equatable {
    static func == (lhs: BlurDetailsStruct, rhs: BlurDetailsStruct) -> Bool {
        return (lhs.id == rhs.id)
    }

    var id = UUID()
    var hasBlur: Bool              // 是否启用模糊
    var cornerRadius: Double       // 圆角半径（存储为Int，运行时使用Double）
    var styleDark: Bool           // 是否为深色风格
    var alpha: Double             // 透明度
}

/// 颜色详细信息结构
struct ColorDetailsStruct: Identifiable, Equatable {
    static func == (lhs: ColorDetailsStruct, rhs: ColorDetailsStruct) -> Bool {
        return (lhs.id == rhs.id)
    }

    var id = UUID()
    var usesCustomColor: Bool = false  // 是否使用自定义颜色
    var color: UIColor = .white       // 颜色值
}

/// 小组件集合结构
/// 包含一组相关小组件的所有配置信息
struct WidgetSetStruct: Identifiable, Equatable {
    static func == (lhs: WidgetSetStruct, rhs: WidgetSetStruct) -> Bool {
        return (lhs.id == rhs.id)
    }

    var id = UUID()

    // 基本属性
    var isEnabled: Bool            // 是否启用
    var orientationMode: Int       // 方向模式
    var title: String             // 标题
    var updateInterval: Double     // 更新间隔

    // 位置相关
    var anchor: Int               // 锚点
    var anchorY: Int             // Y轴锚点
    var offsetPX: Double         // 竖屏X偏移
    var offsetPY: Double         // 竖屏Y偏移
    var offsetLX: Double         // 横屏X偏移
    var offsetLY: Double         // 横屏Y偏移

    // 大小相关
    var autoResizes: Bool         // 自动调整大小
    var scale: Double            // 缩放比例
    var scaleY: Double           // Y轴缩放

    var widgetIDs: [WidgetIDStruct]  // 包含的小组件列表

    var blurDetails: BlurDetailsStruct  // 模糊效果设置

    // 颜色相关
    var dynamicColor: Bool        // 是否使用动态颜色
    var colorDetails: ColorDetailsStruct = .init()  // 颜色设置

    // 文本相关
    var fontName: String         // 字体名称
    var textBold: Bool          // 是否加粗
    var textItalic: Bool        // 是否斜体
    var textAlignment: Int      // 文本对齐方式
    var fontSize: Double        // 字体大小
    var textAlpha: Double       // 文本透明度
}

// MARK: - 小组件管理器类
class WidgetManager: ObservableObject {
    @Published var widgetSets: [WidgetSetStruct]

    /// 初始化方法
    /// - Parameter widgetSets: 初始小组件集合数组
    init(widgetSets: [WidgetSetStruct]) {
        self.widgetSets = widgetSets
    }

    /// 便利初始化方法
    /// 创建空的管理器并加载已保存的小组件集合
    convenience init() {
        self.init(widgetSets: [])
        self.widgetSets = getWidgetSets()
    }

    /// 获取保存的小组件集合列表
    /// - Returns: 小组件集合数组
    public func getWidgetSets() -> [WidgetSetStruct] {
        let defaults = UserDefaults.standard
        var sets: [WidgetSetStruct] = []

        if let dict: [[String: Any]] = defaults.array(forKey: "widgetProperties", forPath: USER_DEFAULTS_PATH) as? [[String: Any]] {
            for s in dict {
                // get the list of widget ids
                var widgetIDs: [WidgetIDStruct] = []
                if let ids = s["widgetIDs"] as? [[String: Any]] {
                    for w in ids {
                        var widgetID: Int = 0
                        var config: [String: Any] = [:]
                        for k in w.keys {
                            if k == "widgetID" {
                                widgetID = w[k] as? Int ?? 0
                            } else {
                                config[k] = w[k]
                            }
                        }
                        var module: WidgetModule? = nil
                        for m in WidgetModule.allCases {
                            if m.rawValue == widgetID {
                                module = m
                                break
                            }
                        }
                        if let module = module {
                            widgetIDs.append(.init(module: module, config: config))
                        }
                    }
                }
                let blurDetails: [String: Any] = s["blurDetails"] as? [String: Any] ?? [:]
                let blurDetailsStruct: BlurDetailsStruct = .init(
                    hasBlur: blurDetails["hasBlur"] as? Bool ?? false,
                    cornerRadius: blurDetails["cornerRadius"] as? Double ?? 4,
                    styleDark: blurDetails["styleDark"] as? Bool ?? true,
                    alpha: blurDetails["alpha"] as? Double ?? 1.0
                )
                let colorDetails: [String: Any] = s["colorDetails"] as? [String: Any] ?? [:]
                let selectedColor: UIColor = UIColor.getColorFromData(data: colorDetails["color"] as? Data) ?? UIColor.white
                let colorDetailsStruct: ColorDetailsStruct = .init(
                    usesCustomColor: colorDetails["usesCustomColor"] as? Bool ?? false,
                    color: selectedColor
                )
                // create the object
                var widgetSet: WidgetSetStruct = .init(
                    isEnabled: s["isEnabled"] as? Bool ?? true,
                    orientationMode: s["orientationMode"] as? Int ?? 0,
                    title: s["title"] as? String ?? NSLocalizedString("Untitled", comment: ""),
                    updateInterval: s["updateInterval"] as? Double ?? 1.0,
                    anchor: s["anchor"] as? Int ?? 0,
                    anchorY: s["anchorY"] as? Int ?? 0,
                    offsetPX: s["offsetPX"] as? Double ?? 0.0,
                    offsetPY: s["offsetPY"] as? Double ?? 0.0,
                    offsetLX: s["offsetLX"] as? Double ?? 0.0,
                    offsetLY: s["offsetLY"] as? Double ?? 0.0,

                    autoResizes: s["autoResizes"] as? Bool ?? false,
                    scale: s["scale"] as? Double ?? 100.0,
                    scaleY: s["scaleY"] as? Double ?? 12.0,

                    widgetIDs: widgetIDs,

                    blurDetails: blurDetailsStruct,

                    dynamicColor: s["dynamicColor"] as? Bool ?? true,
                    fontName: s["fontName"] as? String ?? "System Font",
                    textBold: s["textBold"] as? Bool ?? false,
                    textItalic: s["textItalic"] as? Bool ?? false,
                    textAlignment: s["textAlignment"] as? Int ?? 1,
                    fontSize: s["fontSize"] as? Double ?? 10.0,
                    textAlpha: s["textAlpha"] as? Double ?? 1.0
                )
                widgetSet.colorDetails = colorDetailsStruct
                sets.append(widgetSet)
            }
        }

        return sets
    }

    /// 保存所有小组件集合到用户默认设置
    public func saveWidgetSets() {
        let defaults = UserDefaults.standard
        var dict: [[String: Any]] = []

        for s in widgetSets {
            var wSet: [String: Any] = [:]
            wSet["isEnabled"] = s.isEnabled
            wSet["orientationMode"] = s.orientationMode
            wSet["title"] = s.title
            wSet["updateInterval"] = s.updateInterval

            wSet["anchor"] = s.anchor
            wSet["anchorY"] = s.anchorY
            wSet["offsetPX"] = s.offsetPX
            wSet["offsetPY"] = s.offsetPY
            wSet["offsetLX"] = s.offsetLX
            wSet["offsetLY"] = s.offsetLY

            wSet["autoResizes"] = s.autoResizes
            wSet["scale"] = s.scale
            wSet["scaleY"] = s.scaleY

            var widgetIDs: [[String: Any]] = []
            for w in s.widgetIDs {
                var widget: [String: Any] = [:]
                widget["widgetID"] = w.module.rawValue
                for c in w.config.keys {
                    widget[c] = w.config[c]
                }
                widgetIDs.append(widget)
            }
            wSet["widgetIDs"] = widgetIDs

            let blurDetails: [String: Any] = [
                "hasBlur": s.blurDetails.hasBlur,
                "cornerRadius": Int(s.blurDetails.cornerRadius),
                "styleDark": s.blurDetails.styleDark,
                "alpha": s.blurDetails.alpha
            ]
            wSet["blurDetails"] = blurDetails

            wSet["dynamicColor"] = s.dynamicColor
            let colorDetails: [String: Any] = [
                "usesCustomColor": s.colorDetails.usesCustomColor,
                "color": s.colorDetails.color.data as Any
            ]
            wSet["colorDetails"] = colorDetails

            wSet["fontName"] = s.fontName
            wSet["textBold"] = s.textBold
            wSet["textItalic"] = s.textItalic
            wSet["textAlignment"] = s.textAlignment
            wSet["fontSize"] = s.fontSize
            wSet["textAlpha"] = s.textAlpha

            dict.append(wSet)
        }

        // save it to user defaults
        if dict.count > 0 {
            defaults.setValue(dict, forKey: "widgetProperties", forPath: USER_DEFAULTS_PATH)
        } else {
            // remove from the defaults
            defaults.removeObject(forKey: "widgetProperties", forPath: USER_DEFAULTS_PATH)
        }

        DarwinNotificationCenter.default.post(name: NOTIFY_RELOAD_HUD)
    }

    // MARK: - 小组件修改管理

    /// 添加新的小组件到指定集合
    /// - Parameters:
    ///   - widgetSet: 目标小组件集合
    ///   - module: 小组件类型
    ///   - config: 小组件配置
    ///   - save: 是否立即保存
    /// - Returns: 新创建的小组件标识结构
    public func addWidget(widgetSet: WidgetSetStruct, module: WidgetModule, config: [String: Any], save: Bool = true) -> WidgetIDStruct {
        let newWidget: WidgetIDStruct = .init(module: module, config: config)
        for (i, wSet) in widgetSets.enumerated() {
            if wSet == widgetSet {
                widgetSets[i].widgetIDs.append(newWidget)
            }
        }
        if save { saveWidgetSets(); }
        return newWidget
    }

    /// 添加新的小组件（使用默认配置）
    public func addWidget(widgetSet: WidgetSetStruct, module: WidgetModule, save: Bool = true) -> WidgetIDStruct {
        let config: [String: Any] = [:]
        return addWidget(widgetSet: widgetSet, module: module, config: config, save: save)
    }

    /// 根据索引删除小组件
    public func removeWidget(widgetSet: WidgetSetStruct, id: Int, save: Bool = true) {
        for (i, wSet) in widgetSets.enumerated() {
            if wSet == widgetSet {
                widgetSets[i].widgetIDs.remove(at: id)
            }
        }
        if save { saveWidgetSets(); }
    }

    /// 移动小组件位置
    public func moveWidget(widgetSet: WidgetSetStruct, source: IndexSet, destination: Int) {
        for (i, wSet) in widgetSets.enumerated() {
            if wSet == widgetSet {
                widgetSets[i].widgetIDs.move(fromOffsets: source, toOffset: destination)
            }
        }
    }

    /// 根据小组件标识删除小组件
    public func removeWidget(widgetSet: WidgetSetStruct, id: WidgetIDStruct, save: Bool = true) {
        for (i, wID) in widgetSet.widgetIDs.enumerated() {
            if wID == id {
                removeWidget(widgetSet: widgetSet, id: i, save: save)
                break
            }
        }
    }

    /// 更新小组件配置
    public func updateWidgetConfig(widgetSet: WidgetSetStruct, id: WidgetIDStruct, newID: WidgetIDStruct, save: Bool = true) {
        for (i, wSet) in widgetSets.enumerated() {
            if wSet == widgetSet {
                for (j, wID) in wSet.widgetIDs.enumerated() {
                    if wID == id {
                        widgetSets[i].widgetIDs[j].config = newID.config
                        if save { saveWidgetSets(); }
                        return
                    }
                }
            }
        }
    }

    // MARK: - 小组件集合修改管理

    /// 添加新的小组件集合
    public func addWidgetSet(widgetSet: WidgetSetStruct, save: Bool = true) {
        widgetSets.append(widgetSet)
        if save { saveWidgetSets(); }
    }

    /// 删除小组件集合
    public func removeWidgetSet(widgetSet: WidgetSetStruct, save: Bool = true) {
        for (i, wSet) in widgetSets.enumerated() {
            if widgetSet == wSet {
                widgetSets.remove(at: i)
                break
            }
        }
        if save { saveWidgetSets(); }
    }

    /// 创建新的小组件集合
    /// - Parameters:
    ///   - title: 集合标题
    ///   - anchor: 锚点位置
    ///   - save: 是否立即保存
    public func createWidgetSet(title: String, anchor: Int = 0, save: Bool = true) {
        // create a widget set with the default values
        addWidgetSet(widgetSet: .init(
            isEnabled: true,
            orientationMode: 0,
            title: title,
            updateInterval: 1.0,

            anchor: anchor,
            anchorY: 0,
            offsetPX: anchor == 1 ? 0.0 : 10.0,
            offsetPY: 0.0,
            offsetLX: anchor == 1 ? 0.0 : 10.0,
            offsetLY: 0.0,

            autoResizes: true,
            scale: 100.0,
            scaleY: 12.0,

            widgetIDs: [],

            blurDetails: .init(
                hasBlur: false,
                cornerRadius: 4,
                styleDark: true,
                alpha: 1.0
            ),

            dynamicColor: true,
            fontName: "System Font",
            textBold: false,
            textItalic: false,
            textAlignment: 1,
            fontSize: 10.0,
            textAlpha: 1.0
        ), save: save)

        if IsHUDEnabledBridger() {
            SetHUDEnabledBridger(false)
            SetHUDEnabledBridger(true)
        }
    }

    /// 编辑现有小组件集合
    /// - Parameters:
    ///   - widgetSet: 要编辑的集合
    ///   - ns: 新的集合详情
    ///   - save: 是否立即保存
    public func editWidgetSet(widgetSet: WidgetSetStruct, newSetDetails ns: WidgetSetStruct, save: Bool = true) {
        for (i, wSet) in widgetSets.enumerated() {
            if wSet == widgetSet {
                widgetSets[i].isEnabled = ns.isEnabled
                widgetSets[i].orientationMode = ns.orientationMode
                widgetSets[i].title = ns.title
                widgetSets[i].updateInterval = ns.updateInterval

                widgetSets[i].anchor = ns.anchor
                widgetSets[i].anchorY = ns.anchorY
                widgetSets[i].offsetPX = ns.offsetPX
                widgetSets[i].offsetPY = ns.offsetPY
                widgetSets[i].offsetLX = ns.offsetLX
                widgetSets[i].offsetLY = ns.offsetLY

                widgetSets[i].autoResizes = ns.autoResizes
                widgetSets[i].scale = ns.scale
                widgetSets[i].scaleY = ns.scaleY

                widgetSets[i].blurDetails = ns.blurDetails

                widgetSets[i].dynamicColor = ns.dynamicColor
                widgetSets[i].colorDetails = ns.colorDetails

                widgetSets[i].fontName = ns.fontName
                widgetSets[i].textBold = ns.textBold
                widgetSets[i].textItalic = ns.textItalic
                widgetSets[i].textAlignment = ns.textAlignment
                widgetSets[i].fontSize = ns.fontSize
                widgetSets[i].textAlpha = ns.textAlpha
                break
            }
        }
        if save { saveWidgetSets(); }
    }

    /// 获取更新后的小组件集合
    /// - Parameter widgetSet: 要获取的集合
    /// - Returns: 更新后的集合，如果不存在则返回nil
    public func getUpdatedWidgetSet(widgetSet: WidgetSetStruct) -> WidgetSetStruct? {
        for wSet in widgetSets {
            if wSet == widgetSet {
                return wSet
            }
        }
        return nil
    }
}

// MARK: - 小组件预览详情
class WidgetDetails {
    /// 获取小组件的详细信息
    /// - Parameter module: 小组件类型
    /// - Returns: (名称, 示例文本)的元组
    static func getDetails(_ module: WidgetModule) -> (String, String) {
        switch (module) {
        case .dateWidget:
            return (NSLocalizedString("Date", comment: ""), NSLocalizedString("Mon Oct 16", comment: ""))
        case .network:
            return (NSLocalizedString("Network", comment: ""), "▲ 0 KB/s")
        case .temperature:
            return (NSLocalizedString("Device Temperature", comment: ""), "29.34ºC")
        case .battery:
            return (NSLocalizedString("Battery Details", comment: ""), "25 W")
        case .timeWidget:
            return (NSLocalizedString("Time", comment: ""), "14:57:05")
        case .textWidget:
            return (NSLocalizedString("Text Label", comment: ""), NSLocalizedString("Example", comment: ""))
        case .currentCapacity:
            return (NSLocalizedString("Battery Capacity", comment: ""), "50%")
        case .chargeSymbol:
            return (NSLocalizedString("Charging Symbol", comment: ""), "⚡️")
        case .weather:
            return (NSLocalizedString("Weather", comment: ""), "🌤 20℃")
        case .webWidget:
            return (NSLocalizedString("eb PageW", comment: ""), "https://example.com")
        }
    }

    /// 获取小组件名称
    static func getWidgetName(_ module: WidgetModule) -> String {
        let (name, _) = getDetails(module)
        return name
    }

    /// 获取小组件示例文本
    static func getWidgetExample(_ module: WidgetModule) -> String {
        let (_, example) = getDetails(module)
        return example
    }
}
