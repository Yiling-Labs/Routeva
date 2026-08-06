# Privacy / About 内容闭集（修订：隐私不进根页）

**Status：** accepted（2026-08-06 修订：About 闭集补 **iOS iCloud 披露** + Links 含 Support + **MT 次要披露**；与 CONTEXT / ADR **0054** / hi-fi `05-settings` About 对齐）

**About ›（根页 App 入口）闭集（自上而下）：**

1. **产品名 + 版本**  
2. **一句隐私承诺**（English 源 · `settings.about.privacy_promise`；**不**写绝对 never upload / never leave device）  
3. **iOS · 一句 iCloud 披露**（`settings.about.icloud_exceptions`）：Domain exceptions 可经**用户自己的 iCloud** 备份以便重装/换机；**非**开关、**非**全量配置同步、**非** Routeva 服务器。权威机制见 ADR **0054**。**Android 省略本行**（Platform Gap）。  
   - **产品意图：** 与「Privacy first / temporary help」并读，避免用户误以为例外列表也绝不离开本机。  
   - **非 App Review 硬勾选项：** 苹果不要求 About 单独出这一句；**必须**的是可访问 Privacy Policy 与真实行为一致。本句属 About **产品闭集**，不是营养标签替代物。  
4. **Links**（系统浏览器，**非**应用内长文）：  
   - **Privacy Policy** → **`https://routeva.yilinglabs.com/privacy/`**（副文 *How we handle your data*）  
   - **Terms of Use** → **`https://routeva.yilinglabs.com/terms/`**（副文 *Rules for using Routeva*）  
   - **Support** → 外链发现性（hi-fi：同源站点 Contact，如 `/privacy/#contact`；实现可换正式 support 入口）  
5. **次要：机翻披露**（`settings.about.mt_disclosure` · lock-en）—*Some interface text may be machine-translated. Critical explanations stay in English.* 字阶弱于承诺句；**无**每屏 MT 横幅。见 CONTEXT **Localization Policy**。  
6. **次要：Export diagnostic report**（脱敏）  

**明确不做：** 连点 Advanced；Beta 不强制 Rate/Share；根页独立 **Privacy ›**（见 **0034**）；Overrides 页 iCloud 主开关或常驻云状态条。

**Privacy Policy / Terms：** 权威正文在 **website/**（`/privacy/` · `/terms/`），与 Cloudflare Pages 站点同源。

**为何：** 根页不挂 Privacy/Terms 长文；Web 单一权威源便于审核与更新；About 保留承诺 + **iOS 备份边界** + 外链发现性 + **壳层机翻边界**，与 0054 / Localization Policy 同源、与 hi-fi 单源。

**后果：** CONTEXT **Settings Surface** About 条 · Localization Policy；ADR **0034** / **0054**；copy `settings.about.*`；hi-fi `05-settings.html` About 帧。
