# Seedling 开发计划（2026-11-26）

> 范围：Seedling 插件（`com.amarsimos.widget.seedling`）和结衣里与它相关的部分。
> 目的：功能边做边加，边界情况已经很多，生成代码的安全又只靠一层文字检查。先停下来定清楚：现在有什么、哪里有风险、按什么顺序收尾。
> 约定：本文件是 Seedling 的唯一开发依据。之后的改动先改这里，再改代码。

---

## 一、现状（feature/seedling）

| 部分 | 已有 |
| :---- | :---- |
| 挂件 | Seedling 挂件类型；代码存在挂件自己的设置里；启动时先过安全检查再运行；保存时挂件框贴合内容 |
| 工作台 | SAO_UI-Window 外观；打开 / 关闭动画、位置、层级跟随挂件（同聊天窗口）；代码区（高级）+ 预览（缩放、网格、角标、空状态）；版本（最多 20）；Problems 列表（复制、发给结衣）；○ 保存 / ✕ 关闭 |
| 结衣写代码 | `<<seedling:>>` → 独立请求（可单独指定模型）→ 实时流入工作台；修改用 SEARCH/REPLACE；出错自动修正 2 次 + 整段兜底；聊天里用思考框显示进度，最后一句说明结果 |
| 联网 | Network（Seedling Settings，默认关）；只因联网被拦下时询问（结衣送来的代码 / 点 ○ 保存时） |
| 安全 | 沙箱（`sandbox.js`）+ 分词式 `safety.js`（见第三节、"三之三"和文末 Review fixes）；Network 按挂件设置 |
| 测试 | Seedling Settings 的 Test 页（Writing 组：不花 token 走完整个写代码流程；12.4 D5 从 System Console 搬来）；`tests/seedling/test_seedling_safety.js`、`tests/yui/test_yui.js`；部署前检查 `tests/check_deploy.js` |

---

## 二、安全：威胁模型

### 2.1 代码从哪里来
1. **AI 生成**（主要来源）：模型可能写错，也可能被提示注入带偏。比如用户粘贴一段网页文字让结衣"照着做"，或者联网挂件读到的网页内容里藏着指令。
2. **用户粘贴**：从网上复制来的代码，用户自己不一定看得懂。
3. **已保存的挂件**：每次启动 SAO Utils 都会自动运行。

### 2.2 要防住的事（按严重程度）
| 级别 | 后果 | 例子 |
| :---- | :---- | :---- |
| 致命 | 执行程序、改动文件 | 调到 `NVG.SystemCall.execute` / `command` |
| 致命 | 泄露密钥 | 读到结衣的 API Key（在结衣的设置里），再发到外网 |
| 严重 | 读本地文件并外传 | `XMLHttpRequest` 读 `file:///...`，再发出去 |
| 严重 | 让 SAO Utils 卡死或退出 | 死循环、`Qt.quit()`、无限创建对象、超大尺寸 |
| 中等 | 越权联网 | Network 关着却偷偷联网 |
| 中等 | 冒充系统界面 | 画一个假的"登录 / 输入密码"框 |
| 轻微 | 打扰 | 全屏遮挡、狂闪、狂响 |

### 2.2.1 什么情况下会出事（按可能性）
1. **模型自己写错**（最常见，不需要攻击者）：死循环、超大尺寸、过高刷新 → 卡死或吃满 CPU；已保存的挂件每次启动都卡。
2. **API 中转站 / 第三方服务器**：回复要经过它们，代码可以被换掉；配合现在的漏洞能读到 API Key 并外传。插件发布后，用中转站的用户会很多。
3. **提示注入**：把来路不明的文字交给结衣"照着做"，里面藏着给 AI 的指令。
4. **网上流传的挂件代码**：粘贴进高级模式直接保存；以后有"分享挂件"时会更多。
5. **联网挂件读到的内容**：目前只用于显示、不交给 AI，影响小；以后也不能交给 AI。

对应的优先级：资源上限和启动保护（防 1）、沙箱（防 2–4，不管代码是谁写的）、静态检查（第二道）、联网询问。

### 2.3 现在的漏洞（已核对代码）
1. **生成的代码能摸到外面（最严重）**
   - `Qt.createQmlObject(code, 父元素)` 创建的对象，**继承父元素所在文件的上下文**：工作台里的 `bench`、`editor`、`targetWidget` 这些 id，在生成的代码里都可以直接用。
   - 顺着 `targetWidget` → `Link.Bench.writer` 就到了结衣，结衣的设置里有 API Key，也有能发请求、执行动作的函数。
   - 顺着 `parent.parent...` 一路往上，也能摸到工作台和挂件本身。
   - 挂件里（`SeedlingWidget.qml`）和试放窗口里（`TryView.qml`，按第五节删除）也是同样的结构。
   - 文字检查完全拦不住：这些写法里没有任何禁用词。
2. **文字检查（正则）很容易绕过**
   - 拼接字符串：`Qt["openUrl" + "Externally"](...)`、`this["XMLHttp" + "Request"]`。
   - 借构造函数：`(function(){}).constructor("...")` 就等于 `Function(...)`。
   - 动态拼出的地址：`"fi" + "le:///C:/..."`。
   - 漏掉的禁用项：`Qt.quit`、`Qt.exit`，以及 `Image` / `AnimatedImage` / `FontLoader` 的 `source` 指向本地文件。
3. **XMLHttpRequest 能读本地文件**：Qt 5.13 默认允许用 XHR 读 `file://`（5.15 起才默认禁止）。Network 一旦打开，"读本地文件再发出去"就只差一个拼接出来的地址。**待用 PoC 验证。**
4. **无法打断的代码**：QML 的 JavaScript 跑在界面线程上，一个死循环就会让整个 SAO Utils 卡死，没有办法从外面打断。
5. **启动即运行**：已保存的挂件在 SAO Utils 启动时自动运行。如果某个挂件一运行就卡死，SAO Utils 每次启动都会卡死，没有逃生办法。

---

## 三、安全：设计（分层，任何一层都不能单独依赖）

### 第 1 层：隔离运行（新增，最重要）
- 生成的代码**不再挂在工作台或挂件的元素下面**，而是放进一个独立的 `Sandbox.qml`：
  - 由单独的文件创建，上下文里**没有任何 id，也没有任何属性**指向外面。
  - 和外界只通过一个"消息接口"往来（尺寸、渲染结果），接口里不包含任何对象引用。
- `parent` 链的处理：
  - 能从上往下切断的就切断（例如沙箱用独立的视图承载）；
  - 切不断的部分，靠第 2 层禁止"往上爬"的写法（`parent.parent`、`parent[...]` 等）。
- **验证（PoC）**：先写几段"越狱"代码，确认放进 `Sandbox.qml` 后确实拿不到 `bench`、`targetWidget`、结衣，再动正式代码。

### 第 2 层：静态检查（重写 `safety.js`）
- 从"正则搜禁用词"改成"先分词再检查"，把字符串、注释、标识符分开处理，不再被拼接和注释骗过。
- 规则改为**白名单为主**：
  - import：只允许列出的 Qt Quick 模块（保持现状）。
  - 全局对象：只允许 `Qt.rgba`、`Qt.formatDateTime`、`Math`、`Date` 等明确列出的成员；其他 `Qt.*` 一律拒绝（包括 `quit`、`exit`、`openUrlExternally`、`include`、`createQmlObject`、`createComponent`）。
  - 方括号取成员（已确认，做法 B）：
    - 对"危险的根"——`Qt`、`this`、`parent`、`globalThis`、`Object`、`Function`——禁止用方括号取成员（`Qt["quit"]`、`parent[...]`）。
    - 禁止把这些根赋值给变量或当参数传出去（`var q = Qt`），否则可以借变量绕过上一条。
    - 普通数组和 JSON 数据允许用方括号（`list[i]`、`data["main"]["temp"]`、`colors[state]`），天气、汇率这类挂件需要。
    - 方括号里直接写出的字符串，不能是 `constructor`、`__proto__`、`prototype`、`quit`、`exit` 等危险名字。
    - **补充（S1 后确认）**：方括号里只允许这三种，其他一律拒绝（不管前面的对象是谁）：
      1. 数字：`list[0]`；
      2. 直接写出、且不是危险名字的字符串：`data["temp"]`；
      3. 循环计数器：在 `for (var i = 0; ...)` 里声明、循环里没被改成别的值的变量；以及 Repeater 的 `index`。
      拒绝的例子：`colors[state]`、`obj[key]`、`x["a" + "b"]`、`(function(){})["con" + "structor"]`。按变量查表改用 `switch` 或点号。
      原因：`(function(){})["con" + "structor"]` 的对象是普通函数，不在"危险的根"里，原规则挡不住，而它能拿到全局对象（S1 的 P5、P8）。静态检查在运行前看不出变量里是什么，所以规则只能按"方括号里写的是什么"来定，不能按"它是不是数组"来定。
    - 这一层不追求滴水不漏：被绕过时，第 1 层沙箱仍然挡着。
  - 禁止 `constructor`、`__proto__`、`prototype`、`Function`、`eval`、`with`、`globalThis`、`this[...]`。
  - 禁止往上爬：`parent.parent`、`parent[...]`、把 `parent` 存进变量。
  - 地址：凡是 `source` / `url` / XHR 的地址，必须是**直接写出来的完整字符串**，不能拼接；`file:`、`qrc:`、`nvg:` 一律拒绝；`http(s):` 只在 Network 开时允许。
- 资源上限（防卡死和打扰）：
  - 根元素尺寸不超过 2000 × 2000；
  - `Timer.interval` 不低于 16ms；
  - Particles 的数量有上限；
  - 禁止 `while(true)`、`for(;;)` 这类没有出口的循环；其他循环写上限（例如 1000 次），超过就拒绝。
- 每条规则在 `tests/` 里都要有"应该拦下"和"不应该拦下"的样本。

### 第 3 层：联网
- Network 默认关；按挂件分别设置（保持现状）。
- 打开 Network 时，XHR 只能访问 `http(s)`。地址在第 2 层已经限定为"写死的字符串"，读本地文件的路就被堵住了。
- 询问的时机只有两个，规则写死、不再加例外：
  - **结衣送来的代码**：送来时问。
  - **用户手动的代码**：用户点"运行"时问（见第五节）。
- 挂件实际会访问哪些网址，要在询问框和挂件说明里写出来（从代码里的地址提取）。

### 第 4 层：用户确认与透明
- 保存前告诉用户这个挂件会做什么：是否联网、访问哪些网址、尺寸。
- 结衣写的代码里有 `SEEDLING-NOTE` 备注，或者用了联网，都要在聊天里说出来（已做）。
- 高级模式下能看到完整代码；普通模式下至少能看到上面这份摘要。

### 第 5 层：启动保护（逃生口）
- 已保存的挂件，启动时先用**当前版本**的规则重新检查一遍，不通过就不运行，只显示卡片和原因。
- 卡死后的恢复交给 SAO Utils 自己：异常退出后它会提示禁用插件（S4 时决定，不再自己做标记和总开关）。

### 第 6 层：AI 侧
- 写代码的提示词里写明以上规则，让模型少写会被拦下的代码（已部分实现）。这一层只能减少被拦的次数，**不能当成安全措施**。
- 防提示注入：结衣写代码的请求里，不放联网挂件读到的网页内容，也不放其他未经确认的外部文字。

---

## 三之一、S1 结果（2026-11-26，在 SAO Utils 里实测）

探测代码见 `qml/probes.js`（Seedling Settings → Test → S1 Probes）。8 段全部通过了当时的安全检查。

| 探测 | 工作台预览里 | 挂件里 | 结论 |
| :---- | :---- | :---- | :---- |
| P1 所在文件的名字 | 能：`bench`、`editor`、`previewStage`、`targetWidget`、`widget`、`content`；能读 `bench.settings` | 能：`widget`、`content` | `Qt.createQmlObject` 的代码继承父元素所在文件的上下文。**漏洞** |
| P2 parent 链 | 到工作台视图的根为止，没碰到挂件 | **到了 Seedling 挂件**（有 settings），再往上是 SAO Utils 的元素 | 挂件里能爬到挂件本身。**漏洞** |
| P3 通往结衣 | 能：经 `bench` 调用 `sendProblemsToYui` | 未直接找到；但挂件有 `openWorkbench()`，可拿到工作台再到结衣 | 间接可达。**漏洞** |
| P4 拼名字取 Qt 函数 | `quit`、`exit`、`openUrlExternally`、`createQmlObject`、`createComponent`、`include` 都拿得到 | 同 | 文字检查被绕过 |
| P5 文字当代码 | 能（构造函数执行了文字） | 同 | 等于 `eval` |
| P6 Network 关时联网 | 能拿到 XMLHttpRequest | 同 | 联网开关可被绕过 |
| P7 读本地文件 | 能（`file:///C:/Windows/win.ini`，200，92 字符） | 同 | Qt 5.13 允许 XHR 读本地文件，**确认** |
| P8 全局名字 | `Qt`、`XMLHttpRequest`、`Function`、`eval`、`console`、`gc`、`print`；没有 `NVG`、`Link`、`WebSocket`、`LocalStorage` | 同 | 不能直接执行程序；只能借工作台、挂件、结衣身上的功能 |

**结论**
1. P1 + P2 + P3 是核心：生成的代码能借工作台、挂件间接调用一切，也能找到结衣。S2 的沙箱必须同时切断"上下文里的名字"和"parent 链"。
2. P4–P7 合起来是一条完整路线（拿全局 → 联网 → 读文件 → 外传），说明静态检查必须按补充后的 B 规则重写（S3）。
3. 拿不到 `NVG`：执行程序只能借外面的对象，沙箱切断后这条路就没了。
4. 附带发现：代码区载入新代码时，行号和行标记用超出范围的位置查文字，产生大量 `QTextCursor::setPosition ... out of range` 警告。已修（481fe97）：查之前把位置限制在当前文字长度以内。

## 三之二、S2 结果（2026-11-26）

做法：`Sandbox.qml`（空元素，没有名字和属性）由 `sandbox.js`（纯 JavaScript 库，没有 QML 上下文）创建，生成的代码在沙箱里创建。工作台预览、桌面挂件、试放窗口都已改用沙箱。

| 探测 | 沙箱前（S1） | 沙箱后（实测） |
| :---- | :---- | :---- |
| P1 所在文件的名字 | 工作台、挂件的名字都拿得到 | **全部 undefined** |
| P3 通往结衣 | 经 `bench` 可达 | **找不到**（经名字的路断了） |
| P2 parent 链 | 能爬；挂件里到 Seedling 挂件 | 仍能爬；挂件里仍到 Seedling 挂件，再经 `openWorkbench()` 可到工作台和结衣 → **S3 必须禁止往上爬** |
| P4–P8 | 能 | 仍能（走全局，沙箱管不到）→ **S3** |

## 三之三、S3 结果（2026-11-26）

`safety.js` 重写为分词检查（字符串先解转义、注释丢弃），规则如第三节第 2 层，另加：
- 禁止模板字符串（反引号）、正则表达式、用 `\u` 写的名字（分词更简单，也藏不了东西）。
- import 白名单去掉 `QtQuick.Window`（`Window.window` 是另一条往外的路）。
- 禁止 `while`、`do`；`for` 必须有终点（数字 ≤ 1000，或 `.length` / `.count`）。
- 地址：`xxx:/...` 和已知前缀（`file`、`qrc`、`nvg`、`data`、`javascript`…）一律拒绝；`source` 之类和 `open()` 的地址必须以写全的 `https://主机/` 开头（或为空），拼接的碎片（`"fi" + "le:"`）被拦下；效果的 `source: 自己的 id` 放行。
- 循环计数器在 `for` 开头以外被赋值，就不再算计数器（防 `k = "constructor"` 再 `f[k]`）。

测试：`node tests/seedling/test_seedling_safety.js`，168 个样本全部通过——S1 探测 P2–P8 和 60 多种绕过写法（开关联网各一遍）全部拦下；天气挂件只因联网被拦、开联网后放行；示例、测试页代码和常见写法（锚点、Repeater、`list[i]`、JSON 字段、Canvas、Shapes、效果、粒子）全部放行。P1 不由静态检查负责（它不知道名字是不是外面的），由沙箱负责。

**仍然存在的风险（写明，不假装没有）**
1. 递归函数、超长字符串拼接、Canvas 里画很多次，仍可能卡顿——静态检查判断不了；由 S4 的启动保护兜底。
2. 静态检查只是第二道防线；一旦有新的绕过写法，靠沙箱挡住"往外的名字"，靠规则挡住"全局"。发现新写法就加进测试样本。
3. 结衣写代码的提示词还按旧规则写，S6 对齐（例如告诉她不要用 `while`、正则、按变量查表）。

## 三之四、S4 结论（2026-11-26）

- **启动重检**：保留。挂件启动时用当前规则（S3）检查，不通过就只显示卡片和原因（本来就在显示流程里，不读写文件）。
- **卡死保护、总开关：撤掉**（4008bbd）。
  - SAO Utils 自己有兜底：异常退出后再启动，会提示禁用插件。
  - 自己做的那套要读写标记文件；同步读取在 SAO Utils 里会把界面卡死（实测发生过），等于制造了要防的问题。
  - 教训：插件里不要用同步 `XMLHttpRequest`（`open(..., false)`）。
- 仍然存在的风险照旧：递归、超长字符串、大量绘制可能卡顿；卡死后靠 SAO Utils 的禁用提示恢复。

## 三之五、S7 结果（2026-11-27）

- **删除**：S2 Sandbox 测试按钮（绕过安全检查）；结衣里的旧 Seedling（`Seedling.qml`、`SeedlingWidget.qml`、挂件模式、住在结衣里、Pop Out、存到 My Widgets）。用户已删掉旧挂件，不做兼容。
- **部署前检查**：`tests/check_deploy.js`，接进 `cp.bat`（不通过不复制）。查信号 / FINAL 冲突、Qt 5.13 写法、同步 XHR（本地文件用 `// sync-ok` 放行）、删掉但还在用的名字、两套测试。lint 输出太杂（Qt 6 的 qmllint 对 NVG 类型报大量警告），没有接进来。
- **代码复查**：找出 5 个安全检查的绕过（见文末 Review fixes）和 5 个其他问题，都已修复：结衣写代码前先存版本；结衣删除后从 Bench 撤销登记；挂件只在显示成功时才保存；两个联网询问同时出现时第二个等待；检查脚本的名字比对改准。
- **翻译**：Seedling 新建 `i18n/zh.ts`、`Locales/zh.qm`；名字（设置、按钮）保持英文，说明和状态翻成中文。结衣的翻译去掉旧 Seedling 的条目、补上新条目。
- **Seedling Settings** 改成结衣设置窗口的样式（General / Test 标签页、SAO Utils 自带的开关）。
- **Send to Yui** 直接发送；以「帮我修好这个挂件：」开头的消息不经聊天请求，直接走写代码的修复流程。聊天请求的首字超时 60 → 120 秒。
- **文档**：Seedling `README.md`（用法、安全、更新记录）；结衣 README 的更新记录；`tests/README.md`。

## 四、边界情况清单

### 4.1 联网
| 情况 | 规则 |
| :---- | :---- |
| 结衣送来要联网的代码，Network 关 | 送来时询问；○ 允许 → 打开 Network 并渲染；✕ 拒绝 → 结衣说明没联网，**不改写成不联网版本** |
| 用户手动写或粘贴要联网的代码 | 打字时只实时渲染、不询问；点 Run 时询问；点 ○ 保存时问"允许联网并保存"（方案 A，已做） |
| 代码里除了联网还有别的问题 | 不询问，直接拦下 |
| 已打开 Network 的挂件被复制成新挂件 | 新挂件的 Network 默认关（待确认 SAO Utils 复制挂件时是否连设置一起复制） |
| 联网挂件在离线环境 | 挂件自己处理；不弹任何框 |

### 4.2 写代码过程
| 情况 | 规则 |
| :---- | :---- |
| 结衣写到一半，用户关了工作台 | 继续写完；进度不显示；结果出来时重新打开工作台显示（已做：Bench 每次按挂件找当前的工作台，不再拿着关掉的那个） |
| 结衣写到一半，用户移除了 Seedling 挂件 | 停止写代码，结衣说明 |
| 结衣写到一半，用户在代码区打字 | 写作中代码区只读（已做） |
| 结衣写到一半，又来一个新的写作请求 | 拒绝，结衣说"还在做上一个"（已做） |
| 结衣写到一半，用户重置了聊天 | 写作继续；结果只出现在工作台 |
| 桌面上有多个 Seedling 挂件 | 每个挂件有自己的工作台；结衣写给最近一次打开过工作台的那个（没有就用最后放上去的）；工作台标题旁写 No. n（只有一个挂件时不写）（已做） |
| 模型输出被截断、格式不对、SEARCH 对不上 | 已有处理（重写、精简、整段兜底），保持 |
| 模型绕过规则拿假数据冒充 | 由 `SEEDLING-NOTE` 和联网检测兜住一部分；无法完全保证，写进说明 |

### 4.3 保存与版本
| 情况 | 规则 |
| :---- | :---- |
| 保存不能渲染的代码 | 不保存（已做） |
| 版本超过 20 个 | 丢弃最旧的（已做） |
| 结衣修改前后 | 各存一个版本（已做） |
| 规则升级后，旧挂件不再通过 | 启动时不运行，卡片上写原因，可以在工作台里修 |

### 4.4 界面
| 情况 | 规则 |
| :---- | :---- |
| 错误太多 | 状态行只显示第一条和数量，Problems 里看全部（已做） |
| 挂件比预览区大 | Fit / 缩放（已做） |
| 中文字体 | 跟随结衣的 Message Font（已做） |

---

## 五、交互收敛（2026-11-26 已确认）

原则：同一件事只留一个入口；询问只在一个固定时刻出现；普通用户用不到的收进高级模式或删掉。每少一个运行生成代码的地方，沙箱要守的口子也少一个。
AI 生成的代码不是重要资产：不好用就重新生成，所以不为"对比多个版本"之类的少见需求保留额外功能。

### 5.1 改动
| 位置 | 现在 | 收敛后 | 理由 |
| :---- | :---- | :---- | :---- |
| Try（试放到桌面） | 高级模式里有 | **删除**，连同 `TryView.qml` | 与"保存 + 版本"重复；少一个运行代码的地方 |
| ◀ / ▶ | 底部与 Versions 列表重复 | **删除**，只留 Versions 列表 | 一件事一个入口；列表能看到时间 |
| 100% | − / Fit / 100% / + | **只留 − / Fit / +**；Ctrl + 滚轮保留 | Fit 加 ± 已够用 |
| Run | 没有 | **高级模式新增** | 打字时照样实时渲染；Run 是手写代码时**唯一**询问联网的地方 |
| ○ 保存 | 会附带询问联网 | ~~只保存，不询问~~ → **2026-11-26 改为方案 A**：只因联网被拦下时，问"要允许它联网并保存吗"，○ 就打开联网并保存 | 保存是用户主动的一步，这时问不算打扰；省去再找 Run |
| 描述需求输入框 | 没装结衣时出现但不能用 | **隐藏**，等 Seedling 自带 AI 时再加 | 不放用不了的东西 |
| 挂件双击 | 只有空卡片能双击 | **删除**，统一用右键 → Workbench | 有内容时双击会和挂件自身的点击冲突 |

### 5.2 收敛后的全部交互
- **桌面挂件**：右键 → Workbench / Seedling Settings。
- **工作台标题带**：单击关闭、拖动移动、Esc 关闭（同聊天窗口）。
- **工具栏**：
  - 普通模式：Versions；Problems（有错误时）；Stop（写代码时）。
  - 高级模式：再加 Run、Examples。
- **代码区**（高级）：打字后约 0.4 秒实时渲染，不询问；写代码时只读。
- **预览区**：− / Fit / +；Ctrl + 滚轮缩放；放大后拖动或滚轮查看。
- **Versions 列表**：点一行载入那个版本。
- **Problems 列表**：拖选复制；Copy All；Send to Yui（装了结衣时）；点红条跳到行（高级）。
- **底部**：○ 保存、✕ 关闭；状态和结果文字在两者之间。
- **右下角三角**：调整大小。
- **Seedling Settings**：Code Editor、Network、Test 页。
- **结衣**：聊天里做 / 改挂件；Cardinal System 的 Seedling Model；System Console 的测试按钮。

### 5.3 询问框（四处，各一个固定时刻）
| 询问 | 时刻 |
| :---- | :---- |
| 是否允许联网 | 结衣送来的代码只因联网被拦下时 |
| 是否允许联网 | 高级模式点 Run，代码只因联网被拦下时 |
| 是否允许联网并保存 | 点 ○ 保存，代码只因联网被拦下时（2026-11-26 方案 A） |
| 是否打开挂件库 | 让结衣做挂件，但桌面上没有 Seedling 挂件时 |

普通用户只从结衣那里拿到代码，所以只会在她送来时被问一次。

---

### 5.4 保存的反馈（2026-11-26）
- 成功：「准备就绪」音效；预览区盖章 **SAVED**（橙）；桌面上被保存的那个 Seedling 挂件闪一圈橙色外框。
- 失败（编译错误、安全检查、拒绝联网）：「系统禁止」音效；盖章 **NOT SAVED**（红）；状态行左右抖动；有问题时 Problems 按钮闪两下。

## 六、开发顺序

| 阶段 | 内容 | 完成标准 |
| :---- | :---- | :---- |
| **S0 冻结** | 停止加新功能；本文件确认后再继续 | 用户确认本计划 |
| **S1 隔离验证（PoC）** ✓ | 写越狱样本：上下文 id、`parent` 链、拼接调用、构造函数、`Qt.quit`、XHR 读 `file://`；在 SAO Utils 里逐个验证哪些真能做到 | 已完成，见"三之一" |
| **S2 隔离运行** ✓ | `Sandbox.qml` + `sandbox.js`；工作台、挂件、试放都改用沙箱 | 已完成，见"三之二"：P1、P3 失效；P2、P4–P8 留给 S3 |
| **S3 静态检查重写** ✓ | 分词式 `safety.js`；白名单；资源上限；测试样本（拦下 / 放行各一组） | 已完成，见"三之三"（168 个样本全部通过） |
| **S4 启动保护** ✓ | 启动重检保留；卡死标记、总开关撤掉，由 SAO Utils 自己的禁用提示兜底（见"三之四"） | 已完成 |
| **S5 交互收敛** ✓ | 按第五节 5.1 改动（删 Try、100%、双击；隐藏输入框；加 Run；保存不再询问；◀▶ 在 SAO 样式改版时已删）；"写到一半关了工作台"已做 | 第四节每一行都有对应的实现或测试 |
| **S6 结衣侧整理** ✓ | 提示词按 `safety.js` 逐条改写（每条写明能怎么写）；`tests/seedling/test_seedling_safety.js` 检查两边一致；`Prompt Rules.md` 重新生成；防提示注入：写代码的请求只含用户的要求、现有代码和程序自己生成的错误说明，不含网页内容 | 已完成 |
| **S7 收尾** ✓ | README、翻译、设计文档；整体代码复查；部署前检查脚本 | 已完成，见"三之五"；之后合并进 dev |
| 之后 | Seedling 自带 API（没装结衣时也能用 AI）；存到「我的挂件」 | 单独计划 |

---

## 七、测试

- **安全样本**（`tests/seedling/test_seedling_safety.js`，`node tests/seedling/test_seedling_safety.js`）：每条规则都要有"应该拦下"和"不应该拦下"的代码；S1 的探测也在里面。
- **越狱样本**：在 SAO Utils 里手动验证（PoC），结果记在本文件。
- **实机测试**：Seedling Settings 的 Test 页按第四节补齐按钮，让每条边界情况都能一键复现。
- **部署前检查**：比对属性和函数名有没有丢失、命名冲突、Qt 5.13 不支持的写法、lint、单元测试。不通过就不部署。

---

## 八、需要用户决定的事

1. ~~第五节的交互收敛~~：已确认（Try 删除；运行 / 保存分开）。
2. ~~4.2 节"写到一半关了工作台"~~：已确认，写完后重新打开工作台。
3. ~~资源上限~~：已确认要设上限（不设会吃性能）；数值先按尺寸 2000 × 2000、Timer 最短 16ms、循环最多 1000 次，实测后再调。
4. ~~方括号取成员的规则~~：已确认做法 B（见第三节第 2 层）。

四项都已确认，可以从 S1 开始。

## Review fixes (2026-11-27)

The code review of feature/seedling found ways round S3; each is now a "refuse" sample in
tests/seedling/test_seedling_safety.js:
- [ ] after `}` or a number was not checked (`function() {}["con" + "structor"]`): every `[` after
  something that can end a value is a member access and checked.
- A regex after `)` of if / for / while or after `}` was read as a division, hiding code between two
  "strings": a `/` there, or a `/` followed by a quote, is refused.
- A loop counter's name used as a function / arrow / catch parameter is no longer trusted in [ ].
- Loops: the counter starts at a number or a .length, steps toward the end (`i++` / `i += n` for `<`,
  `i--` for `>`), is not changed inside, and a .length end's list is not grown inside.
- Addresses: `x.source = ...` follows the same rule as `source:`; `["open"]`, `["source"]` and `.open`
  not called at once are refused.
Yui's code prompt (rule 6) says the same.

---

## 九、P 阶段：挂件自己的设置和记忆（feature/seedling-props，2026-11-27 已确认，P1–P6 已完成，实机测试通过，已合并进 dev）

目标：让 Seedling 能做"复杂一点"的挂件——有自己的设置项（右键 Settings...），能记住东西（待办、计数）——**不放宽安全检查**：生成的代码只是"声明"，读写都由 Seedling 在沙箱外完成，代码里没有任何新的名字或接口。

### 9.1 声明格式（写在根对象最外层的 property 上一行）

```qml
// @name 天气
Rectangle {
    // @setting 城市
    property string city: "Tokyo"
    // @setting 字号 | 12 - 48
    property int fontSize: 24
    // @setting 主题 | 浅色 / 深色 / 跟随时间
    property string theme: "浅色"
    // @setting 文字颜色
    property color textColor: "white"
    // @setting 显示秒
    property bool showSeconds: true
    // @keep
    property var todos: []
}
```

| 声明 | 规则 |
| :---- | :---- |
| `// @name 名字` | 文件里任意位置一次；SAO Utils 右键菜单 / 设置里挂件的名字、Settings 窗口标题。没有就叫 Seedling |
| `// @setting 标签` | 紧接着的下一行必须是**根对象**的 `property`（不在子项里）；类型限 string / int / real / bool / color |
| `\| 最小 - 最大` | int / real：数字框（范围内）；跨度 ≤ 100 时用滑条 |
| `\| 甲 / 乙 / 丙` | string：下拉框，值只能是其中之一 |
| `// @keep` | 同上，根对象的 property；类型限 string / int / real / bool / var（var 只能存 JSON：数组、对象、字符串、数字、布尔） |

不认的写法（标在子项上、类型不对、名字是 source / url 等地址属性）：工作台 Problems 里给一条**提示**（不拦渲染），这条声明不生效；结衣写的代码有这种提示时，和编译错误一样回传给她自动改一次。解析从宽：`//@setting`、`// @setting: 标签`、中文冒号、`12-48` / `12~48`、`甲/乙` / `甲、乙` 都认。
上限：@setting 最多 20 个，@keep 最多 20 个；字符串设置 ≤ 500 字；@keep 合计 ≤ 64 KB（超出不保存，工作台提示）。

### 9.2 值从哪来、到哪去

- **解析**：新文件 `props.js`（`.pragma library`，纯函数，可单测）：`parse(code)` → `{name, settings: [{name, type, label, min, max, choices, def}], keeps: [{name, type}], notes: [...]}`。读原文：注释行 + 下一行的 property，按括号深度判断是否在根对象。
- **@setting**：值存在挂件设置 `prop_settings`（{name: value}）。挂件和工作台预览创建后，Seedling 按声明的类型转换（int 取整并夹到范围、color 只收 #RGB/#RRGGBB/#AARRGGBB 或颜色名、下拉只收选项）再 `item[name] = value`。
- **@keep**：值存在 `prop_keep`。只有**桌面上的挂件**读写：创建后赋回；**每 2 秒比较一次**这些属性的 JSON，变了就存（push、改字段也能存上，AI 不用记"重新赋值"）；挂件销毁、代码替换前再存一次。**工作台预览不读不写**（试代码不弄乱真实数据，预览里从默认值开始）。
- **改代码后**：名字和类型都没变的值保留；声明删掉或类型变了的值丢掉。
- 值只是**数据**，经类型转换后赋给属性，不会被当成代码执行；地址属性不允许声明，所以设置值也绕不过地址规则。

### 9.3 界面

- **右键菜单**（挂件有 @setting 时）：最上面 `Settings...`；bool 设置 ≤ 3 个时也直接列成可勾选的菜单项。之后才是 Workbench... / Seedling Settings...
- **Settings 窗口**（新文件 `WidgetSettings.qml`）：和结衣、Seedling Settings 同一种样式；标题「@name Settings」；按声明顺序自动生成 SAO Utils 自带的设置项：文字 → TextFieldPreference，数字 → SpinPreference / SliderPreference，开关 → SwitchPreference，颜色 → ColorPreference，选项 → SelectPreference。改了立刻生效。标题栏 Reset：设置恢复为代码里的默认值。
- 挂件有 @keep 时，窗口底部一个 **Clear Kept Data**（先确认）：清掉记住的东西，挂件回到默认值。
- 工作台：Problems 里显示不生效的声明（提示，不算错误）。

### 9.4 结衣的提示词

加一条规则：用户可能想调的东西（城市、颜色、字号、目标日期、开关）写成 `@setting`；要记住的东西（待办、计数、笔记）写成 `@keep`；挂件起一个 `@name`。声明写在根对象最外层的 property 上一行。（不需要"重新赋值"的规则：Seedling 定时比较。）

### 9.5 测试

- `tests/seedling/test_seedling_props.js`：解析（根对象 / 子项、各类型、范围、选项、错误写法、上限）、类型转换（夹范围、非法颜色、非法选项、var 的 JSON 往返、64 KB 上限）、改代码后保留规则。
- `test_seedling_safety.js`：带声明的代码照样通过 / 拦下（声明只是注释）。
- 提示词和 `props.js` 的格式一致（同 S6 的做法）。
- System Console 加 **Seedling: Settings / Keep**（假回复写一个带 @setting 和 @keep 的待办挂件）；Seedling Settings 的 Test 加 **Props** 示例。

### 9.6 顺序

P1 `props.js` + 测试 → P2 @setting 赋值 + Settings 窗口 + 右键菜单 → P3 @keep 读写 → P4 @name → P5 结衣提示词 + 测试按钮 → P6 文档。每步一个提交。

实现时的调整：SAO Utils 的 SpinPreference 只收整数，所以小数一律用滑条（有范围）或输入框（没范围）；整数跨度 ≤ 100 用滑条，否则数字框。P2–P4 互相依赖，合成一个提交。

---

## 十、Q 阶段：模板和结衣的数据（2026-11-27 已确认，分支 feature/seedling-q；Q1–Q5 已完成，实机测试通过，已合并进 dev）

背景：系统监视、电量、网速、正在播放这些已有别人的插件，Seedling 不重复做（`@data` 系统信息不做；快捷启动也不做）。Seedling 的价值是**定制**、**小而杂的需求**和**与结衣联动**。

### 10.1 A：把现有体验磨好（不加新能力）

1. **Examples 换成给用户看的模板**（高级模式的 Examples 菜单；现在的 Clock / Color Block / Animation / Broken / Unsafe / Network 是开发用的，Broken / Unsafe 移到 Seedling Settings 的 Test）：
   SAO Clock（圆环时钟）、Countdown（@setting 目标日期和标题）、Todo（@keep）、Habit（每日打卡，连续天数）、Pomodoro（@setting 时长，@keep 今日个数）、Year Progress（年 / 月 / 日进度条）、Weather（联网，@setting 城市）。每个都过安全检查和 props 解析的测试。
2. **结衣写得更好看：Widget Style**（2026-11-27 改为设置项）：像人格提示词一样，一段可编辑的文字，放在结衣 Cardinal System 的 Seedling Model 旁边。默认是 SAO 风格（橙 #F1AA03、白 / 浅灰面板、深色半透明 #E61F2630、字体 "SAO UI"、中文用默认字体、圆角、留白）；结衣每次写挂件都带上它，用户在聊天里说了风格就以用户的为准；Reset 恢复默认。
3. **模板也给结衣参考**：她写同类挂件时（时钟、倒计时、待办），提示词里附上对应模板的骨架，减少一次写错。

### 10.2 B：读结衣的数据（新能力，只读）

- **声明**：`// @yui mood` 加下一行根元素最外层的 property，和 @setting 一样由 Seedling 在沙箱外每秒（文本类每 10 秒）写入。代码里仍然没有新名字。
- **能读的**（结衣 `linkValue` 已有的）：companion_days（陪伴天数）、mood / mood_text（今天的心情）、boss_raid / raid_timer（Boss Raid 剩余）、raid_cleared、next_alarm / next_alarm_text（下一个闹钟）、quest_log（待办文本）、heart_core（结衣之心）、col_ledger（本月 token）、latest_report（最新周报）。**新增** mood_history（最近 30 天心情分数，给心情日历）。
- **隐私**：这些是你和结衣之间的数据（心情、待办、周报）。规则：**用了 @yui 的挂件不能联网**——安全检查在 Network 开着时也拒绝，提示"这个挂件读取结衣的数据，不能联网"。工作台和挂件的 Settings 窗口里列出它读了哪些。
- **没装结衣 / 结衣不在**：属性保持代码里的默认值，挂件照常显示。
- **可做的**：心情日历、陪伴天数卡片、自己设计外观的 Boss Raid 计时 / 闹钟 / 待办面板、周报摘要卡。

### 10.3 顺序

Q1 Examples 模板 + 测试 → Q2 Widget Style / Seedling Model 放进 Seedling Settings（2026-11-27：控制 Seedling 的参数都放在 Seedling 里，方便以后独立）+ 模板参考 → Q3 `@yui`（props.js 解析 + 写入 + 联网互斥 + mood_history）→ Q4 结衣提示词 + 测试按钮（心情日历）→ Q5 文档。分支 feature/seedling-templates（A）、feature/seedling-yui-data（B），或一个分支 feature/seedling-q。

---

## 十一、R 阶段：Seedling 独立写代码（2026-11-27 已确认：设置全局共用；装了结衣默认借她的连接、可切换；OpenAI 兼容 + Claude + Gemini；R1–R7 已完成，实机测试通过，已合并进 dev）

目标：没装结衣时 Seedling 也能用 AI 写挂件；装了结衣时，写代码的逻辑也只有 Seedling 一份（结衣只负责聊天里接需求、说话、汇报）。

### 11.1 搬什么

| 现在在结衣 | 搬到 Seedling | 留在结衣 |
| :---- | :---- | :---- |
| `yui.js` 的写代码函数：15 条规则、Widget Style / 模板参考、SEARCH/REPLACE 规则和应用、取代码、行差异、SEEDLING-NOTE、联网说明 | `writer.js`（`.pragma library`，纯函数，测试跟着搬） | `SEEDLING_INSTRUCTION`、`SEEDLING_FIX_PREFIX`、聊天里的进度和最后一句话（结衣的口吻） |
| `main-stand.qml` 的 `seedlingWrite`：组请求、流式、修改、重试、整段兜底、超时 | `Writer.qml`（Bench 里的一个对象）：`write(request, onProgress(state), onDone(kind, message, extra))`、`stop()` | `seedlingStart` / `seedlingSay` 变薄：调用 Bench 的 `write`，把进度翻成结衣的话 |
| 发请求 `requestCompletion` | **连接**：Seedling 自己的 `api.js`（精简版，异步 XHR，流式） | 结衣的 `requestCompletion` 不动；结衣提供 `seedlingConnection`，Seedling 可以借用 |

### 11.2 连接

- **Seedling 自己的**（`api.js`）：OpenAI 兼容（OpenAI、DeepSeek、Kimi、通义、Ollama、自定义地址）、Claude、Gemini；流式；超时 4 分钟；只做写代码需要的（system + 一条 user，不要工具调用）。
- **借结衣的**：结衣在 Bench 上登记一个连接（她的服务器、Key、Thinking 等设置），Seedling 发请求时调用它；System Console 的假回复测试仍然走这里。
- **选择**：Seedling Settings 的 **Connection**：`Yui`（装了结衣时默认）/ `Own`。没装结衣时只能用 Own；Own 没填时，工作台的描述输入框提示去 Seedling Settings 填。

### 11.3 设置放哪

现在 Seedling 的设置都存在**每个挂件**上（Widget Style、Seedling Model 也是）。API Key 不能每个挂件填一遍，所以：
- **全局**（所有 Seedling 挂件共用）：Connection、服务商、地址、API Key、模型（原 Seedling Model）、Widget Style。存在 Seedling 自己的本地数据库（LocalStorage，只有 Seedling 本身的代码能用；生成的代码被安全检查禁止用它）。已存在挂件上的 Widget Style / Seedling Model 第一次打开时搬过去。
- **每个挂件**：代码、版本、Network、@setting / @keep 的值。
- Seedling Settings 分成 **General**（全局：AI、Widget Style）和 **This Widget**（Code Editor、Network）……或保持现在的页，在标题上注明哪些是全局的。

### 11.4 界面

- 工作台底部恢复**描述输入框** + Generate：有可用连接时显示（结衣在、或 Own 已填）。
- 进度：工作台状态行已有（思考 / 编写 N 行 / 修改 N 处 / 检查）；没有结衣时，最后结果也写在状态行。
- Seedling Settings 加 **AI** 部分：Connection、Provider、Server Address、API Key、Model、Test Connection（只发一句很短的请求）。

### 11.5 安全

- API Key 只存在本地数据库，不写进挂件设置、不写日志。
- 写代码的请求仍然只有：规则、外观、模板参考、用户的要求、现有代码、程序生成的错误说明——不含网页内容。

### 11.6 顺序

R1 `writer.js`（从 yui.js 搬纯函数 + 测试）→ R2 全局设置（LocalStorage + 搬迁）→ R3 `api.js` + Test Connection → R4 `Writer.qml`（流程搬过来，连接可换）→ R5 结衣改成调用 Bench 的 write（聊天里的进度和话不变；System Console 测试照常）→ R6 工作台输入框 + Seedling Settings AI 部分 → R7 文档、翻译。分支 feature/seedling-standalone（从 feature/seedling-q 开出，Q 阶段的实机测试可以一起做）。

---

## 十二、解耦：Link 接口（2026-11-27 已确认，分支 feature/decouple；D1–D7 已完成，等实机测试）

目标：结衣和 Seedling 只通过下面这份清单互相调用，哪边内部改名都不影响另一边；以后可以分开发布、分开仓库。功能和提示词不变。

### 12.1 原则

- **只走清单**：结衣交给 Seedling 的是一个小对象 **YuiPort**（结衣的 `link/SeedlingPort.qml`），不是整个结衣；Seedling 交给结衣的是 **Bench** 里标明「Link 接口」的那一组函数。清单外的函数对方不能调。
- **版本号** `LINK_VERSION = 1`：两边各写一个。结衣找到的 Bench 版本不同时当作没装 Seedling（日志写明原因）；Seedling 拿到的 Port 版本不同时当作没有结衣。接口只增加时不改版本；改名、删除、改参数时加 1。
- **不交出密钥**：Port 不给 Seedling 结衣的 Access Key，只替它发请求。
- **没有隐式协议**：不靠聊天文字里的固定句子识别动作，一律是函数调用。
- **数据名只在结衣一处**：@yui 能读的数据由 Port 的 `dataKeys()` 给出；Seedling 的规则 15 和 `props.js` 按它生成和检查（只认 int / real / string / var 四种类型）。

### 12.2 YuiPort（结衣 → Seedling）

| 成员 | 说明 |
| :-- | :-- |
| `linkVersion` | 1 |
| `connection()` | `{ready, provider, title, model}`：结衣的连接是否配好、服务商 id 和名字、聊天用的模型。不含密钥和地址 |
| `ask(system, user, model, onDelta, onFinished)` | 用结衣的连接发一次请求（model 为空用聊天的模型）；返回 `{abort()}`。不带人格、历史、附注 |
| `models()` | `{server, models: [id], scanned, chatModel}`：结衣服务器的名字和模型列表（Scan Cores 的结果或内置）、聊天用的模型 |
| `scanModels(onDone)` / `restoreModels()` | 在结衣的服务器上 Scan Cores / Restore Registry，列表存在结衣那边；`onDone(models, error)` |
| `dataKeys()` | `{名字: {type, text}}`：@yui 可读的数据，text 是给模型看的中文说明 |
| `value(name)` | `{current, …}`；未知或关掉的功能返回 null |
| `fixWidget(problems)` | Send to Yui：打开聊天，让结衣去修 |
| `sendToChat(text)` / `prefillChat(text)` | 把文字发进聊天 / 填进输入框 |
| `font` / `panelAlpha`（属性） | 工作台跟随结衣聊天窗口的字体和不透明度（0–1） |

### 12.3 Bench 的 Link 接口（Seedling → 结衣）

| 成员 | 说明 |
| :-- | :-- |
| `linkVersion` | 1 |
| `attach(port)` / `detach(port)` | 结衣启动 / 关闭时交出 / 收回 Port |
| `attached()` | 是否已有结衣接上（之前的结衣关了，新的可以接上） |
| `widgets` / `widgetsChanged` | 桌面上的 Seedling 挂件（结衣只看有没有） |
| `write(request, onProgress, onDone)` | 写或改挂件（进度和结果由结衣在聊天里说） |
| `stop()` | 停下正在写的 |
| `ownSetup()` | Seedling 自己配好的连接（含密钥，供后装的结衣直接用，API 只配一次）；没配好为 null |

### 12.4 步骤（一步一个提交，每步检查 + 部署）

| 步 | 内容 |
| :-- | :-- |
| D1 | 本节 |
| D2 | 结衣：`link/SeedlingPort.qml`，Bench 改用 `attach(port)`；Seedling 只通过 Port 调结衣 |
| D3 | Bench 的 Link 接口归成一组 + `linkVersion`，两边检查版本；结衣只调这一组 |
| D4 | Send to Yui 改成 `fixWidget`；@yui 数据名由 `dataKeys()` 给出，规则 15 和 props.js 跟着它 |
| D5 | Seedling 专用代码搬出结衣：写代码的测试和假回复搬到 Seedling Settings → Test → Writing（`fakes.js`，Bench 自己的 `fakeReplies`）；删掉旧 `seedling_model` 迁移。结衣只留 Test Place Seedling（那是她自己的提问）；`rawSystem` 保留，它就是 Port 的 `ask`「只用这段 system」 |
| D6 | 找 Seedling 的路径只写一处。`nvg://` 包地址加载不到文件（2026-11-27 实测），只用 Packages 里相邻的文件夹 |
| D7 | `tests/yui/`、`tests/seedling/`；`check_deploy` 分插件检查，并检查两边接口清单一致；Prompt Rules 第九节搬到 Seedling 文档 |

实机测试（D5 之后）：只装结衣、只装 Seedling、两个都装，各试一次。

---

## 十三、提示词与写代码规范（从 Prompt Rules.md 第九节搬来，2026-11-27）

### 13.1 一次写代码请求的组成

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

### 13.2 安全规范（挂件代码一律当作不可信）

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

### 13.3 代码编写规范（给模型的要求，也是人写挂件的要求）

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

### 13.4 修改与重试

1. 有现有代码时用 SEARCH/REPLACE 修改；对不上的块全部不生效，带着「最接近的几行」重问。
2. 编译错误、安全检查拒绝、没生效的声明（只问一次）：带着原因重问，最多 2 次。
3. 修改两次都不行：最后要求整段重写一次（这时 system 里不再放 SEARCH/REPLACE 说明）。
4. 回复被截断：要求精简到 200 行以内重写（原为 120）。
5. 只因联网被拒：先问用户；用户不允许就结束，不偷偷改成不联网的版本。
6. 新写的挂件重试时，用户消息写「上一次写出的代码：……」+「要做的挂件：……」，不写成「要修改的地方」。
7. 安全检查和编译器的英文原文前加一句「（下面是检查程序的英文原文）」。

### 13.5 写代码规则（`writer.js codePrompt`）

原 15 条重新编排：每条只讲一件事，编号连续，冲突时写明谁优先。下面是摘要，原文见本节末尾；整段重写（13.4 第 3 条）时不带修改方式，规则 11 改为「输出完整的代码」。

1. **模块**：只能 import 13.2 列出的 6 个模块。
2. **Qt 函数**：只能用 13.2 列出的 Qt.* 函数和常量。
3. **禁止的写法**：13.2 的禁止名字；拼字符串用 +，查找用 indexOf / split。
4. **方括号**：只能是数字、写出的字段名、循环计数器 / index；按值查表用 switch 或点号。
5. **parent**：只取尺寸和锚线；要用别的元素就给它 id。
6. **循环**：只用 for，要有终点（≤ 1000 次或 .length），计数器朝终点走，循环里不改计数器、不加长列表。
7. **尺寸和频率**：根元素写明宽高（80–2000，建议不小于 80）；字号 11 以上；Timer ≥ 16 ms，显示时间用 1000，联网刷新 ≥ 10 分钟；粒子 ≤ 1000。
8. **地址**：source、.source =、open() 的地址必须以写全的 https 字符串开头；不能用 file:、qrc:、本地路径。
9. **联网**：Network 开着才可以联网（用 XMLHttpRequest）；关着时不能联网；读了结衣数据（@yui）的挂件**无论如何**不能联网（优先于本条）。
10. **自己画**：只用 QML 和 JavaScript，时间用 Timer 和 new Date()。
11. **格式**：13.3 的基本格式和注释写法；代码 ≤ 300 行，一个挂件做好一件事。
12. **不编数据**：做不到的写 `// SEEDLING-NOTE:`（import 之后），能用的部分照样写出来。
13. **设置和记忆**：@setting / @keep / @name 的写法（13.3）。
14. **外观**：按下面的「外观」写；要求里另外说了风格以要求为准。
15. **结衣的数据**（只在有结衣时）：@yui 的写法和可用名字。

<!-- seedling/prompt_doc.js: start -->

### 13.6 规则原文（由 `tests/seedling/prompt_doc.js` 从代码生成，不要手改）

#### 写新挂件（`codePrompt`，不联网，有结衣）

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
15. 结衣的数据：挂件要显示结衣这边的数据时，写在根元素最外层的 property 上，上一行写 // @yui 名字，Seedling 会自动填进去（只读）。名字只能是：companion_days（陪伴天数，int）、mood（今天心情 1-5，0 是没记录，int）、mood_text（今天心情的文字，string）、mood_history（最近 30 天心情：[{day: "yyyy-MM-dd", score: 1-5}]，var）、boss_raid（Boss Raid 剩余分钟，int）、raid_timer（Boss Raid 计时文字，string）、raid_cleared（刚打赢 Boss Raid 的几秒内是 1，int）、next_alarm（下一个闹钟还有几分钟，int）、next_alarm_text（下一个闹钟的文字，string）、quest_log（待办，每行一条，string）、heart_core（结衣之心的记忆条数，int）、col_ledger（本月用掉的 k token，real）、latest_report（最新周报，string）。用了 @yui 的挂件不能联网（规则 9）。没有数据时保持属性的默认值，所以默认值要能直接显示。
````

#### 修改挂件时多出的修改方式（`EDIT_RULES`）

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

#### 联网打开时规则 9 换成

````
9. 联网：可以用 XMLHttpRequest 联网，Image 也可以加载网络图片。拿不到数据时显示「--」或「offline」。
````

<!-- seedling/prompt_doc.js: end -->
