//
//  WidgetManager.m
//
//
//  Created by lemin on 10/6/23.
//

#import <Foundation/Foundation.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <sys/wait.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>
#import "WidgetManager.h"
#import <IOKit/IOKitLib.h>
#import "../extensions/LunarDate.h"
#import "../extensions/FontUtils.h"
#import "../extensions/WeatherUtils.h"

// 感谢: https://github.com/lwlsw/NetworkSpeed13

#define KILOBITS 1000
#define MEGABITS 1000000
#define GIGABITS 1000000000
#define KILOBYTES (1 << 10)
#define MEGABYTES (1 << 20)
#define GIGABYTES (1 << 30)
#define SHOW_ALWAYS 1
// #define INLINE_SEPARATOR "\t"

// #pragma mark - 格式化方法
// static unsigned char getSeparator(NSMutableAttributedString *currentAttributed)
// {
//     return [[currentAttributed string] isEqualToString:@""] ? *"" : *"\t";
// }

#pragma mark - 小组件特定变量
// MARK: 0 - 日期小组件
static NSDateFormatter *formatter = nil;

// MARK: 网络速度小组件
static uint8_t DATAUNIT = 0;

typedef struct {
    uint64_t inputBytes;
    uint64_t outputBytes;
} UpDownBytes;

static uint64_t prevOutputBytes = 0, prevInputBytes = 0;
static NSAttributedString *attributedUploadPrefix = nil;
static NSAttributedString *attributedDownloadPrefix = nil;
static NSAttributedString *attributedUploadPrefix2 = nil;
static NSAttributedString *attributedDownloadPrefix2 = nil;

#pragma mark - Date Widget
/**
 * 格式化日期
 * @param dateFormat 日期格式
 * @param dateLocale 日期区域
 * @return 格式化后的日期字符串
 */
static NSString* formattedDate(NSString *dateFormat, NSString *dateLocale)
{
    if (!formatter) {
        formatter = [[NSDateFormatter alloc] init];
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:dateLocale];
    }
    NSDate *currentDate = [NSDate date];
    NSString *newDateFormat = [LunarDate getChineseCalendarWithDate:currentDate format:dateFormat];
    [formatter setDateFormat:newDateFormat];
    return [formatter stringFromDate:currentDate];
}

#pragma mark - Net Speed Widgets
/**
 * 获取上传和下载字节数
 * @return UpDownBytes结构体，包含上传和下载字节数
 */
static UpDownBytes getUpDownBytes()
{
    struct ifaddrs *ifa_list = 0, *ifa;
    UpDownBytes upDownBytes;
    upDownBytes.inputBytes = 0;
    upDownBytes.outputBytes = 0;

    if (getifaddrs(&ifa_list) == -1) return upDownBytes;

    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next)
    {
        /* Skip invalid interfaces */
        if (ifa->ifa_name == NULL || ifa->ifa_addr == NULL || ifa->ifa_data == NULL)
            continue;

        /* Skip interfaces that are not link level interfaces */
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;

        /* Skip interfaces that are not up or running */
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))
            continue;

        /* Skip interfaces that are not ethernet or cellular */
        if (strncmp(ifa->ifa_name, "en", 2) && strncmp(ifa->ifa_name, "pdp_ip", 6))
            continue;

        struct if_data *if_data = (struct if_data *)ifa->ifa_data;

        upDownBytes.inputBytes += if_data->ifi_ibytes;
        upDownBytes.outputBytes += if_data->ifi_obytes;
    }

    freeifaddrs(ifa_list);
    return upDownBytes;
}

/**
 * 格式化速度
 * @param bytes 字节数
 * @param minUnit 最小单位
 * @return 格式化后的速度字符串
 */
static NSString* formattedSpeed(uint64_t bytes, NSInteger minUnit)
{
    if (0 == DATAUNIT) {
        // Get min units first
        if (minUnit == 1 && bytes < KILOBYTES) return @"0 KB/s";
        else if (minUnit == 2 && bytes < MEGABYTES) return @"0 MB/s";
        else if (minUnit == 3 && bytes < GIGABYTES) return @"0 GB/s";

        if (bytes < KILOBYTES) return [NSString stringWithFormat:@"%.0f B/s", (double)bytes];
        else if (bytes < MEGABYTES) return [NSString stringWithFormat:@"%.0f KB/s", (double)bytes / KILOBYTES];
        else if (bytes < GIGABYTES) return [NSString stringWithFormat:@"%.2f MB/s", (double)bytes / MEGABYTES];
        else return [NSString stringWithFormat:@"%.2f GB/s", (double)bytes / GIGABYTES];
    } else {
        // Get min units first
        if (minUnit == 1 && bytes < KILOBITS) return @"0 Kb/s";
        else if (minUnit == 2 && bytes < MEGABITS) return @"0 Mb/s";
        else if (minUnit == 3 && bytes < GIGABITS) return @"0 Gb/s";

        if (bytes < KILOBITS) return [NSString stringWithFormat:@"%.0f b/s", (double)bytes];
        else if (bytes < MEGABITS) return [NSString stringWithFormat:@"%.0f Kb/s", (double)bytes / KILOBITS];
        else if (bytes < GIGABITS) return [NSString stringWithFormat:@"%.2f Mb/s", (double)bytes / MEGABITS];
        else return [NSString stringWithFormat:@"%.2f Gb/s", (double)bytes / GIGABITS];
    }
}

/**
 * 格式化带有属性的速度字符串
 * @param isUp 是否为上传
 * @param speedIcon 速度图标
 * @param minUnit 最小单位
 * @param hideWhenZero 是否在速度为零时隐藏
 * @param fontSize 字体大小
 * @return 带有属性的速度字符串
 */
static NSAttributedString* formattedAttributedSpeedString(BOOL isUp, NSInteger speedIcon, NSInteger minUnit, BOOL hideWhenZero, double fontSize)
{
    @autoreleasepool {
        if (!attributedUploadPrefix)
            attributedUploadPrefix = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:"▲"] stringByAppendingString:@" "] attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize]}];
        if (!attributedDownloadPrefix)
            attributedDownloadPrefix = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:"▼"] stringByAppendingString:@" "] attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize]}];
        if (!attributedUploadPrefix2)
            attributedUploadPrefix2 = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:"↑"] stringByAppendingString:@" "] attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize]}];
        if (!attributedDownloadPrefix2)
            attributedDownloadPrefix2 = [[NSAttributedString alloc] initWithString:[[NSString stringWithUTF8String:"↓"] stringByAppendingString:@" "] attributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:fontSize]}];

        NSMutableAttributedString* mutableString = [[NSMutableAttributedString alloc] init];

        UpDownBytes upDownBytes = getUpDownBytes();

        uint64_t diff;

        if (isUp) {
            if (upDownBytes.outputBytes > prevOutputBytes)
                diff = upDownBytes.outputBytes - prevOutputBytes;
            else
                diff = 0;
            prevOutputBytes = upDownBytes.outputBytes;
        } else {
            if (upDownBytes.inputBytes > prevInputBytes)
                diff = upDownBytes.inputBytes - prevInputBytes;
            else
                diff = 0;
            prevInputBytes = upDownBytes.inputBytes;
        }

        if (DATAUNIT == 1)
            diff *= 8;

        NSString *speedString = formattedSpeed(diff, minUnit);
        if (!hideWhenZero || ![speedString hasPrefix:@"0"]) {
            if (isUp)
                [mutableString appendAttributedString:(speedIcon == 0 ? attributedUploadPrefix : attributedUploadPrefix2)];
            else
                [mutableString appendAttributedString:(speedIcon == 0 ? attributedDownloadPrefix : attributedDownloadPrefix2)];
            [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString:speedString]];
        }

        return [mutableString copy];
    }
}

#pragma mark - Battery Temp Widget
/**
 * 获取电池信息
 * @return 电池信息字典
 */
NSDictionary* getBatteryInfo()
{
    CFDictionaryRef matching = IOServiceMatching("IOPMPowerSource");
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, matching);
    CFMutableDictionaryRef prop = NULL;
    IORegistryEntryCreateCFProperties(service, &prop, NULL, 0);
    NSDictionary* dict = (__bridge_transfer NSDictionary*)prop;
    IOObjectRelease(service);
    return dict;
}

/**
 * 格式化温度
 * @param useFahrenheit 是否使用华氏度
 * @return 格式化后的温度字符串
 */
static NSString* formattedTemp(BOOL useFahrenheit)
{
    NSDictionary *batteryInfo = getBatteryInfo();
    if (batteryInfo) {
        // AdapterDetails.Watts.Description.Temperature
        double temp = [batteryInfo[@"Temperature"] doubleValue] / 100.0;
        if (temp) {
            if (useFahrenheit) {
                temp = (temp * 9.0/5.0) + 32;
                return [NSString stringWithFormat: @"%.2fºF", temp];
            } else {
                return [NSString stringWithFormat: @"%.2fºC", temp];
            }
        }
    }
    return @"??ºC";
}

#pragma mark - Battery Widget
/*
 Battery Widget Identifiers:
 0 = Watts
 1 = Charging Current
 2 = Regular Amperage
 3 = Charge Cycles
 */
/**
 * 格式化电池信息
 * @param valueType 值类型
 * @return 格式化后的电池信息字符串
 */
static NSString* formattedBattery(NSInteger valueType)
{
    NSDictionary *batteryInfo = getBatteryInfo();
    if (batteryInfo) {
        if (valueType == 0) {
            // Watts
            int watts = [batteryInfo[@"AdapterDetails"][@"Watts"] longLongValue];
            if (watts) {
                return [NSString stringWithFormat: @"%d W", watts];
            } else {
                return @"0 W";
            }
        } else if (valueType == 1) {
            // Charging Current
            double current = [batteryInfo[@"AdapterDetails"][@"Current"] doubleValue];
            if (current) {
                return [NSString stringWithFormat: @"%.0f mA", current];
            } else {
                return @"0 mA";
            }
        } else if (valueType == 2) {
            // Regular Amperage
            double amps = [batteryInfo[@"Amperage"] doubleValue];
            if (amps) {
                return [NSString stringWithFormat: @"%.0f mA", amps];
            } else {
                return @"0 mA";
            }
        } else if (valueType == 3) {
            // Charge Cycles
            return [batteryInfo[@"CycleCount"] stringValue];
        } else {
            return @"???";
        }
    }
    return @"??";
}

#pragma mark - Current Capacity Widget
/**
 * 格式化当前电量
 * @param showPercentage 是否显示百分比
 * @return 格式化后的当前电量字符串
 */
static NSString* formattedCurrentCapacity(BOOL showPercentage)
{
    NSDictionary *batteryInfo = getBatteryInfo();
    if (batteryInfo) {
        return [
            NSString stringWithFormat: @"%@%@",
            [batteryInfo[@"CurrentCapacity"] stringValue],
            showPercentage ? @"%" : @""
            ];
    }
    return @"??%";
}

#pragma mark - Charging Symbol Widget
/**
 * 格式化充电符号
 * @param filled 是否填充
 * @return 充电符号字符串
 */
static NSString* formattedChargingSymbol(BOOL filled)
{
    [[UIDevice currentDevice] setBatteryMonitoringEnabled: YES];
    if ([[UIDevice currentDevice] batteryState] != UIDeviceBatteryStateUnplugged) {
        if (filled) {
            return @"bolt.fill";
        } else {
            return @"bolt";
        }
    }
    return @"";
}


#pragma mark - Main Widget Functions
/*
 小组件标识符:
 0 = 无
 1 = 日期
 2 = 网络上传/下载
 3 = 设备温度
 4 = 电池详情
 5 = 时间
 6 = 文本 | html
 7 = 电池百分比
 8 = 充电符号
 9 = 天气
 10 = Web Page

 TODO:
 - Music Visualizer
 */
/**
 * 格式化解析后的信息
 * @param parsedInfo 解析后的信息字典
 * @param parsedID 解析后的标识符
 * @param mutableString 可变属性字符串
 * @param fontSize 字体大小
 * @param textColor 文字颜色
 * @param apiKey API密钥
 * @param dateLocale 日期区域
 */
void formatParsedInfo(NSDictionary *parsedInfo, NSInteger parsedID, NSMutableAttributedString *mutableString, double fontSize, UIColor *textColor, NSString *apiKey, NSString *dateLocale)
{
    NSString *widgetString;
    NSString *sfSymbolName;
    NSString *stringData;
    NSTextAttachment *imageAttachment;
    switch (parsedID) {
        case 1:
        case 5:
            // Date/Time
            widgetString = formattedDate(
                [parsedInfo valueForKey:@"dateFormat"] ? [parsedInfo valueForKey:@"dateFormat"] : (parsedID == 1 ? NSLocalizedString(@"E MMM dd", comment: @"") : @"hh:mm"), dateLocale
            );
            break;
        case 2:
            // Network Speed
            [
                mutableString appendAttributedString: formattedAttributedSpeedString(
                    [parsedInfo valueForKey:@"isUp"] ? [[parsedInfo valueForKey:@"isUp"] boolValue] : NO,
                    [parsedInfo valueForKey:@"speedIcon"] ? [[parsedInfo valueForKey:@"speedIcon"] intValue] : 0,
                    [parsedInfo valueForKey:@"minUnit"] ? [[parsedInfo valueForKey:@"minUnit"] intValue] : 1,
                    [parsedInfo valueForKey:@"hideSpeedWhenZero"] ? [[parsedInfo valueForKey:@"hideSpeedWhenZero"] boolValue] : NO,
                    fontSize
                )
            ];
            break;
        case 3:
            // Device Temp
            widgetString = formattedTemp(
                [parsedInfo valueForKey:@"useFahrenheit"] ? [[parsedInfo valueForKey:@"useFahrenheit"] boolValue] : NO
            );
            break;
        case 4:
            // Battery Stats
            widgetString = formattedBattery(
                [parsedInfo valueForKey:@"batteryValueType"] ? [[parsedInfo valueForKey:@"batteryValueType"] integerValue] : 0
            );
            break;
        // case 6:
        //     // 偷懒方式，添加html富文本渲染,使用输入内容关键字判断，默认使用txt方式
        //     // 支持多种方式,可选项为show参数. `show=html;https://www.example.com | show=txt;https://www.example.com | show=html;<p>test</p> | https://www.example.com `
        //     stringData = [parsedInfo valueForKey:@"text"] ? [parsedInfo valueForKey:@"text"] : @"Unknown";
        //     if ([stringData isEqualToString:@"Unknown"]) {
        //         widgetString = @"Unknown";
        //     } else {
        //         NSArray *parsedComponents = [stringData componentsSeparatedByString:@";"];
        //         NSString *displayType = @"txt";
        //         NSString *laststring = parsedComponents.lastObject;

        //         if (parsedComponents.count > 1) {
        //             for (NSString *component in parsedComponents) {
        //                 if ([component hasPrefix:@"show="]) {
        //                     displayType = [component substringFromIndex:5];
        //                     break;
        //                 }
        //             }
        //         }

        //         // 检查 laststring 是否为 URL 格式
        //         NSURL *url = [NSURL URLWithString:laststring];
        //         if (url && url.scheme && url.host) {
        //             @try {
        //                 widgetString = [WeatherUtils getDataFrom:laststring];
        //                 if (!widgetString) {
        //                     widgetString = laststring;
        //                 }
        //             } @catch (NSException *exception) {
        //                 NSLog(@"Error fetching data from URL: %@", exception);
        //                 widgetString = @"Error Network";
        //             }
        //         } else {
        //             widgetString = laststring;
        //         }

        //         if ([displayType isEqualToString:@"html"]) {
        //             // 解析 HTML
        //             NSData *data = [widgetString dataUsingEncoding:NSUTF8StringEncoding];
        //             NSDictionary *options = @{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType};
        //             NSError *error;
        //             NSAttributedString *htmlString = [[NSAttributedString alloc] initWithData:data options:options documentAttributes:nil error:&error];

        //             if (htmlString) {
        //                 [mutableString appendAttributedString:htmlString];
        //             } else {
        //                 [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString: widgetString]];
        //                 NSLog(@"Error parsing HTML: %@", error.localizedDescription);
        //             }
        //         }
        //     }
        //     break;
        case 6:
            // Text
            widgetString = [parsedInfo valueForKey:@"text"] ? [parsedInfo valueForKey:@"text"] : @"Unknown";
            break;
        case 7:
            // Current Capacity
            widgetString = formattedCurrentCapacity(
                [parsedInfo valueForKey:@"showPercentage"] ? [[parsedInfo valueForKey:@"showPercentage"] boolValue] : YES
            );
            break;
        case 8:
            // Charging Symbol
            sfSymbolName = formattedChargingSymbol(
                [parsedInfo valueForKey:@"filled"] ? [[parsedInfo valueForKey:@"filled"] boolValue] : YES
            );
            if (![sfSymbolName isEqualToString:@""]) {
                imageAttachment = [[NSTextAttachment alloc] init];
                imageAttachment.image = [
                    [
                        UIImage systemImageNamed:sfSymbolName
                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:fontSize]
                    ]
                    imageWithTintColor:textColor
                ];
                [mutableString appendAttributedString:[NSAttributedString attributedStringWithAttachment:imageAttachment]];
            }
            break;
        case 9:
            {
                // Weather
                NSString *location = [parsedInfo valueForKey:@"location"];
                NSString *format = [parsedInfo valueForKey:@"format"];
                NSDictionary *now = [WeatherUtils fetchNowWeatherForLocation: location apiKey:apiKey dateLocale:dateLocale];
                NSDictionary *today = [WeatherUtils fetchTodayWeatherForLocation: location apiKey:apiKey dateLocale:dateLocale];
                widgetString = [WeatherUtils formatNowResult:now format:format];
                widgetString = [WeatherUtils formatTodayResult:today format:widgetString];
            }
            break;
        case 10:
            // Web Page
            {
                NSString *url = [parsedInfo valueForKey:@"url"];
                if (!url) {
                    widgetString = @"URL not provided";
                } else {
                    @try {
                        widgetString = [WeatherUtils getDataFrom:url];
                        if (!widgetString) {
                            widgetString = @"Failed to load content";
                        } else {
                            NSData *data = [widgetString dataUsingEncoding:NSUTF8StringEncoding];
                            NSDictionary *options = @{NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType};
                            NSError *error;
                            NSAttributedString *htmlString = [[NSAttributedString alloc] initWithData:data options:options documentAttributes:nil error:&error];

                            if (htmlString) {
                                [mutableString appendAttributedString:htmlString];
                            } else {
                                [mutableString appendAttributedString:[[NSAttributedString alloc] initWithString: widgetString]];
                                NSLog(@"Error parsing HTML: %@", error.localizedDescription);
                            }
                        }
                    } @catch (NSException *exception) {
                        NSLog(@"Error fetching web page: %@", exception);
                        widgetString = @"Error loading page";
                    }
                }
            }
            break;
        default:
            // 不添加任何内容
            break;
    }
    if (widgetString && parsedID != 10) {
        widgetString = [widgetString stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
        widgetString = [widgetString stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
        [
            mutableString appendAttributedString:[[NSAttributedString alloc] initWithString: widgetString]
        ];
    }
}

/**
 * 格式化带有属性的字符串
 * @param identifiers 小组件标识符数组
 * @param fontSize 字体大小
 * @param textColor 文字颜色
 * @param apiKey API密钥
 * @param dateLocale 日期区域
 * @return 带有属性的字符串
 */
NSAttributedString* formattedAttributedString(NSArray *identifiers, double fontSize, UIColor *textColor, NSString *apiKey, NSString *dateLocale)
{
    @autoreleasepool {
        NSMutableAttributedString* mutableString = [[NSMutableAttributedString alloc] init];

        if (identifiers) {
            for (id idInfo in identifiers) {
                NSDictionary *parsedInfo = idInfo;
                NSInteger parsedID = [parsedInfo valueForKey:@"widgetID"] ? [[parsedInfo valueForKey:@"widgetID"] integerValue] : 0;
                formatParsedInfo(parsedInfo, parsedID, mutableString, fontSize, textColor, apiKey, dateLocale);
            }
        } else {
            return nil;
        }

        return [mutableString copy];
    }
}

