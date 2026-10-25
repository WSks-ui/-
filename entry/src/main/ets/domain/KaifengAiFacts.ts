// 开封 AI 的封闭事实集。AI 只能引用这里的事实；不在表内的年代、数字、地名
// 一律视为无依据。每条都给出可展开的原文/考古表述与来源，界面点“看原文”用。
//
// 边界：这是“校书”用的依据表，不是完整史料库；石壁纹样与原石拓片、州桥形制
// 都不在本表内作复原性描述。

export interface KaifengAiFact {
  id: string;
  title: string;
  text: string;
  quote: string;
  sourceId: string;
  // 画面锚点：bridge / section / motif / market / lantern。
  anchor: string;
  // 逐句接地用的关键词。模型改写后的句子至少命中一个，才算“有出处”。
  // 关键词只收事实表里出现过的名词与术语，避免把常识词当成依据。
  keywords: string[];
}

export const KAIFENG_AI_FACTS: KaifengAiFact[] = [
  {
    id: 'zf-low-flat',
    title: '州桥低平不通舟船',
    text: '州桥正对御街，桥身低平，不通舟船；只有西河平船可以通行。',
    quote: '其桥与相国寺桥皆低平不通舟船，唯西河平船可过。',
    sourceId: 'roam-source-dongjing',
    anchor: 'bridge',
    keywords: ['州桥', '低平', '不通舟船', '平船', '御街', '西河']
  },
  {
    id: 'zf-stone-piles',
    title: '桥下密排石柱',
    text: '桥柱用青石，桥下密排石柱，因为这里是车驾经过的御路。',
    quote: '其柱皆青石为之……桥下密排石柱，盖车驾御路也。',
    sourceId: 'roam-source-dongjing',
    anchor: 'bridge',
    keywords: ['石柱', '青石', '车驾', '御路']
  },
  {
    id: 'zf-ming-arch',
    title: '明代改建单孔拱桥',
    text: '现揭露的桥体是明代早期砖石单孔拱桥，建在宋代桥基之上。',
    quote: '现发现的桥体为明代早期建造，压在更早的桥基之上。',
    sourceId: 'roam-source-zhouqiao',
    anchor: 'section',
    keywords: ['明代', '单孔', '拱桥', '桥基', '宋代']
  },
  {
    id: 'zf-silt-burial',
    title: '明末黄河淤埋',
    text: '明末崇祯十五年黄河决口，州桥与汴河故道被泥沙淤埋。',
    quote: '明末崇祯十五年（1642）被黄河洪水泥沙淤埋。',
    sourceId: 'roam-source-zhouqiao',
    anchor: 'section',
    keywords: ['明末', '崇祯', '黄河', '淤埋', '泥沙']
  },
  {
    id: 'zf-stone-wall',
    title: '石壁海马双鹤祥云',
    text: '州桥东侧汴河两岸发现北宋石雕祥瑞壁画，雕刻海马、仙鹤、祥云；一组图案为一匹海马、两只仙鹤环以祥云。',
    quote: '近桥两岸皆石壁，雕镌海马水兽飞云之状。',
    sourceId: 'roam-source-dongjing',
    anchor: 'motif',
    keywords: ['石壁', '海马', '仙鹤', '祥云', '壁画']
  },
  {
    id: 'zf-night-market',
    title: '州桥夜市三样吃食',
    text: '州桥夜市自州桥向南，当街有水饭、爊肉、干脯。',
    quote: '自州桥南去，当街水饭、爊肉、干脯。',
    sourceId: 'roam-source-dongjing',
    anchor: 'market',
    keywords: ['夜市', '水饭', '爊肉', '干脯', '州桥']
  },
  {
    id: 'zf-lantern-zhang',
    title: '灯笼张与北宋灯事分属不同年代',
    text: '北宋灯事见于《东京梦华录》；汴京灯笼张的灯彩技艺形成于清末，两者年代不同。',
    quote: '《东京梦华录》所记的北宋灯事，属于节俗文献；灯笼张灯彩技艺形成于清末。',
    sourceId: 'roam-source-lantern-zhang',
    anchor: 'lantern',
    keywords: ['灯笼张', '清末', '北宋', '灯事', '灯彩']
  }
];

export interface KaifengAiStarter {
  id: string;
  label: string;
  question: string;
  anchor: string;
}

export const KAIFENG_AI_STARTERS: KaifengAiStarter[] = [
  { id: 'ask-bridge', label: '州桥为什么是平的', question: '州桥为什么低平，船从哪里过？', anchor: 'bridge' },
  { id: 'ask-section', label: '同一处怎么有三个年代', question: '宋桥、明桥和淤埋层是怎么叠在一起的？', anchor: 'section' },
  { id: 'ask-motif', label: '石壁上刻的是什么', question: '石壁上的海马、仙鹤和祥云怎么排列？', anchor: 'motif' },
  { id: 'ask-market', label: '夜市卖什么', question: '州桥夜市的三样吃食是什么？', anchor: 'market' }
];

export function kaifengAiFactFor(id: string): KaifengAiFact | undefined {
  return KAIFENG_AI_FACTS.find((fact: KaifengAiFact) => fact.id === id);
}
