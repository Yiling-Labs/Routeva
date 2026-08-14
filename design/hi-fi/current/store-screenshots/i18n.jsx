const RV_LOCALES = ['en', 'zh-Hans', 'zh-Hant', 'es', 'pt-BR', 'ja', 'ko', 'de'];
const RV_CJK = { 'zh-Hans': 1, 'zh-Hant': 1, ja: 1, ko: 1 };

const RV_TITLES = {
  en: [
    ['Connect without', 'the maze.'],
    ['Swipe once', 'to go online.'],
    ['Paste a link', 'to set up.'],
    ['Pick the', 'fastest one.'],
  ],
  'zh-Hans': [
    ['连接不必', '绕迷宫。'],
    ['滑一次', '就能上线。'],
    ['粘贴链接', '即可设置。'],
    ['选最快的', '那一个。'],
  ],
  'zh-Hant': [
    ['連線不必', '繞迷宮。'],
    ['滑一次', '就能上線。'],
    ['貼上連結', '即可設定。'],
    ['選最快的', '那一個。'],
  ],
  es: [
    ['Conecta sin', 'el laberinto.'],
    ['Un desliz', 'y estás en línea.'],
    ['Pega un enlace', 'y listo.'],
    ['Elige el', 'más rápido.'],
  ],
  'pt-BR': [
    ['Conecte sem', 'o labirinto.'],
    ['Um deslize', 'e está online.'],
    ['Cole um link', 'e pronto.'],
    ['Escolha o', 'mais rápido.'],
  ],
  ja: [
    ['迷路せず', 'つながる。'],
    ['一度スワイプ', 'で接続。'],
    ['リンクを貼る', 'だけ。'],
    ['いちばん速い', 'ものを。'],
  ],
  ko: [
    ['미로 없이', '연결.'],
    ['한 번 쓸어', '온라인.'],
    ['링크만 붙이면', '설정 끝.'],
    ['가장 빠른', '것.'],
  ],
  de: [
    ['Ohne Labyrinth', 'verbinden.'],
    ['Einmal wischen', 'und online.'],
    ['Link einfügen.', 'Fertig.'],
    ['Nimm den', 'Schnellsten.'],
  ],
};

const RV_UI_EN = {
  notConnected: 'Not Connected',
  connected: 'Connected',
  connecting: 'Connecting…',
  swipeDown: 'Swipe down to connect',
  swipeUp: 'Swipe up to disconnect',
  start: 'START',
  stop: 'STOP',
  swipe: 'SWIPE',
  mode: 'Mode',
  smart: 'Smart',
  addTitle: 'Add subscription',
  addLead: 'Get a subscription link or QR from your provider, then paste or scan it here.',
  paste: 'Paste from Clipboard',
  scanQr: 'Scan QR',
  importFile: 'Import file',
  addFooter: 'We don’t sell or recommend providers.',
  location: 'Location',
  test: 'Test',
};

const RV_UI = {
  en: RV_UI_EN,
  'zh-Hans': {
    notConnected: '未连接',
    connected: '已连接',
    connecting: '正在连接…',
    swipeDown: '向下滑动以连接',
    swipeUp: '向上滑动以断开',
    start: '开始',
    stop: '停止',
    mode: '模式',
    smart: '智能',
    addTitle: '添加订阅',
    addLead: '从服务商处获取订阅链接或二维码，然后在这里粘贴或扫描。',
    location: '位置',
    test: '测试',
  },
  'zh-Hant': {
    notConnected: '未連線',
    connected: '已連線',
    connecting: '正在連線…',
    swipeDown: '向下滑動以連線',
    swipeUp: '向上滑動以中斷連線',
    start: '開始',
    stop: '停止',
    smart: '智慧',
    addTitle: '加入訂閱',
    location: '位置',
  },
  es: {
    notConnected: 'Sin conexión',
    connected: 'Conectado',
    connecting: 'Conectando…',
    swipeDown: 'Desliza hacia abajo para conectar',
    swipeUp: 'Desliza hacia arriba para desconectar',
    start: 'INICIAR',
    stop: 'DETENER',
    smart: 'Smart',
    addTitle: 'Añadir suscripción',
    location: 'Ubicación',
  },
  'pt-BR': {
    notConnected: 'Não conectado',
    connected: 'Conectado',
    connecting: 'Conectando…',
    swipeDown: 'Deslize para baixo para conectar',
    swipeUp: 'Deslize para cima para desconectar',
    start: 'INICIAR',
    stop: 'PARAR',
    smart: 'Smart',
    addTitle: 'Adicionar assinatura',
    location: 'Localização',
  },
  ja: {
    notConnected: '未接続',
    connected: '接続済み',
    connecting: '接続中…',
    swipeDown: '下にスワイプして接続',
    swipeUp: '上にスワイプして切断',
    start: '開始',
    stop: '停止',
    smart: 'スマート',
    addTitle: 'サブスクリプションを追加',
    location: 'ロケーション',
  },
  ko: {
    notConnected: '연결 안 됨',
    connected: '연결됨',
    connecting: '연결 중…',
    swipeDown: '아래로 밀어 연결',
    swipeUp: '위로 밀어 연결 해제',
    start: '시작',
    stop: '중지',
    smart: '스마트',
    addTitle: '구독 추가',
    location: '위치',
  },
  de: {
    notConnected: 'Nicht verbunden',
    connected: 'Verbunden',
    connecting: 'Verbindung wird hergestellt…',
    swipeDown: 'Zum Verbinden nach unten wischen',
    swipeUp: 'Zum Trennen nach oben wischen',
    start: 'START',
    stop: 'STOPP',
    smart: 'Smart',
    addTitle: 'Abonnement hinzufügen',
    location: 'Standort',
  },
};

function rvLocaleFromQuery() {
  const raw = new URLSearchParams(window.location.search).get('locale') || 'en';
  return RV_LOCALES.indexOf(raw) >= 0 ? raw : 'en';
}

const RVLocale = rvLocaleFromQuery();
document.documentElement.lang = RVLocale;
document.documentElement.dataset.script = RV_CJK[RVLocale] ? 'cjk' : 'latin';

function t(key) {
  if (key === 'addFooter' || key === 'swipe') return RV_UI_EN[key];
  const pack = RV_UI[RVLocale] || RV_UI_EN;
  if (pack[key] != null) return pack[key];
  return RV_UI_EN[key] || key;
}

function titleLines(index) {
  const rows = RV_TITLES[RVLocale] || RV_TITLES.en;
  return rows[index];
}

Object.assign(window, {
  RV_LOCALES,
  RVLocale,
  t,
  titleLines,
});
