# AI Music Studio

一款强大的Mac原生AI音乐创作工具，支持AI写歌、声音克隆和AI翻唱功能。

## 功能特点

- **AI写歌** - 基于文本描述生成独特音乐
- **声音录入** - 录制并训练专属声音模型
- **AI翻唱** - 使用克隆声音进行翻唱
- **音乐库** - 管理所有生成的音乐
- **MP3导出** - 导出高质量音频文件

## 系统要求

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## 安装

1. 克隆仓库
```bash
git clone <repository-url>
cd AI-Music-Studio
```

2. 打开 Xcode 项目
```bash
open AI-Music-Studio.xcodeproj
```

3. 构建并运行

## API配置

### Replicate (推荐)

1. 访问 [Replicate](https://replicate.com) 注册账号
2. 获取 API Key
3. 在应用的「设置」中配置 API Key

### HuggingFace (备用)

1. 访问 [HuggingFace](https://huggingface.co) 注册账号
2. 获取 API Token
3. 在应用的「设置」中配置

### 本地部署 (高级)

需要本地部署 MusicGen 和 RVC 服务:

```bash
# MusicGen
pip install audiocraft
python -m audiocraft.server --port 8000

# RVC (需要额外配置)
# 参考 RVC-WebUI 项目
```

## 项目结构

```
AI-Music-Studio/
├── App/                    # 应用入口
├── Views/                  # SwiftUI 视图
├── ViewModels/             # 视图模型
├── Services/               # 服务层
│   ├── Audio/             # 音频处理
│   └── AI/                # AI 服务
├── Models/                 # 数据模型
├── Utils/                  # 工具类
└── Resources/              # 资源文件
```

## 使用的AI模型

| 功能 | 模型 | 来源 |
|------|------|------|
| 音乐生成 | MusicGen | Meta AI |
| 声音克隆 | RVC | 开源社区 |

## 技术栈

- **UI框架**: SwiftUI
- **音频处理**: AVFoundation
- **网络请求**: URLSession + Combine
- **密钥存储**: KeychainAccess

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request!

## 致谢

- [MusicGen](https://github.com/facebookresearch/audiocraft) - Meta AI
- [RVC-Project](https://github.com/RVC-Project) - 开源社区
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) - 密钥存储库
