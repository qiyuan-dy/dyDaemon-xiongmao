# dyDaemon 熊猫平台版

基于原 dyDaemon v1.4.9 逆向分析后重写的熊猫平台（xiongmao88.xyz）抖音自动化工具。

## ✅ 已去除

- ❌ 全部授权验证（mExpireTime、Token、RSA签名）
- ❌ 原有 15 个任务平台（银狐、小飞象、龙门、梦幻、龙珠...）
- ❌ 所有加密混淆（MJEncryptCStringTools 等）
- ❌ 远端控制服务器 (103.85.85.105)

## ✅ 保留核心

- ✅ 抖音自动化操作引擎（点赞/关注/收藏/分享/评论/播放）
- ✅ 悬浮窗控制面板
- ✅ 本地配置持久化
- ✅ 多线程任务调度
- ✅ 错误重试与限流

## ✅ 新增特性

- ✅ 对接熊猫平台 API v1.7
- ✅ 纯本地运行，无第三方服务器
- ✅ 代码完全开源可读，无后门
- ✅ 支持自定义任务间隔、并发数

---

## 文件结构

```
dyDaemon-xiongmao/
├── Makefile                # Theos 编译配置
├── control                 # deb 包信息
├── dyDaemon.plist          # 注入目标配置
├── Tweak.xm                # 主入口 + Logos Hook
├── XMGlobalManager.h/.m    # 全局状态管理
├── XMTaskService.h/.m      # 任务调度（对接熊猫API）
├── XMOperationEngine.h/.m  # 抖音操作引擎
└── XMFloatingView.h/.m     # 悬浮窗控制面板
```

---

## 编译方法

### 前置要求
- macOS + Xcode
- Theos 已安装（`$THEOS` 环境变量已设置）
- iOS SDK 12.0+

### 编译步骤

```bash
cd dyDaemon-xiongmao

# 编译
make clean && make package

# 安装到设备（需配置 THEOS_DEVICE_IP）
export THEOS_DEVICE_IP=手机IP
make install
```

### 生成的文件
编译成功后在 `packages/` 目录下生成 `.deb` 文件。

---

## 熊猫平台 API 对接说明

### 核心接口

| 接口 | 方法 | 用途 |
|------|------|------|
| `/apikey?account=&pwd=` | GET | 获取 API Key |
| `/studio/api/task/get` | GET | 获取任务 |
| `/studio/api/task/submit` | GET | 提交任务结果 |

### 获取任务参数
```
key=API_Key
platform=dy      # 平台类型
type=dz          # 业务类型: dz点赞 gz关注 sc收藏 fx分享 pl评论 bf播放
uid=抖音UID
sec_uid=抖音SecUID
filter=image     # 可选: image=图文 video=视频
cnt=50           # 可选: 播放/分享等任务的数量
```

### 提交任务参数
```
platform=dy
type=dz
studiotask_id=任务ID
key=API_Key
result=true      # 成功/失败
retry_delay=120  # 可选: 失败重试延迟(秒)
block=false      # 可选: 是否屏蔽
```

### CODE 码说明
| Code | 含义 |
|------|------|
| 0 | 成功 |
| 401 | 缺少 key |
| 402 | 参数无效 |
| 403 | 访问太频繁 |
| 404 | 不支持的任务类型 |
| 406 | 没有任务 |
| 407 | 无效 key |
| 408 | 无效订单号 |
| 409 | 订单已过期 |
| 501 | 系统错误 |
| 502 | 账户禁用 |
| 503 | 系统维护 |

---

## 抖音内部接口（操作层）

> 这些是抖音原生 API，工具运行在抖音进程内，自动携带登录态。

| 操作 | 接口路径 |
|------|----------|
| 点赞 | `/aweme/v1/commit/item/digg/` |
| 取消点赞 | 同上 + type=0 |
| 关注 | `/aweme/v1/commit/follow/user/` |
| 取消关注 | 同上 + type=0 |
| 收藏 | `/aweme/v1/aweme/collect/` |
| 取消收藏 | 同上 + collects_flag=0 |
| 播放统计 | `/aweme/v1/aweme/stats/` |
| 用户资料 | `/aweme/v1/user/profile/other/` |
| 关注列表 | `/aweme/v1/user/following/list/` |
| 收藏列表 | `/aweme/v1/aweme/favorite/` |

### 极速版对应接口
前缀从 `/aweme/v1/` 换成 `/sicily/v1/`

---

## 使用说明

1. **安装 deb** 到越狱手机
2. **打开抖音**，右侧出现 🐼 悬浮球
3. **点击悬浮球** 打开控制面板
4. **输入 API Key**（从熊猫平台获取）
5. **勾选需要的任务类型**（点赞/关注/收藏等）
6. **点击「开始任务」** 开始运行

---

## 注意事项

1. **签名问题**：抖音 API 需要 X-Gorgon / X-Khronos 签名。当前版本使用基础网络请求，实际部署时建议 Hook 抖音内部的 `TTNetworkManager` / `AWEApi` 来发请求，自动携带签名。
2. **账号安全**：请使用小号测试，频繁操作可能被风控。
3. **任务间隔**：建议设置合理间隔（最小5-10秒），避免操作过快。
4. **版本适配**：不同抖音版本类名可能有差异，如 Hook 失效请根据实际版本调整类名。

---

## 架构说明

### 三层架构 → 两层精简

原工具三层架构：
```
远端服务器(103.85.85.105) → dyDaemon守护进程 → dylib注入层
```

熊猫版两层架构：
```
熊猫平台API → dylib注入层（直接对接）
```

去掉了中间守护进程层，直接在注入的 dylib 里完成任务拉取和执行，架构更简单。

### 核心模块关系

```
XMFloatingView (UI悬浮窗)
        │
        ▼
XMGlobalManager (状态/配置中心)
        │
        ├─→ XMTaskService (任务调度 → 熊猫API)
        │
        └─→ XMOperationEngine (操作执行 → 抖音API)
```
