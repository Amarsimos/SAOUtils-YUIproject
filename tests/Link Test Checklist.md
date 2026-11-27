# Link 接口实机测试清单

结衣（MHCP-YUI）和 Seedling 解耦（`Seedling Development Plan.md` 第十二节）之后，在 SAO Utils 里逐项检查。除了 A9、B5 和 E 的第一条会用到你配置的 AI，其他都不发请求，不花 token。

- System Console 在结衣的右键菜单里；Seedling Settings 在 Seedling 挂件的右键菜单里。
- Test Seedling Link 的结果同时写进 `SAO Utils 2\Storages\yui\seedling-link.txt`。

## A. 两个都装（结衣开着，桌面上放一个 Seedling 挂件）

| # | 操作 | 应该看到 | 结果 |
| :-- | :-- | :-- | :-- |
| A1 | System Console → **Test Seedling Link** | `resolve nvg://seedling.widget.amarsimos.com/link/bench: com.amarsimos.widget.seedling \| link`；`found at nvg://...`、`Link version 1 (Yui 1)`、`attached: true`、`widgets:` 等于桌面上的 Seedling 挂件数；两边的 AI | ✅ 2026-11-27 |
| A2 | Seedling Settings → Test → **Link Status** | MHCP-YUI 已接上、她的 AI、`Her data: 13 names`、`Writing uses: MHCP-YUI's AI` | |
| A3 | **Yui's Data** | 13 行（companion_days、mood……），开着的功能有值，关掉的是 null | |
| A4 | **Send to Yui** | 结衣的聊天打开，先出现「帮我修好这个挂件：…」，再显示进度，最后说做好了；工作台里出现一个时钟 | |
| A5 | Writing → **Write**，再点 **Edit** | 工作台写出时钟；Edit 只改一个颜色，橙色标出改动的行 | |
| A6 | Writing → **Fix** | 先出一次错，再自动修好 | |
| A7 | Writing → **Network** | 弹出是否允许联网的询问 | |
| A8 | Writing → **Mood Calendar** | 挂件显示最近的心情（@yui 读到了结衣的数据） | |
| A9 | 工作台出错时，点 Problems 里的 **Send to Yui** | 和 A4 一样，但用真实 AI 修 | |
| A10 | Seedling Settings → **Link** 页 | 显示结衣的服务器和模型列表；Scan Cores 和 Restore Registry 能用 | |
| A11 | 工作台的字体和不透明度 | 跟随结衣 Equipment 里的设置 | |

## B. 假装没有结衣（Seedling Settings → Test → 打开 **Pretend No Yui**）

| # | 操作 | 应该看到 | 结果 |
| :-- | :-- | :-- | :-- |
| B1 | **Link Status** | `MHCP-YUI: hidden (Pretend No Yui)`，`Writing uses: Seedling's own AI` | |
| B2 | **Yui's Data** | 「No MHCP-YUI: @yui values stay the code's defaults.」 | |
| B3 | **Send to Yui** | 按钮变灰，点不了 | |
| B4 | Writing → **Mood Calendar** | 挂件能显示，用的是代码里的默认值，不报错 | |
| B5 | 在工作台输入框写需求，按回车 | 用 Seedling 自己的 API 写（Link 页没配好时提示去配） | |

测完关掉 Pretend No Yui。

## C. 只装结衣（把 Seedling 从 Packages 移走，或者在 SAO Utils 里停用）

| # | 操作 | 应该看到 | 结果 |
| :-- | :-- | :-- | :-- |
| C1 | 结衣启动后，System Console → **Test Seedling Link** | `resolve ...: null (not installed)`，然后是 `not found ...; Yui works without it` | |
| C2 | Log | 有 `seedling: not installed (no nvg://...)`，没有报错 | |
| C3 | 聊天里说"做个时钟挂件" | 思考中不出字，也不先说「收到」；只出一条她自己的话：Seedling 的权限还在沉睡，要先装上 Seedling 程序包、放到桌面上。Log：`seedling: asked for a widget, missing`，接着 `missing (asked again)` 不应出现 | |
| C4 | 结衣开着时停用 Seedling，再点 **Test Seedling Link** | `resolve ...: null`，然后 `not found`；Log 有 `seedling: no longer installed` | |
| C5 | 再启用 Seedling，点两次 **Test Seedling Link** | 第一次可能还是 not found（正在加载），第二次 `found at ...` | |
| C6 | 装着 Seedling、她正在写一个挂件时，再让她做另一个 | 同 C3，只出一条她自己的话：上一个还在培育中 | |
| C7 | 装着 Seedling、桌面上有挂件，让她做挂件 | 没有「收到」这类回复，思考的占位原地变成进度消息（「在想…」），然后写出来 | |
| C8 | 她还在思考时，再发一条消息（回车） | 消息马上显示，下面标着「⏳ 排队中：结衣回完上一条就发送」；回复结束后标记消失、消息发出；Log：`message queued`，之后 `queued message(s) sent` | |
| C9 | 她写挂件时发一条普通聊天 | 照常回复，不会再要一次挂件（聊天记录顺序：做挂件 → 进度 → 你的消息） | |
| C10 | 有消息在排队时点 **Cancel** | 回复停下；排队的消息从聊天里撤回，文字回到输入框（多条按行合并，原来输入框里的字接在后面），不会再发出；Log：`cancel: N queued message(s) back in the input field` | |

## D. 只装 Seedling（关掉结衣挂件：结衣不在桌面上就当没有她）

| # | 操作 | 应该看到 | 结果 |
| :-- | :-- | :-- | :-- |
| D1 | **Link Status** | `MHCP-YUI: not running`，`Writing uses: Seedling's own AI` | |
| D2 | Writing 组各按一遍 | 和 A5–A7 一样能走通 | |
| D3 | 重新放上结衣，再点 **Link Status** | 显示已接上 | |

## E. 回归

| # | 操作 | 应该看到 | 结果 |
| :-- | :-- | :-- | :-- |
| E1 | 聊天里让结衣写一个挂件（用真实 AI） | 聊天里有进度，最后说完成 | |
| E2 | 往小拖 Seedling 挂件的框 | 拖到挂件本身大小就停住 | |
| E3 | 周报、开机问候、深夜和休息提醒 | 照常 | |

有哪一项不对：记下编号；有 Log 的话，附上 `seedling` 开头的那些行。
