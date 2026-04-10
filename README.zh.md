# TypeFree

一个轻便的 macOS 菜单栏应用程序，用于语音转文字转录。按下 Fn 键，说话，你的话会自动转录并注入到任何活跃的文本字段。

[English](README.md)

## 功能

- **实时语音转录** — 按 Fn 键开始录音。在浮动的覆盖层面板中查看实时转录。
- **苹果语音识别** — 使用原生 macOS `SFSpeechRecognizer` 实现快速的本地转录。
- **可选 LLM 优化** — 可通过 OpenAI 兼容 API 端点优化转录结果。
- **智能文本注入** — 自动将转录的文本粘贴到活跃的文本字段。
- **CJK 输入法支持** — 检测并正确处理中文、日文和韩文输入法。
- **波形可视化** — 录音过程中 60fps 的动画波形显示。
- **菜单栏集成** — 在 macOS 菜单栏中静默运行；可从顶部菜单最小化、自定义和控制。

## 系统要求

- **macOS 14.0+**（Sonoma 或更新版本）
- **Swift 5.9+**
- **音频录制权限** — 首次运行时将提示请求麦克风访问权限
- **辅助功能权限** — 全局 Fn 键检测和文本字段交互所需

## 安装

### 从源代码构建

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

## 使用方法

1. **开始录音：** 按键盘上的 **Fn 键**（功能键）
2. **说话：** 波形覆盖层将出现并显示实时转录
3. **停止录音：** 释放 **Fn 键**
4. **粘贴：** 转录的文本会自动注入到活跃的文本字段

## 设置

- 点击 TypeFree 菜单栏图标 → **设置**
- 配置 LLM API 端点（如果使用文本优化）
- 调整转录语言和其他偏好设置

## 开发

### 构建命令

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

## 配置

TypeFree 在以下位置存储设置：
- **偏好设置：** `~/Library/Preferences/com.typefree.TypeFree.plist`
- **LLM 设置：** 可通过菜单栏设置窗口访问

### LLM API 设置（可选）

1. 打开 TypeFree → **设置**
2. 输入你的 **OpenAI 兼容 API 端点**（例如 `https://api.openai.com/v1/chat/completions`）
3. 提供你的 **API 密钥**
4. 选择你的 **模型**（例如 `gpt-4`、`gpt-3.5-turbo`）

配置 LLM 后，TypeFree 将自动优化转录结果。

## 故障排除

### 麦克风访问被拒绝

- 打开 **系统设置** → **隐私与安全** → **麦克风**
- 确保 TypeFree 在允许列表中

### Fn 键未检测

- 确保 TypeFree 具有 **辅助功能** 权限
- 打开 **系统设置** → **隐私与安全** → **辅助功能**
- 将 TypeFree 添加到允许列表

### 文本不注入

- 验证目标应用程序支持剪贴板文本注入
- 检查在按 Fn 之前文本字段是否获得焦点
- 某些应用程序可能有安全限制

## 许可

本项目按原样提供，仅供个人使用。
