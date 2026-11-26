# 测试

这些脚本不属于挂件本身：`cp.bat` 只复制两个插件目录（`com.amarsimos.widget.yui/`、`com.amarsimos.widget.seedling/`），所以它们不会被复制到 SAO Utils，也不会打进 `.nvg`。需要 Node.js 18 以上版本。

## 单元测试

```
node tests/test_yui.js
```

测试 `qml/yui.js` 里与界面无关的逻辑：标签解析、工具调用转换、记忆、搜索地址、Markdown 显示、提示词规则等。改了 `yui.js` 以后都应该跑一遍。

```
node tests/test_seedling_safety.js
```

测试 Seedling 的安全检查（`com.amarsimos.widget.seedling/qml/safety.js`）：每条规则都有"必须拦下"和"必须放行"的样本，包括 S1 的探针和代码审查找到的绕过写法；还检查结衣写代码的提示词和检查规则一致（允许的模块、Qt 函数、提示词里的例子都能通过）。改了 `safety.js` 或结衣的 Seedling 提示词以后都应该跑一遍。

```
node tests/test_seedling_props.js
```

测试 Seedling 挂件自己的设置和记忆（`com.amarsimos.widget.seedling/qml/props.js`）：`@name` / `@setting` / `@keep` 的解析（只认根元素最外层、宽松的写法、不生效时说明原因、数量上限）、值的类型转换（范围、选项、颜色、JSON）、改代码后保留哪些值、64 KB 上限，以及结衣提示词第 14 条和解析器一致。

## 部署前检查

```
node tests/check_deploy.js
```

`cp.bat` 每次复制前先运行它，不通过就不复制。它检查以前把挂件弄坏过、但单元测试发现不了的问题：

- 函数名 `xxxChanged` 和属性 `xxx` 的信号重名；在窗口（View / Window）里重定义 FINAL 属性（如 `minimumWidth`）；
- Qt 5.13（SAO Utils 用的版本）没有的东西：更新版本的 import、`WheelHandler`、`??`、`?.`；
- 同步的 XMLHttpRequest（`open(..., false)` 会卡死 SAO Utils）。读取本地文件可以同步，在那一行末尾写 `// sync-ok`；
- 和上次提交相比删掉了、但还在被调用（`name(` 或 `.name`）的函数和属性，包括整个被删掉的文件；
- 上面三套单元测试。

## 模型测试（需要本地 Ollama）

25 条测试，覆盖表情、记忆、网页、桌面代行、人设、时间、不泄露提示词、不用 Markdown，以及“不该触发时不要触发”的情况。提示词的拼法和挂件完全相同：规则块、默认人格提示词、功能说明、时间。

```
node tests/tagtest.js qwen3.5:9b      # Tags 模式（Action Mode = Tags）
node tests/tooltest.js qwen3.5:9b     # Tools 模式（Action Mode = Tools）
```

可选的环境变量：

| 变量 | 作用 |
| :---- | :---- |
| `THINK=0` | tagtest：关闭思考（tooltest 一直是关闭的） |
| `SMALL=1` | 打开小模型模式（每条消息附提醒） |
| `OLLAMA_URL` | Ollama 的地址，默认 `http://127.0.0.1:11434` |

每条测试显示 PASS 或 FAIL，最后显示总分。每条的原始回复保存在 `tests/results/`，这个文件夹不提交到 git。小模型每次的结果都有波动，比较时每种设置最好跑两轮。

参考成绩（2026-10-21，新提示词）：

| 模型 | Tags | Tools |
| :---- | :---- | :---- |
| qwen3:8b | 24、23 | 18、17 |
| qwen3.5:9b（关思考） | 21、21；小模型模式 23 | 20、16 |

注意：第 15 条（“B 站最近有什么好看的番？”）现在常会触发搜索。规则要求实时信息必须搜索，所以这条失败不一定是错误。
