import { ROAM_SOURCES } from './RoamingCatalog';
import { HERITAGE_SITES } from './HeritageCatalog';

export interface PaperSource {
  id: string;
  title: string;
  url: string;
  quote: string;
  accessedAt: string;
  era: string;
}

export interface PaperCity {
  id: string;
  city: string;
  title: string;
  subtitle: string;
  question: string;
  goal: string;
  clue: string;
  // 两级提示：hint先给能立刻尝试的动作，insight再解释文化材料为什么启发这个动作。
  // 纸格范围、间距与数量属于原创玩法参数，不能写成遗址尺度或传统工艺要求。
  hint: string;
  insight: string;
  culture: string;
  sourceIds: string[];
  relatedSiteId: string;
  accent: string;
  photo: string;
  chapterId: string;
  sources: PaperSource[];
}

// 真实材料给出空间/形态关系；剪口位置、网格、支撑阈值都是原创游戏规则。
// 不把这五张纸景宣传为遗址纸模、传统工序或科学复原。材料沿用已整理出处，仍是初稿待校审。
function roamUrl(id: string): string {
  const source = ROAM_SOURCES.find(item => item.id === id);
  return source ? source.url : '';
}

function sitePhoto(id: string): string {
  const site = HERITAGE_SITES.find(item => item.id === id);
  return site && site.photos.length > 0 ? site.photos[0] : '';
}

function material(id: string, title: string, sourceId: string, quote: string, era: string): PaperSource {
  const source = ROAM_SOURCES.find(item => item.id === sourceId);
  return { id, title, url: roamUrl(sourceId), quote, accessedAt: source ? source.accessedAt : '2026-10-23', era };
}

const SMX_SOURCES: PaperSource[] = [
  material('paper-smx-courtyard', '向下打开的院落', 'roam-source-pit-house',
    '资料摘要：地坑院在黄土地表向下开挖院落。', '传统民居'),
  material('paper-smx-walls', '院壁与窑洞', 'roam-source-pit-house',
    '资料摘要：依院壁开凿窑洞，院落与周围空间共同组成居住结构。', '传统民居'),
  material('paper-smx-cut', '镂空与留白', 'roam-source-smx-paper-cut',
    '资料摘要：三门峡剪纸将生活经验与美好愿望带到纸上。本作借用镂空与留白，图案由你创作。', '地方剪纸 / 原创纸景')
];

const LY_SOURCES: PaperSource[] = [
  material('paper-ly-river', '伊河居中', 'roam-source-longmen',
    '资料摘要：龙门石窟位于伊河两岸，河流是理解这里山水空间的一条线索。', '北魏至唐等历史时期'),
  material('paper-ly-banks', '两岸山体', 'roam-source-longmen',
    '资料摘要：窟龛分布在两岸山体上。本作保留纸面的左右两岸，让河窗穿行其间。', '历史遗存 / 原创纸景'),
  material('paper-ly-look', '从山河看向人', 'roam-source-peony',
    '短引：“洛阳之俗，大抵好花。”——欧阳修《洛阳牡丹记》。赏花记述与石窟并置阅读，各自保留年代。', '北宋记述 / 当代花会资料')
];

const DAHECUN_URL: string = 'https://www.chnmus.net/sitesources/hnsbwy/page_pc/bwzl/yyhxzzjd/cpsx/article02dad096e98349b19ed9feaa402f6667.html';
const ZZ_SOURCES: PaperSource[] = [
  { id: 'paper-zz-two-mouths', title: '两口并列', url: DAHECUN_URL,
    quote: '资料摘要：大河村彩陶双连壶由两只陶壶并列连接。', accessedAt: '2026-10-25', era: '新石器时代仰韶文化' },
  { id: 'paper-zz-opening', title: '腹部的通口', url: DAHECUN_URL,
    quote: '资料摘要：腹部接合处有椭圆形通口，使两壶内部相通。这一内部关系启发了纸上的共享空腔。', accessedAt: '2026-10-25', era: '仰韶文化 / 原创纸景' },
  { id: 'paper-zz-pattern', title: '红衣与黑彩', url: DAHECUN_URL,
    quote: '资料摘要：器物为泥质红陶，采用红衣黑彩。纸色与剪口是原创表达，不以“结盟酒具”等用途解释作为判定答案。', accessedAt: '2026-10-25', era: '仰韶文化 / 用途不作定论' }
];

const KF_SOURCES: PaperSource[] = [
  material('paper-kf-lantern', '纸灯的透光', 'roam-source-lantern-zhang',
    '资料摘要：汴京灯笼张的灯彩技艺自清末以来传承。本作借纸面、镂光与支撑造景，不教授传统灯彩工序。', '清末以来灯彩 / 原创纸景'),
  material('paper-kf-night', '夜市的文字', 'roam-source-dongjing',
    '短引：“自州桥南去，当街水饭、爊肉、干脯”——《东京梦华录》卷二“州桥夜市”。', '北宋城市生活的文献记述'),
  material('paper-kf-eras', '把年代分清', 'roam-source-lantern-zhang',
    '阅读边界：北宋灯事与清末以来灯彩分属不同年代。这里的灯形、镂光位置与纸骨是原创模型。', '北宋文献与清末以来技艺分别说明')
];

const PY_SOURCES: PaperSource[] = [
  material('paper-py-shells', '离散材料，整体形象', 'roam-source-xishuipo',
    '资料摘要：西水坡发现用蚌壳摆塑的龙、虎等图案。许多小片共同形成整体形象。', '新石器时代考古材料'),
  material('paper-py-context', '图像有出土语境', 'roam-source-xishuipo',
    '资料摘要：蚌塑图案与墓葬材料共同发现。纸上的镂空轮廓为自由创作，不补绘或复原真实蚌塑细节。', '考古语境 / 原创纸景'),
  material('paper-py-boundary', '形象与解释分开', 'roam-source-xishuipo',
    '资料摘要：墓主身份与蚌图性质仍有不同解释。不把图像直接对应某个传说人物。', '考古材料 / 解释保留边界')
];

export const PAPER_CITIES: PaperCity[] = [
  { id: 'paper-smx', city: '三门峡', title: '把天光留在院子里', subtitle: '向下一剪，院落打开',
    question: '院子向下打开，四周的家怎样留下？', goal: '把中央剪开一小片天光，留下四周的院壁。',
    clue: '在中央用几道相接的短划打开一小片，不必画成方形；别只剪一圈留下会掉下的纸心。四周多留些纸，剪断了就撤回一剪。',
    hint: '在中央来回划开一小片，别只沿外圈剪；让四周仍有纸托住院子。',
    insight: '地坑院的院子在地表下，窑洞依院壁开凿。空出来的院子与留下的院壁，要一起看。',
    culture: '这张原创纸景借地坑院向下的院落、周围院壁与窑洞的关系，让你决定哪里空、哪里留；不作为民居测绘纸模或剪纸工序教学。',
    sourceIds: SMX_SOURCES.map(source => source.id), relatedSiteId: 'smx-miaodigou', accent: '#B46B4F',
    photo: sitePhoto('smx-miaodigou'), chapterId: 'roam-smx-earth-home', sources: SMX_SOURCES },
  { id: 'paper-ly', city: '洛阳', title: '让一条河穿过光', subtitle: '一线河窗，两岸山影',
    question: '河怎样流动，才让两岸都留在纸上？', goal: '从纸面上方往下剪出一条河，让左右两岸都留下。',
    clue: '从纸内偏上的河段一路往偏下的河段剪，弯着走也可以；不必碰到纸边，两旁留出宽一些的山岸。',
    hint: '先在中间剪一条长河，让它走过纸面的大半高度；河可以弯，两旁别剪空。',
    insight: '龙门石窟分布在伊河两岸的山体上。河把视线带向远处，两岸也共同构成这里的观看环境。',
    culture: '这条原创河窗借伊河与两岸山体的关系，让你为河选择走法，也为山岸留下位置；不是龙门实景剖面或造像复原。',
    sourceIds: LY_SOURCES.map(source => source.id), relatedSiteId: 'ly-longmen', accent: '#718B73',
    photo: sitePhoto('ly-longmen'), chapterId: 'roam-ly-spring', sources: LY_SOURCES },
  { id: 'paper-zz', city: '郑州', title: '两道口，同一片光', subtitle: '看得见双口，看懂内部相通',
    question: '两道开口怎样在里面相遇？', goal: '剪出左右两张小嘴，让它们在下面的肚子里相遇。',
    clue: '从左右偏上的位置分别向下剪，到了纸面中部以下再让两路相遇；上方两口之间留一点纸，别只横剪上沿。',
    hint: '先让左、右两口各自往下走，再在下面接到一起；上面仍要看得出两张嘴。',
    insight: '双连壶腹部有椭圆形通口，使两壶内部相通。两道口各自打开，里面却可以共享空间。',
    culture: '这张原创纸景借大河村双连壶腹部相通的结构，让你尝试两口怎样在里面相遇；不据此推断器物用途，也不复原器型。',
    sourceIds: ZZ_SOURCES.map(source => source.id), relatedSiteId: 'zz-dahecun', accent: '#B16E50',
    photo: sitePhoto('zz-dahecun'), chapterId: 'roam-zz-zhenwei', sources: ZZ_SOURCES },
  { id: 'paper-kf', city: '开封', title: '让灯从纸里亮起来', subtitle: '几处镂光，一副相连的纸骨',
    question: '光散开了，纸怎样仍是一盏灯？', goal: '剪出至少三扇分开的小光窗，让托住它们的纸还连在一起。',
    clue: '每扇窗划一小段，点一下只会留下针孔；让几扇窗隔开，分布到纸面不同方向，窗与窗之间留下纸路。',
    hint: '先在相隔较远的地方各划一小段，再添第三扇；别把几扇窗剪成一圈。',
    insight: '灯要让光透出，也要让纸面留得住形状。北宋灯事与清末以来灯彩各有年代，这盏纸灯由你原创。',
    culture: '这盏原创纸灯把透光与留纸变成可以尝试的取舍。北宋灯事与清末以来灯彩分别阅读；光窗数量、灯形与纸骨要求都是游戏设计。',
    sourceIds: KF_SOURCES.map(source => source.id), relatedSiteId: 'kf-zhouqiao', accent: '#B47A45',
    photo: sitePhoto('kf-iron-pagoda'), chapterId: 'roam-kf-night', sources: KF_SOURCES },
  { id: 'paper-py', city: '濮阳', title: '让碎光连成一个形象', subtitle: '片片分开，目光相连',
    question: '不连成一条剪缝，也能让人看见整体吗？', goal: '用至少六段分开的碎光，围出一条宽一些、有起伏的轮廓。',
    clue: '用短划或小弧一段段往前走，段与段之间留纸，但别远远散到四角；让轮廓向两侧伸开，也向上、下起伏，不必照描龙虎。',
    hint: '剪六段以上短小的弧或线，让相邻碎光靠近；可以围成弧环，也可以走一条起伏的折线。',
    insight: '西水坡蚌塑用许多独立蚌片组成整体形象。这里借“分开又相望”来创作，你不用复制真实的龙或虎。',
    culture: '西水坡蚌塑让许多独立材料组成整体形象，这一关系启发了原创碎光轮廓；不复刻真实蚌塑，也不把你的图案作为考古解释。',
    sourceIds: PY_SOURCES.map(source => source.id), relatedSiteId: 'py-xishuipo', accent: '#66887E',
    photo: sitePhoto('py-xishuipo'), chapterId: 'roam-py-dragon-memory', sources: PY_SOURCES }
];

export function paperCityForId(cityId: string): PaperCity | undefined {
  return PAPER_CITIES.find(city => city.id === cityId);
}
