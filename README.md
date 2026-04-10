# TypeFree

A lightweight macOS menu bar application for voice-to-text transcription. Press Fn, speak, and your words are automatically transcribed and injected into any active text field.

## Features

- **Real-time Voice Transcription** — Press Fn key to start recording. See live transcription in a floating overlay panel.
- **Apple Speech Recognition** — Uses native macOS `SFSpeechRecognizer` for fast, on-device transcription.
- **Optional LLM Refinement** — Optionally refine transcriptions through an OpenAI-compatible API endpoint.
- **Smart Text Injection** — Automatically pastes transcribed text into the active text field.
- **CJK Input Method Support** — Detects and properly handles Chinese, Japanese, and Korean input methods.
- **Waveform Visualization** — 60fps animated waveform display during recording.
- **Menu Bar Integration** — Runs quietly in the macOS menu bar; minimize, customize, and control from the top menu.

## System Requirements

- **macOS 14.0+** (Sonoma or later)
- **Swift 5.9+**
- **Audio recording permissions** — First run will prompt for microphone access
- **Accessibility permissions** — Required for global Fn key detection and text field interaction

## Installation

### From Source

1. **Clone the repository:**
   ```bash
   git clone git@github.com:digging-airfare-4u/type-free.git
   cd type-free
   ```

2. **Build the application:**
   ```bash
   make build
   ```

3. **Install to Applications folder:**
   ```bash
   make install
   ```

4. **Launch TypeFree:**
   - Open **Applications** → **TypeFree**
   - Grant microphone and accessibility permissions when prompted
   - The app will appear in the menu bar

## Usage

1. **Start Recording:** Press the **Fn key** (Function key) on your keyboard
2. **Speak:** The waveform overlay will appear and display real-time transcription
3. **Stop Recording:** Release the **Fn key**
4. **Paste:** The transcribed text is automatically injected into the active text field

### Settings

- Click the TypeFree menu bar icon → **Settings**
- Configure LLM API endpoint (if using text refinement)
- Adjust transcription language and other preferences

## Development

### Build Commands

```bash
swift build -c release       # Build release binary
make build                   # Build and create .app bundle
make run                     # Build and launch immediately
make install                 # Copy .app to /Applications
make clean                   # Remove build artifacts
swift test                   # Run all tests
swift test --filter <TestClass/testMethod>  # Run specific test
```

### Project Structure

```
Sources/TypeFree/
├── main.swift                    # Entry point
├── AppDelegate.swift             # Main coordinator & status bar
├── AudioRecorder.swift           # Audio capture & speech recognition
├── FnKeyListener.swift           # Global Fn key detection
├── TextInjector.swift            # Text injection with CJK support
├── CapsuleOverlay.swift          # Floating overlay UI & waveform
├── SessionGate.swift             # Race condition prevention
├── TranscriptionLifecycle.swift  # Stop timing & fallback logic
├── LLMService.swift              # OpenAI API integration
└── LLMSettingsWindow.swift       # Settings UI

Tests/TypeFreeTests/
├── LLMServiceTests.swift
├── SessionGateTests.swift
└── TranscriptionLifecycleTests.swift
```

### Key Architecture Concepts

- **SessionGate** — Prevents race conditions by tracking session IDs. All UI updates and text injection are guarded.
- **TranscriptionLifecycle** — Manages stop timing with a 0.35s grace period for final transcript results.
- **CJK Input Handling** — Automatically switches to ASCII input method, injects text, then restores the original method.
- **LLM Language Awareness** — Uses specialized Chinese prompts for zh-Hans/zh-Hant; generic English for others.
- **Threading** — UI updates on main queue; audio and speech recognition on dedicated queues.

## Configuration

TypeFree stores settings in:
- **Preferences:** `~/Library/Preferences/com.typefree.TypeFree.plist`
- **LLM Settings:** Accessible via the menu bar Settings window

### LLM API Setup (Optional)

1. Open TypeFree → **Settings**
2. Enter your **OpenAI-compatible API endpoint** (e.g., `https://api.openai.com/v1/chat/completions`)
3. Provide your **API key**
4. Choose your **model** (e.g., `gpt-4`, `gpt-3.5-turbo`)

TypeFree will automatically refine transcriptions when LLM is configured.

## Troubleshooting

### Microphone Access Denied

- Open **System Settings** → **Privacy & Security** → **Microphone**
- Ensure TypeFree is in the allowed list

### Fn Key Not Detected

- Ensure TypeFree has **Accessibility** permissions
- Open **System Settings** → **Privacy & Security** → **Accessibility**
- Add TypeFree to the allowed list

### Text Not Injecting

- Verify the target application supports clipboard text injection
- Check that the text field is focused before pressing Fn
- Some applications may have security restrictions

## License

This project is provided as-is for personal use.

---

## 中文说明

### TypeFree

一个轻便的 macOS 菜单栏应用程序，用于语音转文字转录。按下 Fn 键，说话，你的话会自动转录并注入到任何活跃的文本字段。

### 功能

- **实时语音转录** — 按 Fn 键开始录音。在浮动的覆盖层面板中查看实时转录。
- **苹果语音识别** — 使用原生 macOS `SFSpeechRecognizer` 实现快速的本地转录。
- **可选 LLM 优化** — 可通过 OpenAI 兼容 API 端点优化转录结果。
- **智能文本注入** — 自动将转录的文本粘贴到活跃的文本字段。
- **CJK 输入法支持** — 检测并正确处理中文、日文和韩文输入法。
- **波形可视化** — 录音过程中 60fps 的动画波形显示。
- **菜单栏集成** — 在 macOS 菜单栏中静默运行；可从顶部菜单最小化、自定义和控制。

### 系统要求

- **macOS 14.0+**（Sonoma 或更新版本）
- **Swift 5.9+**
- **音频录制权限** — 首次运行时将提示请求麦克风访问权限
- **辅助功能权限** — 全局 Fn 键检测和文本字段交互所需

### 安装

#### 从源代码构建

1. **克隆仓库：**
   ```bash
   git clone git@github.com:digging-airfare-4u/type-free.git
   cd type-free
   ```

2. **构建应用程序：**
   ```bash
   make build
   ```

3. **安装到 Applications 文件夹：**
   ```bash
   make install
   ```

4. **启动 TypeFree：**
   - 打开 **应用程序** → **TypeFree**
   - 出现提示时授予麦克风和辅助功能权限
   - 应用将出现在菜单栏中

### 使用方法

1. **开始录音：** 按键盘上的 **Fn 键**（功能键）
2. **说话：** 波形覆盖层将出现并显示实时转录
3. **停止录音：** 释放 **Fn 键**
4. **粘贴：** 转录的文本会自动注入到活跃的文本字段

### 设置

- 点击 TypeFree 菜单栏图标 → **设置**
- 配置 LLM API 端点（如果使用文本优化）
- 调整转录语言和其他偏好设置

### 开发

#### 构建命令

```bash
swift build -c release       # 构建发布版本
make build                   # 构建并创建 .app 包
make run                     # 构建并立即启动
make install                 # 将 .app 复制到 /Applications
make clean                   # 移除构建工件
swift test                   # 运行所有测试
swift test --filter <TestClass/testMethod>  # 运行特定测试
```

### 项目结构

```
Sources/TypeFree/
├── main.swift                    # 入口点
├── AppDelegate.swift             # 主协调器和状态栏
├── AudioRecorder.swift           # 音频采集和语音识别
├── FnKeyListener.swift           # 全局 Fn 键检测
├── TextInjector.swift            # 带 CJK 支持的文本注入
├── CapsuleOverlay.swift          # 浮动覆盖 UI 和波形
├── SessionGate.swift             # 竞态条件预防
├── TranscriptionLifecycle.swift  # 停止时序和回退逻辑
├── LLMService.swift              # OpenAI API 集成
└── LLMSettingsWindow.swift       # 设置 UI

Tests/TypeFreeTests/
├── LLMServiceTests.swift
├── SessionGateTests.swift
└── TranscriptionLifecycleTests.swift
```

### 关键架构概念

- **SessionGate** — 通过跟踪会话 ID 防止竞态条件。所有 UI 更新和文本注入都被保护。
- **TranscriptionLifecycle** — 管理停止时序，在最终转录结果前有 0.35 秒的宽限期。
- **CJK 输入处理** — 自动切换到 ASCII 输入法，注入文本，然后恢复原始方法。
- **LLM 语言感知** — 对 zh-Hans/zh-Hant 使用专门的中文提示；对其他语言使用通用英文提示。
- **线程处理** — UI 更新在主线程；音频和语音识别在专用队列。

### 配置

TypeFree 在以下位置存储设置：
- **偏好设置：** `~/Library/Preferences/com.typefree.TypeFree.plist`
- **LLM 设置：** 可通过菜单栏设置窗口访问

#### LLM API 设置（可选）

1. 打开 TypeFree → **设置**
2. 输入你的 **OpenAI 兼容 API 端点**（例如 `https://api.openai.com/v1/chat/completions`）
3. 提供你的 **API 密钥**
4. 选择你的 **模型**（例如 `gpt-4`、`gpt-3.5-turbo`）

配置 LLM 后，TypeFree 将自动优化转录结果。

### 故障排除

#### 麦克风访问被拒绝

- 打开 **系统设置** → **隐私与安全** → **麦克风**
- 确保 TypeFree 在允许列表中

#### Fn 键未检测

- 确保 TypeFree 具有 **辅助功能** 权限
- 打开 **系统设置** → **隐私与安全** → **辅助功能**
- 将 TypeFree 添加到允许列表

#### 文本不注入

- 验证目标应用程序支持剪贴板文本注入
- 检查在按 Fn 之前文本字段是否获得焦点
- 某些应用程序可能有安全限制

### 许可

本项目按原样提供，仅供个人使用。
