# 音乐课堂小游戏生成 Skill

主文件：`SKILL.md`

这个 Skill 用于把“音乐教学目标 + 作品/谱例/音频材料”转成可直接课堂使用的小游戏，默认输出为离线单文件 HTML。

## 推荐调用方式

把整个文件夹交给支持 SKILL.md 的代理/编码环境，然后提出类似请求：

- “用 music-classroom-mini-game skill，把《蓝花花》管弦乐版的配器层次做成 5 分钟听辨游戏，初二，投屏+手机可用。”
- “用这个 skill，根据我上传的谱例第 9—14 小节做左右手动作化聆听游戏，离线单文件网页。”
- “用这个 skill，为 3/4 拍设计一个学生可自主改编、能回听比较的节奏游戏。”

## 文件

- `SKILL.md`：完整生成流程、路由、音乐规则与验收门槛。
- `scripts/validate_game.py`：对单文件 HTML 做静态 + 浏览器烟雾测试。
- `examples/G3_小切分侦探_单文件网页版.html`：由该 Skill 的流程生成的独立测试样例。
- `tests/QA_REPORT.md`：实际运行结果。

## 验收命令

```bash
python scripts/validate_game.py examples/G3_小切分侦探_单文件网页版.html
```
