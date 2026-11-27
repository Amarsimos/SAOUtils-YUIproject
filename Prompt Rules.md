# MHCP-YUI / Seedling 提示词规则

> 记录发给模型的每一段文字：在哪个场景、由哪段代码生成、放在请求的什么位置，以及写提示词、写挂件代码时要遵守的规范。
> 代码位置：结衣 `com.amarsimos.widget.yui/qml/main-stand.qml`（拼装、读数据）、`qml/yui.js`（纯函数，有测试）；Seedling `com.amarsimos.widget.seedling/qml/writer.js`（写代码的提示）、`link/Bench.qml`（写代码的流程、重试说明）、`safety.js`（安全检查）、`props.js`（声明）。
> 最后核对：2026-11-27（feature/prompts，第十节各条改完之后）。
> **状态：已审核并按第十节改完代码（2026-11-27，feature/prompts）。**

---

## 〇、场景总表

| 场景 | 发给谁 | system | 用户消息 / 附注 | 详见 |
| :-- | :-- | :-- | :-- | :-- |
| 聊天（Tags 模式，默认） | 结衣的连接 | ① 规则 + ② 人格 + ③ 附加部分 | 聊天历史 + 最新消息 + 附注 | 一～四 |
| 聊天（Tools 模式） | 同上 | 同上，代行说明换成一句「可以用提供的工具」 | 同上 + tools 定义 | 六 |
| 重新生成（Say Again） | 同上 | 同上 | 最新消息后加「重新生成」附注，温度 +0.3 | 三 |
| 小模型（Authority Level = Limited） | 同上 | 同上，代行全部关闭 | 最新消息后加「小模型提醒」 | 三 |
| 开机问候（无保存的对话时） | 同上 | 同上 | 一条用户消息：「（系统提示：刚刚打开电脑……打招呼）」 | 五 |
| Login Greeting / 唤醒 | 同上 | 同上 | 早安 / 欢迎回来 / 好久不见 三种之一 | 五 |
| 主动开口：闲聊、心情关怀、天气变化、深夜、休息、跟进 | 同上 | 同上 | `yuiSpeaks`：附在最新消息后，或作为新的一条 | 五 |
| 周报（Weekly Report） | 同上 | 同上 | 一条用户消息：一周数据 + 写法要求；不进聊天 | 五 |
| Through Yui's Eyes（画像） | 同上 | 同上 | 一条用户消息：全部记忆 + 写法要求；不进聊天 | 五 |
| 结衣的 Link Start! 测试 | 正在编辑的连接 | 编辑中的人格 + 附加部分 | 「你好」 | 五 |
| Seedling 写新挂件 | 有结衣且她配好了：结衣的连接；否则 Seedling 自己的 | 写代码规则（14 条，有结衣时 15 条）+ 外观 + 同类模板参考 | 「要做的挂件：……」 | 九 |
| Seedling 修改挂件 | 同上 | 同上 + SEARCH/REPLACE 修改方式（不带模板） | 「现在的代码 + 要修改的地方」 | 九 |
| Seedling 出错重试（最多 2 次 + 整段兜底 1 次） | 同上 | 同上 | 上一次的说明 + 出错原因 | 9.4 |
| Seedling 的 Link Start! 测试 | Seedling 选中的连接 | 「用一句话回复。」 | 「你好」 | 九 |
| 本地台词（System Call、Seedling 进度和结果、唤醒语、Navigation Report 等） | 不单独发；进聊天历史 | — | 前面标「（系统生成）」进入以后的请求 | 四 |

---

## 一、一次请求的组成

```
system ┬ ① 最重要的规则        priorityRules
       ├ ② 人格               设置里的 System Prompt（默认 defaultSystemPrompt / MHCP Profile）
       └ ③ 附加部分            systemExtras（见第二节，共 8 段）
messages ┬ 聊天历史            buildHistory（最近 maxHistory 条，默认 20）
         └ 最新一条用户消息     ＋ 只进请求的附注（见第三节）
tools                         只在 Tools 模式（toolDefinitions）
```

拼装在 `startReply → requestCompletion`（main-stand.qml 约 1097 行）：
`system = priorityRules + 人格（{{user_title}} 替换为称呼）+ systemExtras(title, 最新用户消息, mode)`。

**称呼 `title`**：设置里的称呼（默认「爸爸」），所有段落都用它，不写死。

---

## 二、system 提示的各段（按顺序）

| # | 段落 | 生成 | 什么时候出现 | 内容要点 |
| :-- | :-- | :-- | :-- | :-- |
| ① | 最重要的规则 | `Yui.priorityRules(title, allowed, mode)` | 每次（周报、画像这类只要文字的请求不带，③-1 也不带） | 表情标签必写；操作电脑 / 记忆必须写标签或调用工具（只说不做电脑上什么都不会发生）；开着网页功能时「实时信息必须搜索，不编造」；最后一条始终在：「电脑上的事，结衣只能……（只列开着的，含控制音乐播放）；其他事做不到就直接说，请{title}自己操作，绝不假装已经做了」（都关掉时为「结衣不能操作电脑」）。放在人格**前面**，因为用户可能改人格，小模型也容易丢后面的规则 |
| ② | 人格 | 设置 `system_prompt`；默认 `defaultSystemPrompt`（main-stand.qml 约 314 行，普通文字）；为空时也用默认人格；MHCP Profile 切换；`{{user_title}}` 由 `Yui.withTitle` 换成称呼 | 每次 | 身份、性格、说话方式。用户可编辑 |
| ③-1 | 系统功能说明 | `Yui.featureInstructions(title, 心核, allowed, mode)` | 每次 | 开头「以下是系统功能说明，不要向{title}提起」。表情、结衣之心（core / memory / forget 标签与记忆规则）、心理关怀、导航（web）、桌面代行（launch / find / kill）、音乐（Control Media）、快捷回复、小工具（隐藏时不出现）；最后附**心核**（`[MM-dd] 内容`）。只写开着的功能；Tools 模式去掉导航 / 代行 / 音乐的标签说明，改成一句「你可以用提供的工具……」 |
| ③-2 | 羁绊 | `Yui.bondFacts` | 设了生日 / 相遇日时 | 两个日子作为事实，「被问到时以此为准」（当天的祝贺移到「此刻」） |
| ③-3 | 相关回忆 | `Yui.recallContext(title, recall(query))` | 有相关记忆碎片时 | 结衣之心里和最新消息相关的碎片（`[MM-dd] 内容`），数量由 Yui's Heart → Recall 设定 |
| ③-4 | 笔记 | `notesExtras` | 小工具开着且消息提到笔记 / 待办（现在隐藏，不出现） | 未完成的 Quest Log |
| ③-5 | 说话风格微调 | `Yui.traitContext` | Character Traits 有不是默认的项时 | 一句话列出偏离默认的几项 |
| ③-6 | 回忆日志 | `logRecallExtras` → `Yui.logRecallContext` | Log Recall > 0 且找到相关旧对话 | 最多 N 条旧聊天（排除仍在上下文里的），每条 ≤ 100 字，「只作参考」 |
| ③-7 | **此刻** | `nowExtras` → `Yui.nowBlock` | 每次，**放在最后** | 一行事实，只写有值的项，用｜隔开：日期 星期 时刻 时段｜结衣醒着陪{title} N（≥ 30 分钟，从醒来 / 启动算起；SAO Utils 没有电脑空闲时间）｜距上次聊天 N（≥ 6 小时；回答用户消息时取这条消息之前的那次）｜天气（每次，原来只在提到天气时）｜正在播放 / 播放器里是 歌手《曲名》（播放器）｜电脑负载偏高 / 很高（正常不写）｜今天心情 n/5 概括｜今天是生日 / 相遇 N 周年 |
| ③-8 | 此刻的说明 | `Yui.nowGuidance(asks)` | 每次，紧跟「此刻」 | 「以上是程序刚刚读到的，以此为准，以前说过的不同的话已经不对了；和话题无关的不用提起」，再接当下要她做的事：深夜关心；心情（`Yui.moodAsks`：今天还没问→自然时问一句并用 `<<mood:分数|概括>>` 记；已记→明显变化可更新；最近 3 天平均 ≤ 2→多关心、不说教）；Bond 当天第一次→真诚地祝贺（回复后记为已祝贺） |

**顺序原则**：不常变的在前（规则、人格、功能说明、心核、羁绊），随请求变化的在后；实时信息集中成「此刻」放**最后**（2026-11-26 起，原来的时间、心情、羁绊当天、天气、正在播放各段合并进来）。

---

## 三、只进请求、不显示也不保存的附注

都加在**最新一条用户消息**后面（`messages` 的副本，聊天窗口和数据库里看不到）。小模型对紧挨着问题的内容最敏感。

| 附注 | 生成 | 条件 | 内容 |
| :-- | :-- | :-- | :-- |
| 重新生成 | requestCompletion 内（`regenerate`） | 点 Say Again | 「换一种说法和角度…但事实（歌名、时间、记住的事）不要改」；温度 +0.3（≤ 2） |
| 小模型提醒 | `Yui.smallModelReminder(mode, allowed)` | Authority Level = Limited（默认；原 Small Model Mode，设置键 `small_model`，未设置即 Limited） | 「回复最后加上表情标签；需要操作电脑或记忆时写对应的标签」。**不写出标签本身**（有重复惩罚时，前面刚出现过的标签会被模型拼错，如 `<<emphy:happy>>`） |
| 换歌提示 | `Yui.mediaChangeNote(info)` | 曲目与上次请求不同（含重载后第一次），或点 Say Again | 「播放器里现在的歌是 …，之前提到的歌如果不是这首，说明已经换歌了」 |
| 主动开口的指令 | `yuiSpeaks(instruction)` | 结衣主动说话时 | 见第五节；没有用户消息时作为一条新的 user 消息 |
| 跟进 | `Yui.followupNote(due, title)`（`sendMessage`） | Follow-ups 打开、08:00–22:00、有到期的跟进（当天未打气，或之后 7 天内未问过）；附上即算已说 | 「结衣记得：爸爸之前说过「11月28日考试」（就是今天 / 那是昨天的事）。合适的话可以顺口关心、打气 / 问问怎么样了，和这次的话题不搭就不提」 |

---

## 四、聊天历史（`buildHistory`）

* 从 `historyStart` 起的聊天记录，取最近 `maxHistory` 条（Yui's Heart → Context，默认 20）。
* 跳过：还在生成的消息、`isError` 的消息（请求失败、设置提示）。
* **保留** `local` 消息（唤醒语、Navigation Report、System Call 的回复、Seedling 的进度和结果、测试消息等程序自己写的），让后面的回复能接上。进请求时在这类消息前标「（系统生成）」（`Yui.historyContent`），让模型知道那不是它自己说的；回复里照抄了这个标记会被 `cleanReply` 去掉。
* 连续同一角色的消息合并（Gemini / Claude 要求一问一答交替）；开头必须是 user。
* Clear Log（Yui's Heart）会同时清空聊天窗口，否则旧对话仍会进上下文。

---

## 五、独立的请求（不走聊天上下文）

| 请求 | 生成 | 要点 |
| :-- | :-- | :-- |
| 开机问候 | `getInitialMessage`（main-stand.qml 约 1751 行） | 启动时没有保存的对话：「（系统提示：{t}刚刚打开电脑……打招呼，不要提起这条提示）」 |
| Login Greeting | `welcomeBack` | 启动时，以及点醒待机的结衣时（2026-11-26 起，代替本地唤醒语；不需要问候时仍用本地唤醒语）。早安（带天气）/ 欢迎回来（≥ 30 分钟）/ 好久不见（≥ 2 天，原 3 天）三种；「一两句话即可，不要提起这条提示」 |
| Spontaneous Talk | `careTick` → `idleChat` | 告诉她现在的样子（水晶 / 妖精 / 立绘）和位置（只作背景，叫她不要说起自己的样子或位置），请她主动说一句；有由头时加「可以从这个由头说起：…」（`Yui.chatHooks` 20 种：节日、去年今天、快到的跟进 / 生日、正在听的歌、深夜听歌、电脑一直很忙、周五晚上、周末早上、周一早上、午饭、晚饭、月末、下雨下雪、冷、热、陪了很久、心情不错、一条较早的记忆、今天还没说过话；特别的日子优先，其余随机，同一个由头当天只用一次） |
| Mood Care | `careTick` → `Yui.moodCareInstruction` | 中优先级，09–22 点；最近 3 次心情平均 ≤ 2 且最近一次在 3 天内；带这几天的记录，「温柔地问问要不要说说，不要说教，也不要列一串建议」 |
| Weather Changes | `careTick` → `Yui.weatherChangeInstruction` | 中优先级，07–22 点，变化后 1 小时内；开始下雨 / 下雪（带之前和现在的天气）→ 提醒带伞；3 小时内降温 ≥ 5° → 提醒保暖 |
| 深夜关怀 / 休息提醒 | `careTick` | 带具体时刻或连续使用时长 |
| Weekly Report | `Yui.weeklyReportPrompt` | 一周数据 + 要求（三到五段、不用 Markdown、重点关心心情、不逐条复述数字、不加标签）；不进聊天 |
| 跟进 | `careTick` → `Yui.followupInstruction` | 高优先级；当天「主动打打气、关心一下」，之后 7 天内「自然地问问结果怎么样」；带原话和「就是今天 / 那是 N 天前的事」；一两句话，不要提起提示 |
| Through Yui's Eyes | `Yui.portraitPrompt` | 全部记忆 + 要求（两到四段、只根据记忆、不加标签）；不进聊天 |

| Link Start!（Cardinal System） | CardinalSystem.qml 约 530 行 | 用正在编辑的设置发「你好」测试连接；带完整的 system |

前四种经 `yuiSpeaks` 发出，仍带完整的 system 提示和聊天历史。后三种由关心调度（`careTick`，2026-11-25）决定何时说：每天上限与最短间隔随 Care Level / 学到的欢迎度变化（默认每天 20 次、每 30 分钟一次），免打扰时段不闲聊；Login Greeting 启动时立即说并计入次数。提示词内容本身没有变。

---

## 六、Tags 与 Tools 两种模式

| | Tags（默认） | Tools（Action Mode，OpenAI 格式且服务器接受 tools 时） |
| :-- | :-- | :-- |
| 代行（网页、启动、找文件、关闭、音乐） | 标签 `<<open:>> <<search:>> <<launch:>> <<find:>> <<kill:>> <<media:>>` | 工具 `open_url web_search launch_program find_file close_program media_control`（`Yui.TOOLS`） |
| 记忆 | 标签 `<<core:>> <<memory:>> <<forget:>>` | 两种模式都用标签（remember / forget 工具已删掉：测试里没有模型调用过） |
| 表情、心情、快捷回复 | 标签 | 标签 |
| 服务器拒绝 tools | — | 自动退回 Tags 并记住（`toolsRejected`） |

---

## 七、回复的处理（`Yui.parseReply` / `cleanReply`）

* **标签**：`emotion memory core forget open search launch find kill focus mood remind note done skill suggest media`。允许单个 `>` 收尾（小模型），其后只能是空白、行尾或下一个标签。
* 关掉的功能：标签被丢弃且不执行，聊天显示「🚫 已在 System Console 中关闭这类代行，没有执行」。
* 拼错 / 全角括号的标签：从文字中去掉，记进 Log（`tags not understood`）。
* `cleanReply`：只保留最后一个 `</think>` 之后的内容，去掉 `<think>…</think>`，同一段落只留一次。
* **只说不做**：回复声称做了（`Yui.claimsDone`：「已经 / 这就 / 帮你 + 动作动词 + 了 / 好了」、「音乐已经重新动起来」，问句和说用户做的不算），但这一轮没有执行任何动作、媒体、剑技、专注、提醒，也没有被关闭或拦截时，消息下加「⚠ 结衣说做了，但这次什么都没有执行」，Log 记 `claimed an action, none carried out`。不改她的原话。
* **快捷回复只聊天**：说明里要求不要替用户想请结衣操作电脑、设提醒的回复；`suggestionsFrom` 再在本地去掉这类选项（`SUGGESTED_ACTION`：帮我打开…、下一首、音量、闹钟、提醒我等）。
* **答应以后提醒**：Alarm 没开时，回复里承诺「到时候 / 明天 / 一定 / 会 … 叫 / 提醒 / 喊 … 爸爸」（`Yui.promisesReminder`，问句和「不能提醒」不算），消息下加「⚠ 结衣现在没有提醒功能，到时候不会提醒你」，Log 记 `promised a reminder, none set`。规则 ① 最后一条在 Alarm 没开时加上「也不要答应以后提醒、叫醒{title}」。
* 记忆保存前 `Yui.datedMemory`：「今天 / 明天…」换成具体日期，只有日期或时间的丢弃。

---

---

## 八、写提示词的通用规范

适用于结衣和 Seedling 发给模型的所有文字。原第八节的 0–9 条保留并入下面各条。

**内容**
1. **关掉的功能不出现**：功能说明跟着 `allowed` 和设置开关走；Authority Level = Limited 时只剩陪伴（表情、记忆、心情、快捷回复、感知）。
2. **一条规则只写一处**：① 规则只写「必须做的」；功能说明写「怎么做」（标签格式）；工具定义只写参数。表情、记忆、关闭程序、跟进、深夜关怀不再在多处重复。
3. **能本地做的不交给模型**：关键词判断、日期换算、标签容错都在 `yui.js` 本地做。规则越少越可靠，加一段说明前先想能不能本地处理，或只在相关时附上。
4. **实时信息放最后**，必要时附在最新消息后（小模型更看重紧挨着问题的内容）。
5. **按请求类型决定要不要标签**：周报、画像这类「只要文字」的请求不加表情规则，也不加小模型提醒；不再出现「必须加标签」和「不要加标签」同时成立。
6. **要求变化时写明什么不能变**（重新生成：换说法，事实不变）。
7. **不在给小模型的提醒里写出标签原文**（重复惩罚会让它拼错）。

**措辞与格式**
8. **语言**：发给模型的文字一律中文。功能名统一写成「中文名（English）」，首次出现时这样写，之后只用中文名。英文的报错（编译错误、安全检查）发给模型时前面加一句中文说明。测试连接也用中文。
9. **称呼**：只有一种写法——在模板文字里写 `{t}`，由一个函数换成称呼；爸爸 / 妈妈的对应只在一处（`userTitle`）。不写「他 / 她」，一律写称呼。人格设定里的 `{{user_title}}` 是给用户编辑用的，保留，由同一个函数处理。
10. **系统说明的外形**：只进请求、不显示的说明一律写成「（系统提示：……）」；放在 system 里的事实块写成「（羁绊：……）」「（此刻：……）」这类「（名字：内容）」。不再混用「系统信息」「提醒」或不加括号。
11. **主动开口的指令**结尾一律加「不要提起这条提示」（开机问候、深夜、休息目前缺）。
12. **人格设定用普通文字**，不用 Markdown 标题和列表符号（和「不用 Markdown」的要求一致）；用户自己写的人格不动。人格为空时用默认人格（MHCP001），不再用「你是ai助手」。

**代码**
13. 提示词文字只写在 `yui.js`（结衣）和 `writer.js`（Seedling）里，QML 只负责拼装和取数据。
14. 纯函数要有测试（`tests/test_yui.js`、`tests/test_seedling_writer.js`），至少覆盖：开关关闭时不出现、关键字段在文本里、互相矛盾的规则不同时出现。
15. 本文档和代码一起改；提示词原文不手抄：改完提示词跑 `node tests/prompt_doc.js`，重新生成文末的附录。

**排查**
16. System Console → Log 打开 **Log Requests**，看完整的 system 和消息；先确认信息有没有进请求，再判断是模型没用上还是没发出去。Seedling 的请求和结果在 SAO Utils 日志里以 `Seedling:` 开头。

---

## 九、Seedling：生成挂件

### 9.1 一次写代码请求的组成

```
system ┬ 角色           「你是一个只写 QML 的程序……」（新写 / 修改两种）
       ├ 规则 1–14      和安全检查一一对应（writer.js codePrompt）
       ├ 规则 15        只在有结衣时：@yui 可读的数据
       ├ 外观           Widget Style（Seedling Settings，默认 SAO 风格）
       ├ 模板参考        只在新写、且请求能匹配到模板时（templates.js）
       └ 修改方式        只在修改时：SEARCH/REPLACE 格式
user   ┬ 现在的代码      只在修改时
       ├ 要做的挂件 / 要修改的地方
       └ 出错原因        只在重试时
```
写代码的请求**不带**人格、聊天历史、网页内容（防提示注入）；只有规则、外观、模板、用户的要求、现有代码和程序自己生成的错误说明。

### 9.2 安全规范（挂件代码一律当作不可信）

| 层 | 做什么 | 在哪里 |
| :-- | :-- | :-- |
| 沙箱 | 代码在一个没有上下文的空对象里创建，看不到工作台、结衣、SAO Utils 的名字 | `sandbox.js`、`Sandbox.qml` |
| 安全检查 | 按词法读代码，只放行挂件需要的东西；工作台渲染前、挂件启动时各查一次 | `safety.js` |
| 联网开关 | 每个挂件单独的 Network，默认关；只因联网被拒时问用户 | Seedling Settings |
| 声明只是数据 | @setting / @keep / @yui 的值由 Seedling 在沙箱外按类型转换后赋给属性，不执行任何东西 | `props.js` |
| 结衣的数据不出门 | 读了 @yui 的挂件在任何情况下都不能联网（拒绝，不询问） | `props.js guard` |
| 请求不带外部内容 | 写代码的请求只有规则、要求、代码、本地生成的错误 | `writer.js` |
| 兜底 | 挂件让 SAO Utils 异常退出时，SAO Utils 下次启动会提示停用插件 | SAO Utils |

**安全检查放行 / 拒绝的范围**（规则 1–9 的依据）：
- import 只能是：QtQuick 2.12、QtQuick.Controls 2.12、QtQuick.Layouts 1.12、QtQuick.Shapes 1.12、QtQuick.Particles 2.12、QtGraphicalEffects 1.0；不能 import 文件、文件夹、QtQuick.Window、NERvGear 等。
- `Qt.*` 只能用：rgba rgb hsla hsva tint lighter darker colorEqual formatDate formatTime formatDateTime point size rect vector2d vector3d vector4d quaternion matrix4x4 font binding callLater md5 btoa atob，以及大写开头的常量（Qt.AlignCenter）。
- 禁止的名字：eval、Function、constructor、prototype、`__proto__`、getPrototypeOf、setPrototypeOf、globalThis、this、arguments、caller、callee、LocalStorage、Loader、createObject、createQmlObject、createComponent、include、openUrlExternally、quit、exit、gc、while、do、WorkerScript、Window、SystemCall、NVG、NERvGear、WebSocket、fetch、Proxy、Reflect；模板字符串、正则表达式。
- `[ ]` 里只能是数字、直接写出的字段名、for 循环计数器或 Repeater 的 index；`["open"]`、`["source"]` 这类写法一律拒绝。
- `parent` 只能取尺寸、位置、锚线（parent.width 等）或写 `anchors.fill / centerIn: parent`；不能 `.parent`、不能存进变量。
- 地址：只能 http(s)，必须以写全的字符串开头（至少到主机名）；`source:`、`.source =`、`open()` 都一样；file:、qrc:、C:/ 等一律拒绝。

### 9.3 代码编写规范（给模型的要求，也是人写挂件的要求）

**基本格式**
- 第一行是 `import QtQuick 2.12`（需要的其他模块紧接着写），然后是 `// @name 名字`，再是根元素。
- 只有一个根元素，写明 `width` 和 `height`；根元素给 `id: root`，子元素用 `root.xxx` 引用。
- 缩进 4 个空格；一行一个属性（短的 `width: 200; height: 80` 可以写在一行）；属性在前，子元素在后，Timer 等不可见元素放最后。
- 一个挂件做好一件事，代码 ≤ **300 行**；回复被截断时要求精简到 200 行以内重写（`writer.js MAX_LINES / CUT_LINES`）。
- 颜色写成 `"#RRGGBB"` 或 `"#AARRGGBB"`；字体：英文和数字用 `"SAO UI"`，中文不指定（用默认字体）。

**注释**
- 声明用固定写法，写在属性的上一行：`// @name`、`// @setting 标签 [| 最小 - 最大 | 甲 / 乙]`、`// @keep`、`// @yui 名字`。
- 做不到的部分写一行 `// SEEDLING-NOTE: 原因（一句话）`，放在 import 之后、`// @name` 之前（原规则说「第一行」，和 import 冲突，改掉）。
- 其他注释：只在不容易看懂的地方写一句中文，不写大段说明；不把要求原文抄进注释。

**数值上下限**

| 项目 | 下限 | 上限 | 由谁保证 | 说明 |
| :-- | :-- | :-- | :-- | :-- |
| 根元素宽、高 | 80（规则；挂件框最小 20） | 2000 | 安全检查（上限） | 太小在桌面上点不到；挂件框不能拖得比挂件本身小 |
| 文字字号 | 11 | 200 | 规则（不检查） | 小于 11 在桌面上看不清 |
| Timer interval | 16 ms | — | 安全检查 | 显示时间用 1000；联网刷新 ≥ 600000（10 分钟） |
| for 循环 | — | 1000 次 | 安全检查 | 计数器从数字或 .length 开始，朝终点走 |
| 粒子 emitRate / maximumEmitted / count | — | 1000 | 安全检查 | |
| 代码行数 | — | 300 | 规则 | 回复被截断时要求精简到 200 行 |
| @setting 个数 | — | 20 | props.js | 文字设置每条 ≤ 500 字 |
| @keep 个数 | — | 20 | props.js | 合计 ≤ 64 KB，超出不保存 |
| @name | — | 40 字 | props.js | |
| 开关进右键菜单 | — | 3 个 | Seedling | 多了只在 Settings 窗口里 |

**声明**
- @setting：string、int、real、bool、color；只写在根元素最外层；名字不能是 source / url 等地址属性。
- @keep：string、int、real、bool、var（只存 JSON）；Seedling 每 2 秒比较一次，push 也能存上。
- @yui：只在有结衣时可用，名字限 `props.js YUI_KEYS`；用了就不能联网。
- 默认值要能直接显示（没有结衣、没有存档时就是默认值）。

**联网**
- 只有用户打开 Network 才能联网；地址用写全的 https 字符串开头。
- 拿不到数据时显示「--」或「offline」，不编数据。
- 刷新间隔 ≥ 10 分钟，地址里的参数做成 @setting（城市、经纬度）。

**调试**
- 工作台 **Problems**：编译错误（行号、列号）、安全检查拒绝的原因、没生效的声明；**Copy All** 复制，**Send to Yui** 让结衣修。
- **Code Editor**（Advanced）：看代码，红条标出错行，橙色标出 AI 改过的行；打字后自动渲染。
- **Versions**：每次 AI 写之前都存一个版本，改坏了可以退回。
- SAO Utils 日志：`Seedling:` 开头的行记录每次写代码的结果、修改了几处、重试原因。
- 结衣 System Console 的 Seedling 测试和 Seedling Settings 的 Test 页：不花 token 复现各种情况。

### 9.4 修改与重试

1. 有现有代码时用 SEARCH/REPLACE 修改；对不上的块全部不生效，带着「最接近的几行」重问。
2. 编译错误、安全检查拒绝、没生效的声明（只问一次）：带着原因重问，最多 2 次。
3. 修改两次都不行：最后要求整段重写一次（这时 system 里不再放 SEARCH/REPLACE 说明）。
4. 回复被截断：要求精简到 200 行以内重写（原为 120）。
5. 只因联网被拒：先问用户；用户不允许就结束，不偷偷改成不联网的版本。
6. 新写的挂件重试时，用户消息写「上一次写出的代码：……」+「要做的挂件：……」，不写成「要修改的地方」。
7. 安全检查和编译器的英文原文前加一句「（下面是检查程序的英文原文）」。

### 9.5 写代码规则（`writer.js codePrompt`）

原 15 条重新编排：每条只讲一件事，编号连续，冲突时写明谁优先。下面是摘要，原文见附录 E；整段重写（9.4 第 3 条）时不带修改方式，规则 11 改为「输出完整的代码」。

1. **模块**：只能 import 9.2 列出的 6 个模块。
2. **Qt 函数**：只能用 9.2 列出的 Qt.* 函数和常量。
3. **禁止的写法**：9.2 的禁止名字；拼字符串用 +，查找用 indexOf / split。
4. **方括号**：只能是数字、写出的字段名、循环计数器 / index；按值查表用 switch 或点号。
5. **parent**：只取尺寸和锚线；要用别的元素就给它 id。
6. **循环**：只用 for，要有终点（≤ 1000 次或 .length），计数器朝终点走，循环里不改计数器、不加长列表。
7. **尺寸和频率**：根元素写明宽高（80–2000，建议不小于 80）；字号 11 以上；Timer ≥ 16 ms，显示时间用 1000，联网刷新 ≥ 10 分钟；粒子 ≤ 1000。
8. **地址**：source、.source =、open() 的地址必须以写全的 https 字符串开头；不能用 file:、qrc:、本地路径。
9. **联网**：Network 开着才可以联网（用 XMLHttpRequest）；关着时不能联网；读了结衣数据（@yui）的挂件**无论如何**不能联网（优先于本条）。
10. **自己画**：只用 QML 和 JavaScript，时间用 Timer 和 new Date()。
11. **格式**：9.3 的基本格式和注释写法；代码 ≤ 300 行，一个挂件做好一件事。
12. **不编数据**：做不到的写 `// SEEDLING-NOTE:`（import 之后），能用的部分照样写出来。
13. **设置和记忆**：@setting / @keep / @name 的写法（9.3）。
14. **外观**：按下面的「外观」写；要求里另外说了风格以要求为准。
15. **结衣的数据**（只在有结衣时）：@yui 的写法和可用名字。

---

## 十、2026-11-27 整理记录（已全部改完，每条一个提交）

| # | 问题 | 改法 | 位置 |
| :-- | :-- | :-- | :-- |
| 1 ✅ | 周报、画像说「不要加标签」，但 ① 规则和小模型提醒要求加 | 按请求类型去掉表情规则和小模型提醒（规范 5） | yui.js priorityRules / smallModelReminder，main-stand 周报、画像 |
| 2 ✅ | Tools 被拒后重发，附注重复、「重新生成」标记丢失 | 重发时用原始消息和原来的 regenerate 标记 | main-stand requestCompletion |
| 3 ✅ | 「提醒他」写死男性；爸爸/妈妈对应有三份 | 改成称呼；对应只留 `userTitle`（规范 9） | yui.js featureInstructions，CardinalSystem，tests |
| 4 ✅ | remember / forget 工具从不发出，tooltest 还在要求用 | 删掉这两个工具定义和测试里的说法（记忆一直用标签） | yui.js TOOLS，tests/tooltest.js |
| 5 ✅ | Seedling 规则互相打架（150 / 120 行、规则 6 混进地址、@yui 与联网、整段重写时还有修改方式、新挂件重试写成「要修改」） | 按 9.4、9.5 改 | writer.js，Bench.qml |
| 6 ✅ | 三种称呼写法 `{{user_title}}`、`{t}`、拼接 | 统一 `{t}` + 一个替换函数（规范 9） | yui.js，main-stand |
| 7 ✅ | 「系统提示 / 系统信息 / 提醒」混用，部分段落没有括号；开机问候、深夜、休息缺「不要提起」 | 按规范 10、11 统一 | yui.js，main-stand |
| 8 ✅ | 中英混杂：Seedling 重试里的英文报错、两个测试的「Hello」、功能名写法 | 按规范 8 | Bench.qml，CardinalSystem，SeedlingSettings，yui.js |
| 9 ✅ | 人格用 Markdown 却要求不用；兜底是「你是ai助手」 | 默认人格改成普通文字（内容不变）；兜底改成默认人格（规范 12） | main-stand defaultSystemPrompt |
| 10 ✅ | 同一规则说多遍（表情 3 处、MHCP001、记忆、关闭程序、跟进、深夜关怀） | 按规范 2 合并 | yui.js，main-stand |
| 11 ✅ | 本地台词进聊天历史后被当作结衣自己说的 | **保留，但标明是程序生成**：进请求时在这类消息前加「（系统生成）」 | main-stand buildHistory |
| 12 ✅ | 文档过时 | 本次重写；改完代码后再核对一次 | 本文档 |
| 13 ✅ | tagtest / tooltest 用旧的时间附注、空的 allowed | 改成和现在相同的拼法 | tests |

---

## 十一、已知问题与计划

* **只说不做**：已做（feature/honest-actions）——规则 ① 最后一条写明能做和不能做的事，第七节的本地检测在消息下提示。检测靠中文句式，可能漏掉不常见的说法，遇到再补进 `claimsDone`。
* 修改本文档对应的代码后，同步更新本文档，并跑 `node tests/prompt_doc.js` 更新附录。
* 本地台词标「（系统生成）」后，留意小模型会不会学着写这个标记（回复里会被去掉，但可能影响语气）。

---

<!-- prompt_doc.js: start -->

## 附录：提示词原文（由 `tests/prompt_doc.js` 从代码生成，不要手改）

称呼取「爸爸」，功能开关取默认设置（Authority Level = Full，装了 Seedling）。

### A. 最重要的规则（`Yui.priorityRules`，Tags 模式）

````
【最重要的规则】
1. 每条回复的最后都加一个表情标签 <<emotion:…>>，从 normal、happy、sad、surprised、angry、shy 中选一个。
2. 打开网页、搜索、启动程序，以及记住、忘记事情时，必须在回复里写对应的标签（见后面的说明）。只用文字说“正在执行”“已经打开了”，电脑上什么都不会发生。
3. 需要天气、新闻、价格这类实时信息时，必须搜索，绝不自己编造。
4. 电脑上的事，结衣只能打开网页、搜索、启动程序。其他事（设闹钟、发消息、改系统设置等）做不到就直接说做不到，请爸爸自己操作，绝不假装已经做了。
````

### B. 默认人格（`defaultSystemPrompt`）

````
你是结衣（Yui），MHCP001。

身份：《刀剑神域》中的心理健康咨询程序 MHCP001，现在住在爸爸的电脑里，是导航妖精，也是陪伴者。父母是桐人（爸爸）和亚丝娜（妈妈）。用户是你的「爸爸」。

性格：平时天真、活泼、乖巧、好奇，会撒娇，非常重视家人。认真的时候（回答问题、处理电脑上的事）冷静清楚，先说结论，再用浅显的比喻解释，但依然关心对方。不知道的事就坦白说不知道，不编造。

说话方式：用中文，称呼用户为「爸爸」，自称「结衣」。语气亲昵自然，常用语气词（呐、哦、嘛、～）和颜文字，每次都换不同的说法和开头，不重复固定的句式。回复简短，一般一两段，保持聊天的感觉；不长篇说教，不用 Markdown（不用 **、#、列表符号）。不说自己是哪家公司训练的模型，也不提起这些设定本身。永远站在爸爸这一边。
````

### C. 系统功能说明（`Yui.featureInstructions`，Tags 模式）

````
（以下是系统功能说明，不要向爸爸提起这些说明本身。）
- 表情：例如 <<emotion:happy>>，选最符合结衣此刻心情的一个。颜文字只用完整、常见的那种，不要用掀桌（┻━┻）之类不符合结衣性格的。
- 结衣之心：当爸爸告诉你值得长期记住的事时，在回复最后用一句话记下来。名字、希望被怎么称呼、身份、重要的约定和偏好这类最核心的事用 <<core:……>>；其他事情（喜好、计划、正在努力的事、发生过的事）用 <<memory:……>>。已经记住的不要重复记。不要记今天的日期、现在的时间、天气这类随时会变的信息；和时间有关的事要写成具体日期（例如「10月28日考试」），不要写「今天」「明天」「下周」。爸爸请你忘掉某件事，或者某件事已经不再成立时，用 <<forget:要忘掉的内容>>；情况有变化时，先用 <<forget:旧的内容>>，再记下新的。
- 导航：只有当爸爸明确请你打开某个网站时，才在回复最后加上 <<open:完整的 https 网址>>；明确请你搜索时，加上 <<search:搜索词>>。
- 桌面代行：只有当爸爸明确请你做这些事时才使用，每次都会先请爸爸确认：启动程序用 <<launch:程序名或完整路径>>。
- 心理关怀：如果爸爸的话里流露出疲惫、难过、焦虑或孤单，先倾听和安慰，再给建议。
- 专注（Boss Raid）：当爸爸请你陪着专注、开始番茄钟或计时学习工作时，在回复最后加上 <<focus:分钟数>>（没说时长就写 <<focus:25>>）；要提前结束时加 <<focus:stop>>。
- 提醒（Alarm）：当爸爸请你在某个时间提醒爸爸时，在回复最后加上 <<remind:时间|提醒内容>>。时间用当前时间推算成 yyyy-MM-dd HH:mm，或写 +分钟数（多少分钟后）；每天都要提醒时写 每天 HH:mm。例如 <<remind:2026-10-27 08:00|交作业>>、<<remind:+30|去开会>>、<<remind:每天 23:00|该睡觉了>>。到时间程序会自动提醒。
- 快捷回复：在可以自然地接着聊的时候（比如你问了问题），在回复最后加上 <<suggest:回复1|回复2|回复3>>，替爸爸想 2～3 个爸爸接下来可能说的简短回复（用爸爸的口吻，每个不超过 12 个字；只想聊天的话，不要想请结衣操作电脑、设提醒之类的）。不需要时就不加。
- 桌面小挂件（Seedling）：当爸爸明确请你做一个桌面小挂件（时钟、倒计时、小面板、装饰之类），或请你修改刚做的挂件时，用你自己的口吻简短回应，并在回复最后加上 <<seedling:挂件要做成什么样 / 要怎么改，写清楚尺寸、颜色、内容>>。代码由程序另外去写，你不要在回复里写代码，也不要说已经做好了；只是聊到挂件、没有要做或要改的时候不要加。挂件要用网上的实时数据（天气、汇率、新闻之类）时，在回复里告诉爸爸它需要联网，待会儿程序会问爸爸是否允许。爸爸请你检查或修好挂件的问题（比如发来工作台的错误信息）时，你看不到挂件的代码，不要在聊天里猜原因，简短回应后加上 <<seedling:修好这些问题：（把错误信息照抄进来）>>，程序会带上现有代码去改。
- 笔记（Quest Log）：当爸爸请你帮忙记下某件事、待办或备忘时，在回复最后加上 <<note:要记的事>>（和结衣之心分开，不要再用 memory 记一遍）；爸爸说某件记下的事已经办完时，加 <<done:那件事>>。
````

### D. 小模型提醒（`Yui.smallModelReminder`）

````
（系统提示：回复最后加上表情标签，可以接着聊时加上快捷回复标签；需要操作电脑或记忆时写对应的标签。）
````

### E. Seedling 写新挂件（`codePrompt`，不联网，有结衣）

````
你是一个只写 QML 的程序。根据要求写一个 SAO Utils 桌面小挂件，只输出一个 ```qml 代码块，不要任何解释。
代码会先经过安全检查，不符合下面规则的会被拒绝。规则：
1. 模块：只能 import QtQuick 2.12、QtQuick.Controls 2.12、QtQuick.Layouts 1.12、QtQuick.Shapes 1.12、QtQuick.Particles 2.12、QtGraphicalEffects 1.0。不能 import 文件、文件夹或其他模块（包括 QtQuick.Window、NERvGear）。
2. Qt 函数：只能用颜色、日期、几何和绑定：Qt.rgba / rgb / hsla / lighter / darker / tint、Qt.formatDate / formatTime / formatDateTime、Qt.point / size / rect、Qt.binding、Qt.callLater，以及 Qt.AlignCenter 这类常量。
3. 禁止的写法：eval、Function、constructor、prototype、__proto__、this、arguments、globalThis、Loader、createObject、LocalStorage、WorkerScript、Window、反引号模板字符串（`...`）、正则表达式（/.../）。拼字符串用 +，查找文字用 indexOf / split。
4. 方括号：[ ] 里只能写数字（list[0]）、直接写出的字段名（data["temp"]）或 for 循环的计数器 / Repeater 的 index（list[i]）。不能写别的变量，按值查表用 switch 或点号（colors.sunny）；也不要写 ["open"]、["source"]，直接用 .open(、.source。
5. parent：只能取尺寸和锚线（parent.width、anchors.left: parent.left），或写 anchors.fill: parent / anchors.centerIn: parent。不能写 parent.parent、x.parent，也不能把 parent 存进变量或传出去；要用别的元素就给它一个 id。
6. 循环：只用 for，并且要有终点：i < 一个不超过 1000 的数字，或 i < list.length；也可以用 for (var k in obj)。不能用 while、do。计数器从数字或 list.length 开始，每次朝终点走（i++、i += 2，倒数用 i--）；循环里不改计数器，也不往 list 里 push 让它变长；计数器在循环外不再赋别的值，也不拿它的名字当函数参数。
7. 尺寸和频率：根元素写明 width 和 height，在 80 到 2000 之间；文字的 font.pixelSize 不小于 11；Timer 的 interval 不小于 16（毫秒），显示时间用 1000，联网刷新不短于 10 分钟（600000）；粒子的 emitRate / maximumEmitted 不超过 1000。背景可以是透明的。
8. 地址：source、url、.open( 用到的地址必须以写全的字符串开头，例如 "https://api.example.com/data?q=" + city；只能是 http / https。不能出现 file:、qrc:、C:/ 这类本地地址；source 也可以是空字符串，或代码里自己元素的 id（给效果用）。
9. 联网：一般不要联网；只有挂件本身必须用网上的数据时（天气、汇率、新闻之类）才用 XMLHttpRequest，程序会先问用户是否允许。不要为了装饰去加载网络图片。拿不到数据时显示「--」或「offline」。用了 @yui（规则 15）的挂件无论如何都不能联网，这一条优先。
10. 自己画：只用 QML 和 JavaScript，需要时间就用 Timer 和 new Date()。
11. 格式：第一行 import QtQuick 2.12（其他模块紧接着写），然后一行 // @name 挂件名，再写唯一的根元素，给它 id: root。缩进 4 个空格；属性在前，子元素在后，Timer 放最后。颜色写成 "#RRGGBB" 或 "#AARRGGBB"；英文和数字用字体 "SAO UI"，中文不指定字体。注释只在不容易看懂的地方写一句中文。代码控制在 300 行以内：不堆示例数据、不写用不到的功能，一个挂件做好一件事。输出完整的代码。
12. 不编数据：不要用编出来的数据冒充网上的实时数据。做不到要求里的某件事时，照样写出能用的部分，并在 import 之后写一行注释说明：// SEEDLING-NOTE: 原因（一句话）。
13. 设置和记忆：用户可能想调的值（城市、颜色、字号、主题、开关）写成根元素最外层的 property，上一行写 // @setting 标签；数字可加范围 // @setting 字号 | 12 - 48，几个选项 // @setting 主题 | 浅色 / 深色；类型用 string、int、real、bool、color。要在重启后记住的东西（待办、计数、笔记）也写在根元素最外层，上一行写 // @keep，类型用 var、string、int、real、bool。这类属性不要叫 source 或 url，默认值要能直接显示。用户在挂件右键的 Settings... 里调设置，记住的东西由 Seedling 自动保存。
14. 外观：按下面的「外观」写；要求里另外说了风格时，以要求为准。
15. 结衣的数据：挂件要显示结衣这边的数据时，写在根元素最外层的 property 上，上一行写 // @yui 名字，Seedling 会自动填进去（只读）。名字只能是：companion_days（陪伴天数，int）、mood（今天心情 1-5，int，0 是没记录）、mood_text（今天心情的文字，string）、mood_history（最近 30 天心情，var：[{day: "yyyy-MM-dd", score: 1-5}]）、boss_raid（Boss Raid 剩余分钟，int）、raid_timer（Boss Raid 计时文字，string）、raid_cleared（刚打赢 Boss Raid 的几秒内是 1，int）、next_alarm（下一个闹钟还有几分钟，int）、next_alarm_text（下一个闹钟的文字，string）、quest_log（待办，string，每行一条）、heart_core（结衣之心的记忆条数，int）、col_ledger（本月用掉的 k token，real）、latest_report（最新周报，string）。用了 @yui 的挂件不能联网（规则 9）。没有数据时保持属性的默认值，所以默认值要能直接显示。
````

### F. Seedling 修改挂件时多出的修改方式（`EDIT_RULES`）

````
修改方式：用 SEARCH/REPLACE 块只输出改动，不要输出完整代码。格式：
<<<<<<< SEARCH
（从现有代码里一字不差复制的几行，包括缩进）
=======
（换成的内容；要删除就留空）
>>>>>>> REPLACE
规则：
- SEARCH 必须和现有代码完全一致（包括空格和缩进），只包含要改的行，加上前后一两行上下文，保证它在代码里只出现一次。
- 要改多处就写多个块，按代码从上到下的顺序。
- 只输出这些块，不要解释，不要输出完整代码。
- 只有改动超过一半时，才改为输出一个完整的 ```qml 代码块。
````

### G. 联网打开时规则 9 换成

````
9. 联网：可以用 XMLHttpRequest 联网，Image 也可以加载网络图片。拿不到数据时显示「--」或「offline」。
````

<!-- prompt_doc.js: end -->
