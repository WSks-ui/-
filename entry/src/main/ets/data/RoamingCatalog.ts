import type { RoamChapter, RoamSource } from '../domain/Roaming';

// 首发内容均随包离线提供。官方网页仅作出处，不下载或随包分发网页配图。
// 2026-10-23 已读取下列官方正文；本轮是编辑整理，继续保留“初稿待校审”。
// 新篇章与旧 22 条档案使用不同身份，relatedSiteIds 仅提供延伸入口，不建立历史传承链。
// 2026-10-24：开封三条线索按《东京梦华录》卷一「河道」改为史料版：
// 州桥低平不通舟船、桥下密排石柱、车驾御路；第二幕改为宋基—明桥—明末淤埋，
// 并加入石壁残纹与州桥夜市三摊。玩法与正文都变了，内容修订号推进到 3。
// 旧记忆保留其冻结的 contentRevision，不追改。
export const ROAM_CONTENT_REVISION: number = 3;
export const ROAM_REVIEW_STATUS: string = '初稿待校审';

export const ROAM_SOURCES: RoamSource[] = [
  {
    id: 'roam-source-miaodigou', title: '国家文物局·庙底沟遗址资料',
    url: 'http://www.ncha.gov.cn/art/2022/3/19/art_2587_75.html', accessedAt: '2026-10-23'
  },
  {
    id: 'roam-source-pit-house', title: '中国非物质文化遗产网·地坑院营造技艺',
    url: 'https://www.ihchina.cn/project_details/14687.html', accessedAt: '2026-10-23'
  },
  {
    id: 'roam-source-smx-paper-cut', title: '中国非物质文化遗产网·三门峡剪纸保护资料',
    url: 'https://www.ihchina.cn/tenyear_protect_detail/20025.html', accessedAt: '2026-10-23'
  },
  {
    id: 'roam-source-longmen', title: '河南省人民政府·龙门石窟资料',
    url: 'https://m.henan.gov.cn/2026/08-06/3383102.html', accessedAt: '2026-10-23'
  },
  {
    id: 'roam-source-peony', title: '中国非物质文化遗产网·洛阳牡丹花会',
    url: 'https://www.ihchina.cn/project_details/15243.html', accessedAt: '2026-10-23'
  },
  {
    id: 'roam-source-water-banquet', title: '中国非物质文化遗产网·洛阳水席制作技艺',
    url: 'https://www.ihchina.cn/project_details/14669.html', accessedAt: '2026-10-23'
  },
  {
    id: 'roam-source-zhenghan', title: '河南省人民政府·郑韩故城与溱洧资料',
    url: 'https://m.henan.gov.cn/2025/03-10/3134723.html', accessedAt: '2026-10-23'
  },
  {
    id: 'roam-source-zhouqiao', title: '中国历史研究院·州桥及附近汴河遗址资料',
    url: 'http://hrczh.cass.cn/ywdt/dt/202502/t20250228_5849988.shtml', accessedAt: '2026-10-23'
  },
  {
    // 州桥“低平不通舟船”与“州桥夜市”均出自本书；引用卷一「河道」、卷二「州桥夜市」。
    id: 'roam-source-dongjing', title: '维基文库·《东京梦华录》卷一「河道」、卷二「州桥夜市」',
    url: 'https://zh.wikisource.org/zh-hans/%E6%9D%B1%E4%BA%AC%E5%A4%A2%E8%8F%AF%E9%8C%84', accessedAt: '2026-10-24'
  },
  {
    id: 'roam-source-lantern-zhang', title: '中国非物质文化遗产网·汴京灯笼张',
    url: 'https://www.ihchina.cn/project_details/14067.html', accessedAt: '2026-10-23'
  },
  {
    id: 'roam-source-xishuipo', title: '中国社会科学网·西水坡蚌塑龙虎资料',
    url: 'https://www.cssn.cn/lsx/lsx_kgx/202210/t20221024_5552751.shtml', accessedAt: '2026-10-23'
  },
  {
    id: 'roam-source-cangjie-fair', title: '南乐县人民政府·仓颉庙会与地方记忆资料',
    url: 'http://www.nanle.gov.cn/content/2024/856209.html', accessedAt: '2026-10-23'
  }
];

export const ROAM_CHAPTERS: RoamChapter[] = [
  {
    id: 'roam-smx-earth-home', city: '三门峡', title: '黄土里的家', kicker: '第一城 · 从日常出发',
    subtitle: '从一片陶土、一座院落，到亲手选下的窗花。',
    opening: '如果把宏大的历史放远一点，黄河岸边的人怎样过日子？沿着陶窑、院落和纸上的愿望，寻找一个家的轮廓。',
    closing: '一片陶土、一处院落、一纸愿望，组成生活的不同切面。史前聚落、传统民居与剪纸各有自己的年代；这一页把你的观察留在它们之间。',
    accent: '#B76B45', scene: 'smx-home', relatedSiteIds: ['smx-miaodigou', 'smx-yangshao', 'smx-xipo'],
    sourceIds: ['roam-source-miaodigou', 'roam-source-pit-house', 'roam-source-smx-paper-cut'],
    clues: [
      {
        id: 'roam-smx-life', title: '把陶器放回生活里', goal: '在聚落里找到制作与居住的线索',
        instruction: '点画面中的“作”和“居”，看看陶窑与房屋怎样组成日常，再选一条想带走的观察。',
        body: '庙底沟遗址的房址、壕沟和陶窑，留下了史前聚落生活的线索。陶器也可以放回制作与日常使用的环境中观察：人们在哪里居住，又在哪里制作器物？画面是帮助寻找关系的原创示意。',
        era: '仰韶文化时期 · 考古资料', sourceIds: ['roam-source-miaodigou'], mode: 'find',
        options: [
          { id: 'smx-clay', label: '留住陶土的线索', detail: '把器物与制作它的聚落环境放在一起观察。' },
          { id: 'smx-home', label: '留住房屋的线索', detail: '从居住与生产的位置，想象日常生活需要怎样的空间。' }
        ]
      },
      {
        id: 'roam-smx-pit-house', title: '院子藏在地表之下', goal: '揭开地表，找到地坑院的院落与窑洞',
        instruction: '拖动遮罩，看院子怎样向地下展开，再选一个最想记住的空间关系。',
        body: '地坑院是在黄土地表向下开挖院落，再依院壁开凿窑洞的传统民居。它回应了当地的土质与居住需要。本条讲传统民居营造，与上一条史前聚落分别标明年代；示意中的结构用于理解空间。',
        era: '传统民居 · 非遗营造技艺', sourceIds: ['roam-source-pit-house'], mode: 'reveal',
        options: [
          { id: 'smx-courtyard', label: '记住向下的院落', detail: '地表下展开的院子，是理解地坑院空间的入口。' },
          { id: 'smx-cave', label: '记住围院的窑洞', detail: '窑洞依院壁开凿，院与居室共同组成生活空间。' }
        ]
      },
      {
        id: 'roam-smx-paper-cut', title: '为纸页添一扇窗', goal: '选择一枚原创窗花，让自己的纸页亮起来',
        instruction: '试选不同窗花，观察镂空与留白，再确认想留在这一页的图案。',
        body: '三门峡剪纸把生活经验和美好愿望带到纸上。本页借剪纸的镂空与留白设计了三枚原创窗花，供你选择装点纪念画面；它们是云河纪的创作，不作为传统纹样名称或传承人的作品介绍。',
        era: '民间美术 · 当代传承资料', sourceIds: ['roam-source-smx-paper-cut'], mode: 'decorate',
        options: [
          { id: 'smx-sun', label: '一轮暖阳', detail: '原创圆形窗花，留下一点温暖与明亮。' },
          { id: 'smx-river', label: '一湾河水', detail: '原创水纹窗花，把沿河行走的心情留在纸上。' },
          { id: 'smx-branch', label: '一枝新叶', detail: '原创枝叶窗花，给这一页添一点生长的愿望。' }
        ]
      }
    ]
  },
  {
    id: 'roam-ly-spring', city: '洛阳', title: '这一城春色，为谁而开', kicker: '第二城 · 山水与相聚',
    subtitle: '沿伊河看石窟，摘一句赏花记述，再读一席汤羹。',
    opening: '一座城的春色，除了花，还会留下些什么？从伊河两岸走进洛阳，让山水、赏花与一桌饭依次进入你的景窗。',
    closing: '山水石窟、北宋赏花记述与今日传承的水席，来自不同的历史层次。你的春日尾页把它们并置，留下这一回最想记住的城市日常。',
    accent: '#AA687E', scene: 'ly-spring', relatedSiteIds: ['ly-longmen', 'ly-hanwei', 'ly-erlitou'],
    sourceIds: ['roam-source-longmen', 'roam-source-peony', 'roam-source-water-banquet'],
    clues: [
      {
        id: 'roam-ly-longmen', title: '让伊河进入景窗', goal: '移动景窗，看见山、河与石窟的相对位置',
        instruction: '沿伊河方向拨动景窗，让两岸山体进入视野，再选择你想保留的观看角度。',
        body: '龙门石窟分布在伊河两岸的山体上，石窟与河流共同构成这里的观看环境。先把视线放在山与水的关系，再进入具体造像和营造年代。这里的远景是原创叙事示意，延伸档案可继续查看龙门资料。',
        era: '北魏至唐等时期 · 石窟资料', sourceIds: ['roam-source-longmen'], mode: 'window',
        options: [
          { id: 'ly-river', label: '从河面望向两岸', detail: '让伊河成为进入龙门山水环境的一条线。' },
          { id: 'ly-cliff', label: '从山体寻找石窟', detail: '记住石窟依山而开的空间关系，再继续读造像资料。' }
        ]
      },
      {
        id: 'roam-ly-peony', title: '摘下一句赏花记述', goal: '沿文字移动，找到欧阳修写下的洛阳日常',
        instruction: '拨开花影，读出这一句，再选择想从句子里留下的意思。',
        body: '“洛阳之俗，大抵好花。”——欧阳修《洛阳牡丹记》。中国非物质文化遗产网的洛阳牡丹花会资料引用了这段北宋记述。短短一句把目光带向人们的赏花日常；后面的解释是本篇编辑导读。',
        era: '北宋记述 / 当代花会资料', sourceIds: ['roam-source-peony'], mode: 'excerpt',
        options: [
          { id: 'ly-flowers', label: '留下“好花”二字', detail: '把城市的春色读成一种日常的喜爱。' },
          { id: 'ly-people', label: '留下赏花的人', detail: '从一句风俗记述里，想到参与其中的人们。' }
        ]
      },
      {
        id: 'roam-ly-water-banquet', title: '让春日落在一席之间', goal: '打开汤羹线索，组合自己的春日尾页',
        instruction: '选择一片尾页，看看汤羹与相聚怎样改变纸上的春日景象。',
        body: '洛阳水席制作技艺把汤羹、菜肴和上菜节奏组织成一席饮食经验。读过山水与赏花，再把目光落到人们围坐的一桌饭。本页以原创汤碗和花影收束，不提供菜单、价格或当日活动信息。',
        era: '传统饮食技艺 · 当代传承资料', sourceIds: ['roam-source-water-banquet'], mode: 'compose',
        options: [
          { id: 'ly-broth', label: '留一碗暖汤', detail: '以汤羹作春日尾页的中心，记住生活里的温度。' },
          { id: 'ly-gathering', label: '留一席相聚', detail: '以围坐的关系收束这一城，记住一起赏春的心情。' },
          { id: 'ly-petal', label: '留一片花影', detail: '让赏花的文字与汤碗旁的原创花影在纸上相遇。' }
        ]
      }
    ]
  },
  {
    id: 'roam-zz-zhenwei', city: '郑州', title: '溱洧河边，去赴一次相会', kicker: '第三城 · 诗与城市生活',
    subtitle: '从一座城门走进古城，沿着字词寻找水与人的线索。',
    opening: '如果古城有一封邀请，它会从哪里开始？选一道门，沿水读一句诗，再为这次纸上的相会留下自己的片段。',
    closing: '城门提供空间，诗句留下声音的文字，礼乐器物补充古城生活的材料。你选择的相会片段属于这次阅读，不代表复原了古人的某一天。',
    accent: '#547D80', scene: 'zz-meeting', relatedSiteIds: ['zz-zhenghan', 'zz-shang', 'zz-dahecun', 'zz-duling-fangding'],
    sourceIds: ['roam-source-zhenghan'],
    clues: [
      {
        id: 'roam-zz-gates', title: '从哪一道门进城', goal: '辨认水门与陆门，把通行线索接入古城',
        instruction: '移动入口观察窗，让河道与城门相接，再选一道想继续进入的门。',
        body: '郑韩故城的北城门考古发现包括陆门与水门。门不只是城墙上的一个缺口，也提示了城内外通行与水系之间的联系。本页以原创小景帮助辨认关系，具体遗迹继续由档案与出处说明。',
        era: '春秋战国 · 城址考古资料', sourceIds: ['roam-source-zhenghan'], mode: 'gate',
        options: [
          { id: 'zz-water-gate', label: '沿水门进入', detail: '让水的方向成为理解古城通行的一条线索。' },
          { id: 'zz-land-gate', label: '沿陆门进入', detail: '从城墙与道路的连接，观察城内外的关系。' }
        ]
      },
      {
        id: 'roam-zz-poem', title: '在字词之间找到水', goal: '沿诗句寻找“溱”“洧”与水势的联系',
        instruction: '沿河拨动文字，让水名进入景窗，再选择想摘下的一小段意思。',
        body: '“溱与洧，方涣涣兮。”——《诗经·郑风·溱洧》。河南省人民政府的郑韩故城资料引用了这一首句。本篇以水名和水势作为阅读入口；画面中的相会片段是编辑叙事，不充作古城实景复原。',
        era: '《诗经》文本 · 先秦文学线索', sourceIds: ['roam-source-zhenghan'], mode: 'words',
        options: [
          { id: 'zz-river-names', label: '记住两条水名', detail: '从“溱与洧”进入诗歌与地方的联系。' },
          { id: 'zz-flowing', label: '记住流动的字句', detail: '沿“方涣涣兮”的文字，留住水势带来的阅读感受。' }
        ]
      },
      {
        id: 'roam-zz-zheng-song', title: '给相会留一段回声', goal: '把诗、乐与城市线索收成一张相会纸页',
        instruction: '选择一段想留住的画面，让相会片段在古城与河水间展开。',
        body: '郑韩故城发现的编钟等器物，为认识古城礼乐生活提供了材料。“郑声”在本篇是进入诗、乐与城市生活的叙事题名。纸页用文字与画面留下回声，不播放未经核实的复原古乐，也不把出土器物对应到某支曲子。',
        era: '东周器物资料 / 当代编辑叙事', sourceIds: ['roam-source-zhenghan'], mode: 'echo',
        options: [
          { id: 'zz-riverside', label: '在河边相会', detail: '以水和字词作这次阅读的中心，留下纸上的相会。' },
          { id: 'zz-city-light', label: '在城门停一刻', detail: '让通行的空间与人的交往在原创画面中相接。' },
          { id: 'zz-words', label: '把一句诗带走', detail: '留住已注明篇名的首句，继续读诗歌中的地方记忆。' }
        ]
      }
    ]
  },
  {
    id: 'roam-kf-night', city: '开封', title: '点亮汴京的一夜', kicker: '第四城 · 叠城寻路',
    subtitle: '州桥低平，御街过得去，汴河的船另找走法。',
    opening: '一幅还没定案的纸页：桥低平，车驾要过，船却进不了桥洞。先读清州桥为什么这样造，再往下看同一处的三个年代。',
    closing: '州桥低平不通舟船，是御街与漕运分工的结果；宋基、明桥、明末淤埋叠在同一处，石壁留下海马与双鹤；夜市的三处摊，靠你的灯亮起来。北宋文献与清末以来灯彩各有年代，眼前这一盏属于你的原创纪念画面。',
    accent: '#B78342', scene: 'kf-night', relatedSiteIds: ['kf-zhouqiao', 'kf-city-wall', 'kf-iron-pagoda', 'kf-fanta'],
    sourceIds: ['roam-source-zhouqiao', 'roam-source-dongjing', 'roam-source-lantern-zhang'],
    clues: [
      {
        id: 'roam-kf-crossing', title: '州桥为什么是平的', goal: '让御街的车驾过得去，也给汴河的船找到走法',
        instruction: '拖动桥片与铜环，把桥对准街口；点桥型切换平桥或拱桥；再把高桅船拖到东岸泊位。',
        body: '《东京梦华录》卷一「河道」记州桥「正对于大内御街，其桥与相国寺桥皆低平不通舟船，唯西河平船可过……桥下密排石柱，盖车驾御路也」。北宋的州桥是低平平桥：御街的车驾要平过，桥下密排石柱；高桅船不从这一段过。现揭露的单孔拱桥属于明代改建。本页的桥长、街宽与泊位是原创示意和玩法参数，不是州桥形制、桥梁尺度或汴河断面的复原。',
        era: '北宋 · 御街与汴河', sourceIds: ['roam-source-zhouqiao', 'roam-source-dongjing'], mode: 'bridge',
        options: [
          { id: 'kf-street-river', label: '记住街河交会', detail: '从州桥所在的位置，观察城市道路与水道的联系。' },
          { id: 'kf-follow-water', label: '沿着水线继续', detail: '把汴河作为阅读开封城市空间的一条线。' }
        ]
      },
      {
        id: 'roam-kf-layers', title: '同一处，三个年代', goal: '把宋、明、明末三片材料叠到剖面上，说清它们的顺序',
        instruction: '把宋代桥基、明代桥体、明末淤埋拖到下、中、上三条层带；层位齐后，再按「一匹海马、两只仙鹤环以祥云」拼好石壁残纹。',
        body: '州桥及附近汴河遗址的发掘，把桥、河道与不同时期的遗存放在同一处：现揭露的桥体为明代早期砖石单孔拱桥，建于宋代桥基之上；明末崇祯十五年黄河决口，州桥与汴河故道被泥沙淤埋。桥东汴河两岸还发现北宋石雕祥瑞壁画，雕刻海马、仙鹤、祥云，与《东京梦华录》「近桥两岸皆石壁，雕镌海马水兽飞云之状」相印证。本页剖面与残纹是阅读示意，不表示实测剖面、原石拓片或全城地层。',
        era: '多期城市遗存 · 考古层位线索', sourceIds: ['roam-source-zhouqiao'], mode: 'layers',
        options: [
          { id: 'kf-bridge-layers', label: '留住桥的层次', detail: '让今天看到的遗存，带出不同时期的城市问题。' },
          { id: 'kf-city-memory', label: '留住同一处城市', detail: '记住位置与时间的叠合，继续读开封的城市记忆。' }
        ]
      },
      {
        id: 'roam-kf-lantern', title: '把灯挂进州桥夜市', goal: '点亮桥头、水边、街口三处摊',
        instruction: '拖动三盏灯，照到水饭、爊肉、干脯三处摊；灯骨与灯纸可点选，最后选一个想留下的祝愿。',
        body: '《东京梦华录》卷二「州桥夜市」记「自州桥南去，当街水饭、爊肉、干脯」；北宋灯事与清末以来汴京灯笼张的灯彩技艺分属不同年代。本页的水饭、爊肉、干脯三摊取自夜市条，灯形、纸面、照亮半径与摆法是云河纪的原创纸灯模型和玩法参数，不是宋代灯制复原，也不是非遗工序教学。',
        era: '北宋夜市文献 / 清末以来灯彩技艺', sourceIds: ['roam-source-dongjing', 'roam-source-lantern-zhang'], mode: 'light',
        options: [
          { id: 'kf-river-safe', label: '愿河路安澜', detail: '点亮原创水纹灯，把沿河行走的祝愿写进画面。' },
          { id: 'kf-home-warm', label: '愿灯火可亲', detail: '点亮原创圆灯，留住街巷里温暖的光。' },
          { id: 'kf-new-page', label: '愿此页常新', detail: '点亮原创折纸灯，让这一夜成为下一段探索的起点。' }
        ]
      }
    ]
  },
  {
    id: 'roam-py-dragon-memory', city: '濮阳', title: '龙乡的故事，怎样留到今天', kicker: '第五城 · 遗存、传说与今日',
    subtitle: '从蚌塑龙虎，到造字传说，再到仍在被讲述的地方记忆。',
    opening: '一个故事可以怎样留下来？先找蚌壳摆出的图案，再走进地方传说的纪念空间，看看今日的人怎样继续讲述。',
    closing: '蚌塑龙虎是考古材料，仓颉造字属于传说，庙会是今日仍在传承的民俗。三种材料各自承载记忆，你留下的“龙乡回声”记录的是这次理解与选择。',
    accent: '#5F7A57', scene: 'py-memory', relatedSiteIds: ['py-xishuipo', 'py-cangjie', 'py-qicheng'],
    sourceIds: ['roam-source-xishuipo', 'roam-source-cangjie-fair'],
    clues: [
      {
        id: 'roam-py-shell', title: '在蚌壳之间找到形象', goal: '移动观察窗，辨认蚌塑龙与虎的形态',
        instruction: '沿蚌壳线条移动景窗，让龙与虎依次进入视野，再选下最吸引你的观察。',
        body: '西水坡遗址的墓葬中发现了用蚌壳摆塑的龙、虎图案。这些形象是认识史前观念与图像表达的考古材料。先观察线条与整体形态，再读资料中的解释；本页轮廓为原创示意，不补绘遗物细节。',
        era: '仰韶文化时期 · 墓葬考古资料', sourceIds: ['roam-source-xishuipo'], mode: 'trace',
        options: [
          { id: 'py-dragon', label: '留住龙的轮廓', detail: '从蚌壳组成的整体形象入手，记住这条考古图像线索。' },
          { id: 'py-tiger', label: '留住虎的轮廓', detail: '比较两种形象的线条，让观察先于解释。' }
        ]
      },
      {
        id: 'roam-py-cangjie', title: '走进传说的纪念空间', goal: '拨开字影，把仓颉传说与地方纪念联系起来',
        instruction: '移动字影观察窗，找到传说与纪念空间的连接，再选择想保留的线索。',
        body: '仓颉造字是地方长期讲述的传说。南乐的仓颉纪念空间与庙会资料，保存了人们纪念造字、讲述地方故事的方式。本条作为传说与民俗记忆阅读，不把传说人物或造字过程当作考古定论。',
        era: '造字传说 · 地方纪念与民俗', sourceIds: ['roam-source-cangjie-fair'], mode: 'characters',
        options: [
          { id: 'py-character-memory', label: '记住文字的想象', detail: '把造字传说作为人们解释文字来处的一种文化记忆。' },
          { id: 'py-place-memory', label: '记住纪念的空间', detail: '观察人们怎样借一处地方保存并讲述故事。' }
        ]
      },
      {
        id: 'roam-py-fair', title: '让今日的讲述留下回声', goal: '从庙会资料中选择一条线索，完成龙乡回声',
        instruction: '试选想留下的记忆，让蚌纹、字影或相聚的人进入你的收束纸页。',
        body: '仓颉庙会的当代资料，让地方记忆进入今天的讲述与参与。回看这一城，考古遗存、造字传说和民俗活动分别提供不同材料。选一条想继续了解的线索，形成自己的“龙乡回声”；这不表示你已经到访。',
        era: '当代民俗资料 · 个人阅读选择', sourceIds: ['roam-source-cangjie-fair', 'roam-source-xishuipo'], mode: 'remember',
        options: [
          { id: 'py-shell-echo', label: '把蚌纹带走', detail: '以考古图像收束这一页，继续追问形象怎样留下。' },
          { id: 'py-word-echo', label: '把字影带走', detail: '以传说与文字的想象收束这一页，继续读地方记忆。' },
          { id: 'py-people-echo', label: '把相聚带走', detail: '以今日的讲述和参与收束这一页，记住文化仍由人来传递。' }
        ]
      }
    ]
  }
];
