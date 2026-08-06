# docs/copy — App UI English 键值源

产品用户可见 UI 串的 **English 工程源**（非运行时包、非 8 语译库）。策略见 CONTEXT **Product Copy Source** / **Localization Policy**；决策见 ADR **0053**；locale 闭集见 **0047 / 0048**。

## 文件

| 文件 | 职责 |
|---|---|
| [`en.yaml`](./en.yaml) | 唯一权威 **English** 键值表（P0 + 壳层） |
| [`acceptance-by-screen.md`](./acceptance-by-screen.md) | **按屏验收表**：hi-fi 帧 ↔ key（设计收口 / 实现前走查） |
| `README.md`（本文件） | 治理与约定 only — **不**写具体串 |

**不在此目录：** GTM 商店文案（`gtm/`）、营销站长文（`website/`）、机翻产物（实现期进各端 catalog 或 `generated/`，不得覆盖 `en.yaml` 权威）。

## 条目形状

```yaml
- key: home.idle.status
  en: Not Connected
  tier: shell          # shell | lock-en
  surface: home        # optional if derivable from key prefix
  notes: "optional; lock-en should cite ADR/CONTEXT when non-obvious"
```

## Key 约定

- 逻辑名：`surface.slot`（小写 ASCII、点分层）
- Android 资源名：`.` → `_`（如 `home_idle_status`）
- 通用壳：`chrome.*`
- **key 稳定、value 可变**；禁止用英文短句当 key（改措辞会迫使重命名）
- 插值占位（平台无关）：`{name}` · `{count}` · `{date}` · `{displayName}` 等

## Tier

| tier | 含义 | 改 value 时权威 | 机翻（非 en） |
|---|---|---|---|
| `shell` | 导航、按钮、空态、列表壳、行名等 | current hi-fi（重大 IA 仍要 ADR） | 上架前可无人审机翻 |
| `lock-en` | 诊断主文案/四桶、Repair、隐私关键句、付费墙等 | CONTEXT / 相关 ADR | **不**硬译；缺合格译文回落 en |

## 生命周期

1. **种子（开工前）：** 填满 P0 闭集 + 壳层；key / en / tier 齐。
2. **实现期：** 改用户可见 English → **先改 `en.yaml` → 再灌** iOS String Catalog / Android `strings`。禁止只改一端 app 内硬编码英文字符串。
3. **上架前：** 对 `tier: shell` 批量机翻闭集 locale；`lock-en` 保持 en 或显式回落。
4. **生成器：** yaml → xcstrings/xml 按需；非本目录前置。

## 首版与后续填充

- **收编：** CONTEXT · ADR · `design/hi-fi/current/craft-p0/` · 线框文案锚点中**已出现**的产品句。
- **壳层补齐：** 仅 `chrome.*` 与明显平台通用用语可用中性 English 补全。
- **禁止：** 临场创作 lock-en 业务/信任句；把未定 P1/P2 编进表冒充完成。

## 范围边界

**在表内：** Home / Setup / Add Subscription / Subscriptions / Settings（已定闭集）/ Diagnostic sheet / Repair UI / Help 壳与 Can·Can’t / 通用 chrome。

**不在表内：** LLM 对话正文、商店 listing、官网 Brand Presence 段落、协议法律全文（仅 App 内链标题/副文）。

## 对 hi-fi 的收编

种子已对照 `design/hi-fi/current/craft-p0/`（02–07）收编 + 壳层补齐。  
`diag.example.*` / `help.chat.example.*` 为 **hi-fi 场景样例**（引擎模板可后换），不是「每种失败唯一正文」。

校验（本地）：

```bash
python3 -c "import yaml; d=yaml.safe_load(open('docs/copy/en.yaml')); assert len(d['strings'])==len({s['key'] for s in d['strings']})"
```

实现期发现缺 key：补 `en.yaml` 再灌双端，不要只在一端硬编码。
