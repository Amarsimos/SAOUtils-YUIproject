# 测试

这些脚本不属于挂件本身：`cp.bat` 只复制 `com.amarsimos.widget.yui/`，所以它们不会被复制到 SAO Utils，也不会打进 `.nvg`。需要 Node.js 18 以上版本。

## 单元测试

```
node tests/test_yui.js
```

测试 `qml/yui.js` 里与界面无关的逻辑：标签解析、工具调用转换、记忆、搜索地址、Markdown 显示、提示词规则等。改了 `yui.js` 以后都应该跑一遍。

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
