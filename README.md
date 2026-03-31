# VoiceKeys - iOS 语音输入键盘

自定义 iOS 键盘扩展，说中文 → 自动润色/翻译 → 插入文字。支持中文润色、英语翻译、西班牙语翻译。

## 功能

- **无感录音**：在键盘内直接录音，不需要切换 App（主 App 在后台处理）
- **中文润色**：去掉口头禅、重复内容，加标点，修错别字
- **英语翻译**：说中文 → 输出地道英语
- **西班牙语翻译**：说中文 → 输出地道西班牙语
- **隐私优先**：语音识别由 Apple 本地处理，录音不保存
- **5 分钟自动关闭**：麦克风空闲 5 分钟自动关闭，省电

## 技术架构

```
键盘扩展（VoiceKeysKeyboard）
  ↕ App Group (UserDefaults + 文件 + Darwin 通知)
主 App（VoiceKeys）
  → AVAudioEngine 保持后台麦克风活跃
  → SFSpeechRecognizer 语音识别
  → Moonshot API 润色/翻译
```

**关键技术**：主 App 用 `AVAudioEngine` 的 inputNode idle tap 保持麦克风活跃，iOS 不会挂起正在使用麦克风的 App。键盘扩展通过 App Group 发送指令，主 App 在后台完成录音、识别、润色。

## 安装

### 前置条件
- Xcode 16+
- iOS 17+ 设备
- Apple Developer 账号（免费即可）
- [xcodegen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）

### 步骤

1. Clone 仓库
```bash
git clone https://github.com/2025kaskas-sys/VoiceKeys.git
cd VoiceKeys
```

2. 生成 Xcode 项目
```bash
xcodegen generate
```

3. 打开项目
```bash
open VoiceKeys.xcodeproj
```

4. 配置签名
- 选择 VoiceKeys target → Signing & Capabilities → 选你的 Team
- 选择 VoiceKeysKeyboard target → 同样选 Team
- 确保两个 target 都有 App Group: `group.com.domingo.voicekeys`

5. 运行到 iPhone（Cmd+R）

6. iPhone 上设置
- 设置 → 通用 → 键盘 → 键盘 → 添加新键盘 → VoiceKeys
- 点击 VoiceKeys → 开启「允许完全访问」

## 使用方法

1. **首次使用**：在键盘中点麦克风 → 自动跳到主 App 启动服务 → 手动返回
2. **之后每次**：点麦克风 → 直接录音（不跳转）→ 点完成 → 文字自动插入
3. **切换语言**：键盘上点国旗图标切换（🇨🇳润色 / 🇺🇸英语 / 🇪🇸西班牙语）

## API 配置

默认使用 Moonshot API（`moonshot-v1-8k` 模型）。API key 内置在代码中，如需更换：

编辑 `Shared/SharedDefaults.swift`：
```swift
static let defaultAPIKey = "你的API Key"
```

编辑 `Shared/Services/PolishingService.swift`：
```swift
// 更换 API 端点和模型
var request = URLRequest(url: URL(string: "https://api.moonshot.ai/v1/chat/completions")!)
"model": "moonshot-v1-8k"
```

兼容所有 OpenAI 格式的 API（DeepSeek、Claude 等），只需改端点和模型名。

## 项目结构

```
VoiceKeys/
├── Shared/                          # 键盘和主 App 共享代码
│   ├── Constants.swift              # App Group ID、URL scheme
│   ├── SharedDefaults.swift         # 跨进程通信（UserDefaults + 文件 + 心跳）
│   ├── Services/PolishingService.swift  # Moonshot API 润色/翻译
│   └── Theme/DarkTheme.swift        # 深色主题
├── VoiceKeysApp/                    # 主 App
│   ├── VoiceKeysApp.swift           # 入口，URL scheme 处理
│   ├── Audio/BackgroundRecordingService.swift  # 核心：后台录音+识别+润色
│   └── Views/ContentView.swift      # 主界面
├── VoiceKeysKeyboard/               # 键盘扩展
│   ├── KeyboardViewController.swift # 键盘控制器，IPC 通信
│   └── Views/KeyboardView.swift     # 键盘 UI
├── Resources/                       # 图标等资源
└── project.yml                      # xcodegen 配置
```

## License

MIT
