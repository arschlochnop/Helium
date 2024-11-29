//
//  SettingsView.swift
//  氦气UI
//
//  Created by lemin on 10/19/23.
//

import Foundation
import SwiftUI

// 构建号
let buildNumber: Int = 0
// 调试模式是否启用
let DEBUG_MODE_ENABLED = false
// 用户默认设置路径
let USER_DEFAULTS_PATH = "/var/mobile/Library/Preferences/com.leemin.helium.plist"

// MARK: 设置视图
// TODO: 这里需要完成
struct SettingsView: View {
    // 调试变量
    @State var sideWidgetSize: Int = 100
    @State var centerWidgetSize: Int = 100

    // 偏好变量
    @State var apiKey: String = ""
    @State var dateLocale: String = "en_US"
    @State var hideSaveConfirmation: Bool = false
    @State var debugBorder: Bool = false
    @State var hideWidgetsInScreenshot: Bool = false

    var body: some View {
        NavigationView {
            List {
                // 应用版本/构建号
                Section {

                } header: {
                    Label(NSLocalizedString("版本 ", comment:"") + "\(Bundle.main.releaseVersionNumber ?? NSLocalizedString("未知", comment:"")) (\(buildNumber != 0 ? "\(buildNumber)" : NSLocalizedString("发布", comment:"")))", systemImage: "info")
                }

                // 偏好列表
                Section {
                    HStack {
                        Text(NSLocalizedString("日期地区", comment:""))
                            .bold()
                        Spacer()
                        Picker("", selection: $dateLocale) {
                            Text("en_US").tag("en_US")
                            Text("zh_CN").tag("zh_CN")
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Text(NSLocalizedString("天气Api密钥", comment:""))
                            .bold()
                        Spacer()
                        TextField("", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    HStack {
                        Toggle(isOn: $hideSaveConfirmation) {
                            Text(NSLocalizedString("隐藏保存确认弹出", comment:""))
                                .bold()
                                .minimumScaleFactor(0.5)
                        }
                    }

                    HStack {
                        Toggle(isOn: $debugBorder) {
                            Text(NSLocalizedString("显示调试边框", comment:""))
                                .bold()
                                .minimumScaleFactor(0.5)
                        }
                    }

                    HStack {
                        Toggle(isOn: $hideWidgetsInScreenshot) {
                            Text(NSLocalizedString("截图时隐藏小组件", comment:""))
                                .bold()
                                .minimumScaleFactor(0.5)
                        }
                    }

                    HStack {
                        Text(NSLocalizedString("氦气数据", comment:""))
                            .bold()
                        Spacer()
                        Button(action: {
                            do {
                                try UserDefaults.standard.deleteUserDefaults(forPath: USER_DEFAULTS_PATH)
                                UIApplication.shared.alert(title: NSLocalizedString("成功删除用户数据！", comment:""), body: NSLocalizedString("请重启应用以继续。", comment:""))
                            } catch {
                                UIApplication.shared.alert(title: NSLocalizedString("删除用户数据失败！", comment:""), body: error.localizedDescription)
                            }
                        }) {
                            Text(NSLocalizedString("重置数据", comment:""))
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Label(NSLocalizedString("偏好", comment:""), systemImage: "gear")
                }

                // 调试设置
                if #available(iOS 15, *), DEBUG_MODE_ENABLED {
                    Section {
                        HStack {
                            Text(NSLocalizedString("侧边小部件大小", comment:""))
                                .bold()
                            Spacer()
                            TextField(NSLocalizedString("侧边大小", comment:""), value: $sideWidgetSize, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .submitLabel(.done)
                        }

                        HStack {
                            Text(NSLocalizedString("中心小部件大小", comment:""))
                                .bold()
                            Spacer()
                            TextField(NSLocalizedString("中心大小", comment:""), value: $centerWidgetSize, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.decimalPad)
                                .submitLabel(.done)
                        }
                    } header: {
                        Label(NSLocalizedString("调试偏好", comment:""), systemImage: "ladybug")
                    }
                }

                //鸣谢列表
                Section {
                    LinkCell(imageName: "leminlimez", url: "https://github.com/leminlimez", title: "LeminLimez", contribution: NSLocalizedString("主开发者", comment: "leminlimez的贡献"), circle: true)
                    LinkCell(imageName: "lessica", url: "https://github.com/Lessica/TrollSpeed", title: "Lessica", contribution: NSLocalizedString("TrollSpeed & 辅助触摸逻辑", comment: "lessica的贡献"), circle: true)
                    LinkCell(imageName: "fuuko", url: "https://github.com/AsakuraFuuko", title: "Fuuko", contribution: NSLocalizedString("修改者", comment: "Fuuko的贡献"), imageInBundle: true, circle: true)
                    LinkCell(imageName: "bomberfish", url: "https://github.com/BomberFish", title: "BomberFish", contribution: NSLocalizedString("UI改进", comment: "BomberFish的贡献"), imageInBundle: true, circle: true)
                } header: {
                    Label(NSLocalizedString("鸣谢", comment:""), systemImage: "wrench.and.screwdriver")
                }
            }
            .toolbar {
                HStack {
                    Button(action: {
                        saveChanges()
                    }) {
                        Text(NSLocalizedString("保存", comment:""))
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
            .navigationTitle(Text(NSLocalizedString("设置", comment:"")))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // 加载设置
    func loadSettings() {
        dateLocale = UserDefaults.standard.string(forKey: "dateLocale", forPath: USER_DEFAULTS_PATH) ?? "en_US"
        apiKey = UserDefaults.standard.string(forKey: "apiKey", forPath: USER_DEFAULTS_PATH) ?? ""
        hideSaveConfirmation = UserDefaults.standard.bool(forKey: "hideSaveConfirmation", forPath: USER_DEFAULTS_PATH)
        debugBorder = UserDefaults.standard.bool(forKey: "debugBorder", forPath: USER_DEFAULTS_PATH)
        hideWidgetsInScreenshot = UserDefaults.standard.bool(forKey: "hideWidgetsInScreenshot", forPath: USER_DEFAULTS_PATH)
    }

    // 保存更改
    func saveChanges() {
        UserDefaults.standard.setValue(apiKey, forKey: "apiKey", forPath: USER_DEFAULTS_PATH)
        UserDefaults.standard.setValue(dateLocale, forKey: "dateLocale", forPath: USER_DEFAULTS_PATH)
        UserDefaults.standard.setValue(hideSaveConfirmation, forKey: "hideSaveConfirmation", forPath: USER_DEFAULTS_PATH)
        UserDefaults.standard.setValue(debugBorder, forKey: "debugBorder", forPath: USER_DEFAULTS_PATH)
        UserDefaults.standard.setValue(hideWidgetsInScreenshot, forKey: "hideWidgetsInScreenshot", forPath: USER_DEFAULTS_PATH)
        UIApplication.shared.alert(title: NSLocalizedString("保存更改", comment:""), body: NSLocalizedString("设置已成功保存", comment:""))
        DarwinNotificationCenter.default.post(name: NOTIFY_RELOAD_HUD)
    }

    // 连接单元格代码来自Cowabunga
    struct LinkCell: View {
        var imageName: String
        var url: String
        var title: String
        var contribution: String
        var systemImage: Bool = false
        var imageInBundle: Bool = false
        var circle: Bool = false

        var body: some View {
            HStack(alignment: .center) {
                Group {
                    if systemImage {
                        Image(systemName: imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if imageInBundle {
                        let url = Bundle.main.url(forResource: "credits/" + imageName, withExtension: "png")
                        if url != nil {
                            Image(uiImage: UIImage(contentsOfFile: url!.path)!)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    } else {
                        if imageName != "" {
                            Image(imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                }
                .cornerRadius(circle ? .infinity : 0)
                .frame(width: 24, height: 24)

                VStack {
                    HStack {
                        Button(action: {
                            if url != "" {
                                UIApplication.shared.open(URL(string: url)!)
                            }
                        }) {
                            Text(title)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 6)
                        Spacer()
                    }
                    HStack {
                        Text(contribution)
                            .padding(.horizontal, 6)
                            .font(.footnote)
                        Spacer()
                    }
                }
            }
            .foregroundColor(.blue)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
