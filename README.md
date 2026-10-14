# UniCal —— 日历 + 课程表 + 日程 三合一（四端）

一套 Dart 代码，覆盖 **Android / iOS / HarmonyOS / Windows**。

## 为什么是 Flutter / Dart

| 约束 | 结论 |
|---|---|
| 鸿蒙 NEXT 已移除 AOSP，应用层只支持 ArkTS（+ C/C++ NDK） | Java / Kotlin 无法直接写鸿蒙，出局 |
| ArkUI-X 官方只覆盖 HarmonyOS / Android / iOS，Windows 仍在规划中 | 缺 Windows，出局 |
| KMP + CMP 在鸿蒙端只能共享逻辑，UI 仍需 ArkUI 重写；Windows 走 JVM | 两套 UI + JVM 内存开销，不满足"低占用" |
| **Flutter + OpenHarmony SIG 适配** | ✅ 四端一套 UI + 逻辑，Dart AOT，无 VM / 无 Bridge |

鸿蒙侧 SDK：`https://atomgit.com/OpenHarmony-flutter`（三方库已迁至 `https://atomgit.com/CPF-Flutter`，141 个）。
可用基线版本：**Flutter 3.7 / 3.22 / 3.27 / 3.35 / 3.41**。

## 目录结构

```
lib/
├── main.dart                   # 应用外壳：今日 / 课表 / 日历 三个入口
└── src/
    ├── domain/                 # 统一领域模型（纯 Dart，零依赖）
    │   ├── term.dart           #   学期 + 作息时间表（周次锚点）
    │   ├── course.dart         #   课程 + 单双周/周次范围规则
    │   ├── event.dart          #   日程 + RRULE 最小子集 + 例外日
    │   ├── todo.dart           #   待办 + 分类 + 优先级
    │   ├── occurrence.dart     #   ★ 三源统一后的时间轴条目
    │   └── date_util.dart      #   日期归一化 / 分钟换算
    ├── engine/                 # 三个展开引擎 + 合并器
    │   ├── week_resolver.dart  #   日期 → 教学周
    │   └── agenda_merger.dart  #   ★ 课程/日程/待办 → Occurrence，排序 + 冲突检测
    └── data/
        └── repository.dart     # 数据层契约 + 内存演示实现
```

## 整合的关键：`Occurrence`

课程、日程、待办是三种**异构**数据（前者按"教学周 + 星期 + 节次"排布，后两者按绝对时间），
直接做三个页面会导致三套数据、三套排序、三套冲突逻辑。

本设计让三者各自展开为同一种 `Occurrence`（某天某时段的一条条目），
上层三种视图只消费这一种类型：

```
Course  ─┐
Event   ─┼─► 展开器 ─► List<Occurrence> ─► 今日时间轴 / 周课表网格 / 月日历密度
Todo    ─┘                                （同一份结果，三种呈现）
```

排序规则：全天在前 → 按开始时间 → 课程 > 日程 > 待办。
待办 `duration = 0`，天然不参与撞课检测。

## 运行

```bash
# 先用官方 Flutter 创建各平台目录（骨架只放了 lib/）
flutter create --platforms=android,ios,windows .
flutter pub get
flutter run -d windows          # Windows
flutter run -d android          # Android
flutter run -d "iPhone 15"      # iOS（需 macOS + Xcode）
```

鸿蒙端：把 `ohos/` 目录用 DevEco Studio 打开后构建，或使用 ohos 版 flutter：

```bash
# 使用 OpenHarmony SIG 的 flutter_flutter
flutter create --platforms=ohos .
flutter build hap --release
```

> 注意：ohos 版 flutter 与官方 flutter 是两个 SDK，需通过 `fvm` 或 PATH 切换，不要混用。

## 低占用做法

- Release 为 Dart **AOT** 编译，运行时无 VM、无 JS Bridge、无 JVM
- 惰性展开：只计算被请求的某天/某周，不做全年实例实例化
- 依赖极简：骨架阶段零三方依赖，P3 阶段只加 `sqflite` / `path_provider`
- 提醒交给系统调度（AlarmManager / 系统通知），App 不常驻后台

## 后续（P2–P5）

- [ ] 教务导入（JS 脚本解析，参考 拾光 / Dawn-Course 的适配仓库）
- [ ] ICS 导入导出、JSON 备份、WebDAV 同步
- [ ] 系统通知提醒、节假日免打扰、桌面小组件
- [ ] 农历 / 节气（可移植 DDCalendar 的寿星万年历算法）
- [ ] 每个引擎补单元测试：`flutter test`
