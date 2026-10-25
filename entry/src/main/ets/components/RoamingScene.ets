import { RoamingTheme as R } from './RoamingTheme';

interface ScenePoint { x: number; y: number; }

// 原生画布中的五城是原创叙事图景，不是遗址测绘、历史建筑或蚌塑布局的复原。
// 每一帧由线索、用户的拨动位置与选择派生；没有后台播放的“假发现”定时器。
// 记忆预览使用完成态（amount=100），不冒充曾经取景的精确中间位置。
@Component
export struct RoamingScene {
  @Prop @Watch('draw') scene: string = 'smx-home';
  @Prop @Watch('draw') stage: number = 0;
  @Prop @Watch('draw') amount: number = 0;
  @Prop @Watch('draw') choice: number = -1;
  @Prop @Watch('draw') found: string[] = [];
  @Prop @Watch('draw') illuminated: boolean = false;
  @Prop sceneHeight: number = 360;
  @Prop interactive: boolean = true;
  onMove: (value: number) => void = () => {};
  onSpot: (id: string) => void = () => {};
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private ready: boolean = false;
  private widthVp: number = 360;
  private heightVp: number = 360;
  private panStart: number = 0;

  private polygon(points: ScenePoint[], color: string, line: string = ''): void {
    const c = this.context;
    c.beginPath();
    points.forEach((point: ScenePoint, index: number) => {
      if (index === 0) c.moveTo(point.x, point.y); else c.lineTo(point.x, point.y);
    });
    c.closePath(); c.fillStyle = color; c.fill();
    if (line) { c.strokeStyle = line; c.lineWidth = 1.5; c.stroke(); }
  }

  private ellipse(x: number, y: number, rx: number, ry: number, color: string): void {
    const c = this.context;
    c.save(); c.translate(x, y); c.scale(rx, ry);
    c.beginPath(); c.arc(0, 0, 1, 0, Math.PI * 2); c.fillStyle = color; c.fill(); c.restore();
  }

  private line(x: number, y: number, x2: number, y2: number, color: string, width: number = 2): void {
    const c = this.context;
    c.beginPath(); c.moveTo(x, y); c.lineTo(x2, y2); c.strokeStyle = color; c.lineWidth = width; c.stroke();
  }

  private sky(dark: boolean = false): void {
    const c = this.context;
    c.fillStyle = dark ? '#173E3D' : '#E8EBDD'; c.fillRect(0, 0, 1000, 760);
    this.ellipse(785, 126, 62, 62, dark ? '#F1D79E' : '#E5CE98');
    // 低透明细纹保持纸感；位置固定，缩放和拖动不会出现随机闪烁。
    c.strokeStyle = dark ? '#31524A' : '#D9DECE'; c.lineWidth = 1;
    for (let y = 17; y < 760; y += 16) {
      c.beginPath(); c.moveTo(0, y); c.lineTo(1000, y + 4); c.stroke();
    }
    c.fillStyle = dark ? '#2D544A' : '#CED9BF';
    c.beginPath(); c.moveTo(-40, 340);
    c.bezierCurveTo(70, 210, 160, 300, 230, 195); c.bezierCurveTo(330, 60, 415, 220, 490, 260);
    c.bezierCurveTo(630, 115, 730, 250, 810, 290); c.bezierCurveTo(940, 130, 1000, 245, 1050, 220);
    c.lineTo(1050, 540); c.lineTo(-40, 540); c.closePath(); c.fill();
    c.fillStyle = dark ? '#376552' : '#88AA89';
    c.beginPath(); c.moveTo(-20, 400); c.bezierCurveTo(80, 220, 165, 250, 250, 370);
    c.bezierCurveTo(360, 250, 470, 270, 585, 380); c.bezierCurveTo(720, 260, 830, 330, 1030, 300);
    c.lineTo(1030, 680); c.lineTo(-20, 680); c.closePath(); c.fill();
  }

  private hill(x: number, y: number, width: number, height: number, color: string): void {
    const c = this.context;
    c.beginPath(); c.moveTo(x - width, y); c.bezierCurveTo(x - width * 0.6, y - height * 0.12,
      x - width * 0.45, y - height, x, y - height);
    c.bezierCurveTo(x + width * 0.5, y - height * 0.96, x + width * 0.6, y - height * 0.05, x + width, y);
    c.closePath(); c.fillStyle = color; c.fill();
    for (let index = 0; index < 5; index++) {
      c.beginPath(); c.moveTo(x - width * 0.3 + index * width * 0.15, y - height * 0.8);
      c.quadraticCurveTo(x + index * width * 0.11, y - height * 0.4, x + width * 0.4 + index * width * 0.06, y - 12);
      c.strokeStyle = '#5F8E78'; c.lineWidth = 2; c.globalAlpha = 0.35; c.stroke(); c.globalAlpha = 1;
    }
  }

  private river(): void {
    const c = this.context;
    c.beginPath(); c.moveTo(-50, 592); c.bezierCurveTo(155, 405, 335, 590, 483, 476);
    c.bezierCurveTo(625, 367, 775, 445, 1050, 346); c.lineTo(1050, 587);
    c.bezierCurveTo(810, 575, 650, 540, 530, 639); c.bezierCurveTo(370, 755, 130, 570, -50, 800);
    c.closePath(); c.fillStyle = '#3E806F'; c.fill();
    c.beginPath(); c.moveTo(-30, 635); c.bezierCurveTo(185, 450, 375, 637, 510, 518);
    c.bezierCurveTo(665, 415, 780, 480, 1030, 397); c.strokeStyle = '#AFC6A2'; c.lineWidth = 3; c.stroke();
    for (let index = 0; index < 12; index++) {
      const x = 55 + index * 88; const y = 571 + Math.sin(index * 0.7) * 35 - index * 9;
      c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x + 20, y - 7, x + 43, y + 1);
      c.strokeStyle = '#8FB69B'; c.lineWidth = 2; c.globalAlpha = 0.7; c.stroke(); c.globalAlpha = 1;
    }
  }

  private tree(x: number, y: number, scale: number = 1, blossom: boolean = false): void {
    const c = this.context; c.save(); c.translate(x, y); c.scale(scale, scale);
    this.line(0, 0, -2, -75, '#586E4F', 8); this.line(-2, -45, -38, -90, '#586E4F', 4);
    this.line(-2, -55, 32, -103, '#586E4F', 4);
    this.ellipse(-36, -97, 41, 30, blossom ? '#D9997B' : '#6D9872');
    this.ellipse(27, -112, 44, 36, blossom ? '#E5B69A' : '#8FAA7A');
    this.ellipse(-5, -134, 39, 28, blossom ? '#E5B69A' : '#7AA079');
    this.ellipse(2, -86, 46, 30, blossom ? '#E6B091' : '#7AA079'); c.restore();
  }

  private person(x: number, y: number, color: string = '#E7D9AC', scale: number = 1): void {
    const c = this.context; c.save(); c.translate(x, y); c.scale(scale, scale);
    this.ellipse(0, -39, 7, 8, '#B69068');
    this.polygon([{ x: -8, y: -29 }, { x: 7, y: -29 }, { x: 13, y: -4 }, { x: -14, y: -4 }], color);
    this.line(-5, -2, -8, 9, '#4F6757', 3); this.line(5, -2, 7, 9, '#4F6757', 3); c.restore();
  }

  private house(x: number, y: number, scale: number = 1): void {
    const c = this.context; c.save(); c.translate(x, y); c.scale(scale, scale);
    this.polygon([{ x: -49, y: -6 }, { x: -49, y: -57 }, { x: 45, y: -57 }, { x: 45, y: -6 }], '#D3B582');
    this.polygon([{ x: -70, y: -55 }, { x: -15, y: -114 }, { x: 67, y: -55 }], '#8B8860');
    for (let index = 0; index < 8; index++) this.line(-50 + index * 13, -56, -14 + index * 6, -105, '#B7AA78', 2);
    c.fillStyle = '#626D4D'; c.fillRect(-12, -38, 25, 32);
    this.line(-50, -4, 50, -4, '#9B9A6B', 3); c.restore();
  }

  private pavilion(x: number, y: number, scale: number = 1, dark: boolean = false): void {
    const c = this.context; c.save(); c.translate(x, y); c.scale(scale, scale);
    this.line(-39, -4, -39, -73, dark ? '#B59060' : '#BFA579', 7);
    this.line(40, -4, 40, -73, dark ? '#B59060' : '#BFA579', 7);
    this.polygon([{ x: -66, y: -71 }, { x: -38, y: -85 }, { x: 0, y: -117 },
      { x: 39, y: -85 }, { x: 68, y: -71 }], dark ? '#416E5A' : '#466F57');
    this.line(-69, -70, 70, -70, '#BBC59A', 4);
    this.line(-53, 1, 54, 1, '#C7B58B', 8); this.line(-56, 11, 58, 11, '#D8C79F', 5);
    this.line(-39, -29, 41, -29, '#8B8C60', 3); c.restore();
  }

  private boat(x: number, y: number, scale: number = 1): void {
    const c = this.context; c.save(); c.translate(x, y); c.scale(scale, scale);
    this.polygon([{ x: -48, y: 0 }, { x: -29, y: 18 }, { x: 31, y: 18 }, { x: 49, y: -2 }], '#D3B984');
    this.line(-50, 0, 50, 0, '#E7DBB1', 3);
    this.polygon([{ x: -17, y: -3 }, { x: -13, y: -33 }, { x: 17, y: -31 }, { x: 24, y: -4 }], '#6F8060');
    this.line(32, 1, 56, -35, '#D5C298', 3); c.restore();
  }

  private blossom(x: number, y: number, size: number, color: string): void {
    for (let petal = 0; petal < 8; petal++) {
      const angle = petal * Math.PI / 4;
      this.ellipse(x + Math.cos(angle) * size * 0.58, y + Math.sin(angle) * size * 0.58, size * 0.45, size * 0.45, color);
    }
    this.ellipse(x, y, size * 0.25, size * 0.25, '#C9A75C');
  }

  private grain(x: number, y: number, scale: number = 1): void {
    const c = this.context; c.save(); c.translate(x, y); c.scale(scale, scale);
    for (let stem = 0; stem < 5; stem++) {
      const dx = stem * 9 - 18; this.line(dx, 15, dx - 10, -47 - stem * 3, '#8F9A57', 2);
      for (let seed = 0; seed < 5; seed++) {
        this.ellipse(dx - 13 + seed * 1.5, -15 - seed * 7 - stem * 3, 5, 3, '#D3B761');
        this.ellipse(dx - 4 + seed * 1.5, -18 - seed * 7 - stem * 3, 5, 3, '#D3B761');
      }
    }
    this.line(-22, 4, 25, 2, '#9C6D47', 4); c.restore();
  }

  private kiln(x: number, y: number, highlighted: boolean): void {
    const c = this.context; c.save(); c.translate(x, y);
    c.beginPath(); c.moveTo(-53, 8); c.bezierCurveTo(-62, -78, 60, -86, 58, 5);
    c.closePath(); c.fillStyle = '#B48B5E'; c.fill();
    c.beginPath(); c.moveTo(-25, 8); c.lineTo(-24, -11); c.arc(0, -11, 24, Math.PI, 0);
    c.lineTo(24, 8); c.closePath(); c.fillStyle = highlighted ? '#AD6E43' : '#6E7351'; c.fill();
    this.line(-54, 9, 59, 8, '#D7BD8B', 4);
    c.fillStyle = '#8E7253'; c.fillRect(-10, -72, 23, 14);
    // 陶窑轮廓是通用学习符号，大小、结构和位置不表示庙底沟某座陶窑的实测资料。
    for (let index = 0; index < 3; index++) {
      const px = -41 + index * 41;
      c.beginPath(); c.moveTo(px - 8, 28); c.bezierCurveTo(px - 20, -3, px + 20, -3, px + 8, 28);
      c.closePath(); c.fillStyle = highlighted ? '#B0764E' : '#A58C62'; c.fill();
    }
    c.restore();
  }

  private pitHouse(): void {
    const c = this.context;
    this.sky();
    this.hill(160, 450, 280, 130, '#BEBA82');
    c.fillStyle = '#C8BC8B'; c.fillRect(0, 418, 1000, 342);
    this.polygon([{ x: 205, y: 420 }, { x: 610, y: 327 }, { x: 821, y: 444 }, { x: 431, y: 573 }], '#9D9266');
    this.polygon([{ x: 249, y: 427 }, { x: 612, y: 353 }, { x: 612, y: 535 }, { x: 431, y: 584 }], '#BAA277');
    this.polygon([{ x: 612, y: 353 }, { x: 771, y: 446 }, { x: 613, y: 559 }, { x: 612, y: 535 }], '#978765');
    this.polygon([{ x: 249, y: 427 }, { x: 430, y: 527 }, { x: 771, y: 446 }, { x: 613, y: 559 },
      { x: 431, y: 614 }, { x: 249, y: 513 }], '#D4BF8F');
    this.polygon([{ x: 309, y: 479 }, { x: 612, y: 409 }, { x: 699, y: 456 }, { x: 431, y: 548 }], '#E7D4A7');
    // 窑洞只表达“下沉院落与四周房间”的关系；数量与开口不是特定民居的测绘数据。
    for (let index = 0; index < 3; index++) {
      const x = 362 + index * 77; const y = 439 - index * 17;
      c.beginPath(); c.moveTo(x - 20, y + 40); c.lineTo(x - 20, y + 8);
      c.bezierCurveTo(x - 20, y - 20, x + 20, y - 28, x + 20, y);
      c.lineTo(x + 20, y + 31); c.closePath(); c.fillStyle = '#6D7255'; c.fill();
    }
    this.person(490, 502, '#B45B40', 0.9); this.tree(650, 450, 0.55);
    if (this.choice === 0) {
      this.line(309, 479, 431, 548, '#EFE0AB', 5); this.line(431, 548, 699, 456, '#EFE0AB', 5);
    } else if (this.choice === 1) {
      for (let index = 0; index < 3; index++) this.ellipse(362 + index * 77, 460 - index * 17, 27, 30, '#33F0DB9B');
    }
    for (let stair = 0; stair < 6; stair++) this.line(698 - stair * 12, 470 + stair * 11,
      741 - stair * 12, 490 + stair * 11, '#9E956D', 3);
    const coverY = 302 + this.amount * 3.7;
    if (this.amount < 96) {
      c.save(); c.beginPath(); c.rect(170, coverY, 680, 760 - coverY); c.clip();
      this.polygon([{ x: 180, y: 422 }, { x: 610, y: 321 }, { x: 849, y: 442 }, { x: 430, y: 646 }], '#D3C28F');
      for (let index = 0; index < 12; index++) this.line(220 + index * 45, 445, 265 + index * 45, 475, '#B9AD7C', 2);
      c.restore();
      this.line(180, coverY, 850, coverY, '#F1E4BA', 5);
    }
    this.tree(175, 457, 0.8); this.tree(827, 455, 0.6);
  }

  private paperFlower(x: number, y: number, scale: number, type: number): void {
    const c = this.context; c.save(); c.translate(x, y); c.scale(scale, scale);
    c.strokeStyle = '#AF513B'; c.lineWidth = 5;
    if (type === 1) {
      c.beginPath(); c.arc(0, 0, 67, 0, Math.PI * 2); c.stroke();
      c.save(); c.beginPath(); c.arc(0, 0, 60, 0, Math.PI * 2); c.clip();
      for (let index = 0; index < 5; index++) {
        c.beginPath(); c.moveTo(-72, -46 + index * 23); c.bezierCurveTo(-23, -78 + index * 23,
          20, -17 + index * 23, 75, -48 + index * 23); c.lineWidth = 8; c.stroke();
      }
      c.restore(); c.restore(); return;
    }
    if (type === 2) {
      c.beginPath(); c.arc(0, 0, 67, 0, Math.PI * 2); c.stroke();
      c.beginPath(); c.moveTo(-4, 58); c.bezierCurveTo(13, 18, -11, -21, 0, -60); c.lineWidth = 7; c.stroke();
      for (let index = 0; index < 5; index++) {
        const side = index % 2 === 0 ? -1 : 1; const yLeaf = 36 - index * 19;
        this.polygon([{ x: 0, y: yLeaf }, { x: side * 28, y: yLeaf - 3 },
          { x: side * 42, y: yLeaf - 25 }, { x: side * 13, y: yLeaf - 20 }], '#B4593F');
      }
      c.restore(); return;
    }
    for (let petal = 0; petal < (type === 1 ? 6 : 8); petal++) {
      c.save(); c.rotate(petal * Math.PI * 2 / (type === 1 ? 6 : 8));
      if (type === 2) {
        this.polygon([{ x: 0, y: -10 }, { x: -15, y: -41 }, { x: 0, y: -76 }, { x: 15, y: -41 }], '#B4593F');
        this.ellipse(0, -44, 5, 14, '#ECDCB5');
      } else {
        c.beginPath(); c.moveTo(0, 0); c.bezierCurveTo(-43, -45, -18, -76, 0, -46);
        c.bezierCurveTo(18, -76, 43, -45, 0, 0); c.closePath(); c.fillStyle = '#B4593F'; c.fill();
        this.ellipse(0, -34, 4, 10, '#ECDCB5');
      }
      c.restore();
    }
    this.ellipse(0, 0, 14, 14, '#C76745'); this.ellipse(0, 0, 5, 5, '#EBD8AE'); c.restore();
  }

  private homeScene(): void {
    const c = this.context;
    if (this.stage === 1) { this.pitHouse(); return; }
    this.sky(); this.hill(130, 495, 300, 150, '#A7AF7D'); this.hill(795, 470, 330, 152, '#719976');
    if (this.stage === 0) {
      this.polygon([{ x: 78, y: 491 }, { x: 457, y: 347 }, { x: 918, y: 480 }, { x: 574, y: 673 }], '#C8C393');
      this.house(280, 410, 1.18); this.house(560, 433, 1.05); this.house(775, 453, 0.92);
      this.house(405, 552, 1.14); this.person(565, 522, '#E1D1A0', 1.05); this.person(645, 521, '#9D6447', 0.85);
      this.kiln(242, 531, this.found.includes('kiln'));
      this.house(724, 554, this.found.includes('home') ? 1.25 : 1);
      if (this.found.includes('kiln')) this.ellipse(243, 575, 58, 8, '#D4AD64');
      if (this.found.includes('home')) this.ellipse(724, 575, 55, 8, '#D4AD64');
      if (this.choice >= 0) {
        c.beginPath(); c.arc(this.choice === 0 ? 243 : 724, 522, 95, 0, Math.PI * 2);
        c.strokeStyle = '#E9D5A2'; c.lineWidth = 4; c.stroke();
      }
      c.fillStyle = '#AE7B50'; c.beginPath(); c.moveTo(497, 553); c.bezierCurveTo(478, 520, 530, 516, 516, 552);
      c.closePath(); c.fill();    } else {
      c.fillStyle = '#D0BC8A'; c.fillRect(150, 270, 700, 420);
      this.polygon([{ x: 109, y: 279 }, { x: 500, y: 157 }, { x: 890, y: 279 }], '#6F8462');
      c.fillStyle = '#E7D4A8'; c.fillRect(298, 310, 405, 308);
      for (let index = 0; index < 5; index++) this.line(300 + index * 100, 309, 300 + index * 100, 618, '#9B8960', 6);
      for (let index = 0; index < 4; index++) this.line(298, 310 + index * 102, 703, 310 + index * 102, '#9B8960', 6);
      if (this.choice >= 0) this.paperFlower(501, 464, 1.48, this.choice);
      else      this.tree(170, 652, 0.87); this.grain(812, 652, 1.1);
    }
  }

  private cliff(): void {
    const c = this.context;
    this.polygon([{ x: 90, y: 400 }, { x: 123, y: 222 }, { x: 212, y: 164 }, { x: 290, y: 240 },
      { x: 352, y: 213 }, { x: 418, y: 351 }, { x: 429, y: 487 }], '#779177');
    for (let index = 0; index < 8; index++) {
      const x = 133 + index * 33; const y = 270 + Math.sin(index) * 20;
      c.beginPath(); c.moveTo(x - 10, y + 50); c.lineTo(x - 10, y + 9);
      c.arc(x, y + 9, 10, Math.PI, 0); c.lineTo(x + 10, y + 50); c.closePath(); c.fillStyle = '#445F50'; c.fill();
      this.line(x - 14, y + 52, x + 14, y + 52, '#A5AD86', 3);
    }
    this.hill(857, 448, 320, 240, '#547F68'); this.pavilion(807, 345, 0.65);
  }

  private springScene(): void {
    const c = this.context; this.sky(); this.river(); this.cliff();
    this.tree(83, 672, 1.25, this.stage > 0); this.tree(914, 613, 0.9, this.stage > 0);
    this.boat(584, 533, 0.72);
    if (this.stage === 0) {
      // 景窗是原生可拖动的观察遮罩；它改变可见范围，用户必须把窗口移向山崖才展开下一步。
      const x = this.choice === 1 ? 120 + this.amount * 2 : this.choice === 0 ? 280 + this.amount * 3.2 : 160 + this.amount * 6.7;
      const y = this.choice === 0 ? 440 : this.choice === 1 ? 325 : 354;
      c.save(); c.beginPath(); c.rect(0, 0, 1000, 760); c.arc(x, y, 149, 0, Math.PI * 2, true);
      c.fillStyle = 'rgba(235,235,214,0.58)'; c.fill('evenodd'); c.restore();
      c.beginPath(); c.arc(x, y, 149, 0, Math.PI * 2); c.strokeStyle = '#F6EBCB'; c.lineWidth = 8; c.stroke();
      c.beginPath(); c.arc(x, y, 155, 0, Math.PI * 2); c.strokeStyle = '#748A65'; c.lineWidth = 2; c.stroke();
      this.line(x, y - 164, x, y - 138, '#F9EBCB', 3); this.line(x - 161, y, x - 134, y, '#F9EBCB', 3);
    } else if (this.stage === 1) {
      for (let index = 0; index < (this.choice < 0 ? 4 : 13); index++) {
        const x = 175 + (index * 93) % 660; const y = 575 + Math.sin(index * 1.4) * 68;
        this.blossom(x, y, 17 + index % 3 * 4, this.choice === 1 ? '#D19874' : '#D5A88D');
      }
      this.person(677, 552, '#B87858', 0.95); this.person(721, 545, '#E9D6A3', 0.83);
      if (this.choice === 1) {
        this.person(611, 575, '#C7B179', 1.12); this.person(569, 572, '#AE7E5E', 1.02);
        this.person(767, 560, '#CDD0A0', 0.9);
      }
    } else {
      c.fillStyle = '#D6C18C'; c.fillRect(170, 493, 660, 152);
      this.ellipse(500, 513, 236, 73, '#E7D8AB');
      this.ellipse(501, 503, 142, 52, '#7F997E');
      c.beginPath(); c.moveTo(359, 503); c.bezierCurveTo(364, 620, 633, 620, 643, 503);
      c.fillStyle = '#517B67'; c.fill(); this.ellipse(501, 501, 137, 47, '#DCC894');
      if (this.choice >= 0) {
        for (let index = 0; index < 6; index++) this.ellipse(420 + index * 29, 500 + Math.sin(index) * 16, 17, 7,
          this.choice === 1 ? '#C8A36D' : '#94A77A');
        for (let index = 0; index < 4; index++) {
          c.beginPath(); c.moveTo(435 + index * 42, 449); c.bezierCurveTo(409 + index * 42, 413,
            466 + index * 42, 389, 441 + index * 42, 351);
          c.strokeStyle = '#F2E8CA'; c.lineWidth = 4; c.stroke();
        }
      }
      if (this.choice === 1) {
        this.person(246, 544, '#B7815B', 1.4); this.person(754, 541, '#B79B68', 1.4);
        this.person(316, 466, '#D9C68F', 1.2); this.person(690, 465, '#A17859', 1.18);
      }
      this.blossom(765, 529, 35, '#CE9179');
      if (this.choice === 2) {
        this.blossom(230, 570, 36, '#D6A18A'); this.blossom(688, 608, 24, '#DAAD91');
        this.blossom(738, 623, 17, '#D6A18A'); this.blossom(318, 633, 18, '#DCB196');
      }
    }
  }

  private wallGate(): void {
    const c = this.context;
    this.polygon([{ x: 180, y: 424 }, { x: 179, y: 270 }, { x: 772, y: 251 }, { x: 823, y: 413 }], '#7C9070');
    for (let index = 0; index < 12; index++) c.fillRect(179 + index * 54, 251 + Math.sin(index) * 5, 32, 35);
    c.fillStyle = '#B8B38A'; c.fillRect(529, 292, 181, 155);
    this.pavilion(620, 290, 1.1);
    c.fillStyle = '#365D4E'; c.fillRect(568, 351, 103, 105);
    this.polygon([{ x: 139, y: 410 }, { x: 462, y: 398 }, { x: 390, y: 519 }, { x: 53, y: 549 }], '#D9CAA0');
    c.fillStyle = '#4B6E54'; c.fillRect(292, 321, 85, 127);
    this.line(278, 322, 390, 321, '#C5BD92', 9);
    this.line(287, 340, 287, 442, '#879471', 6); this.line(382, 340, 382, 442, '#879471', 6);
  }

  private meetingScene(): void {
    const c = this.context; this.sky(); this.river();
    if (this.stage === 0) {
      this.wallGate(); this.tree(111, 505, 0.8); this.tree(838, 427, 0.62);
      if (this.choice === 1) {
        const x = 175 + this.amount * 1.6; const y = 503 - this.amount * 0.75;
        this.person(x, y, '#AC6B4E', 1.16);
        this.line(163, 523, x, y + 13, '#E4D5AA', 4);
      } else {
        const x = 365 + this.amount * 2.3; const y = 592 - this.amount * 1.32;
        this.boat(x, y, 0.93);
      }
    } else {
      this.hill(845, 500, 260, 100, '#98AD7F'); this.tree(173, 551, 1.1, true);
      this.pavilion(804, 452, 0.8); this.tree(890, 575, 0.75);
      this.person(360, 516, '#D4B17C', 1.45); this.person(424, 501, '#9F624C', 1.35);
      this.person(640, 448, '#DDD5A6', 0.75); this.person(675, 446, '#9B9770', 0.8);
      if (this.stage === 1) {
        const count = this.choice < 0 ? 3 : 11;
        for (let index = 0; index < count; index++) {
          const x = 260 + index * 47;
          this.line(x, 650, x + 4, 614 - index % 3 * 8, '#718D60', 3);
          this.blossom(x + 4, 608 - index % 3 * 8, 8, '#C6B2A0');
        }
        if (this.choice === 0) {
          // 选“水名”时只在河面点出两处水口，不再把字画进画布
          this.ellipse(345, 606, 16, 5, 'rgba(226,211,167,0.7)');
          this.ellipse(697, 576, 16, 5, 'rgba(226,211,167,0.7)');
        } else if (this.choice === 1) {
          for (let index = 0; index < 4; index++) {
            c.beginPath(); c.moveTo(466, 574 + index * 16);
            c.bezierCurveTo(527, 548 + index * 16, 602, 587 + index * 16, 670, 550 + index * 16);
            c.strokeStyle = '#C0D0AC'; c.lineWidth = 3; c.stroke();
          }
        }
      } else {
        this.polygon([{ x: 261, y: 588 }, { x: 540, y: 552 }, { x: 656, y: 623 }, { x: 372, y: 681 }], '#D2C290');
        if (this.choice === 1) {
          this.pavilion(510, 390, 1.15);
          c.fillStyle = '#B6B080'; c.fillRect(460, 383, 100, 108);
          c.fillStyle = '#4C7057'; c.fillRect(484, 420, 51, 71);
          this.person(505, 525, '#B47E54', 0.8);
        } else if (this.choice === 2) {
          this.polygon([{ x: 288, y: 565 }, { x: 648, y: 550 }, { x: 648, y: 653 }, { x: 288, y: 670 }], '#E5D4A7');
        } else {
          this.ellipse(450, 608, 45, 14, '#C9A36D'); this.ellipse(538, 603, 28, 11, '#829476');
        }
      }
    }
  }

  // ——————————————————————————————————————————————
  // 开封《点亮汴京的一夜》图景
  // 采用汴河—虹桥—御街的空间关系：河自西向东横过画面，街从桥上穿过入城，
  // 桥是整个篇章的“轴心”。船行到桥下即“水与街交会”，点灯即“河面有了灯影”。
  // 所有形制为原创示意，不表示州桥发掘的实测形制、跨度或宋代桥梁复原。
  // ——————————————————————————————————————————————

  private kfSky(night: boolean): void {
    const c = this.context;
    const sky = c.createLinearGradient(0, 0, 0, 470);
    if (night) {
      sky.addColorStop(0, '#0D2728'); sky.addColorStop(0.5, '#173D39'); sky.addColorStop(1, '#255045');
    } else {
      sky.addColorStop(0, '#F2ECDA'); sky.addColorStop(0.45, '#E9E5CD'); sky.addColorStop(1, '#D8DDC0');
    }
    c.fillStyle = sky; c.fillRect(0, 0, 1000, 760);
    // 月用暖白，日只用淡影；两者都带一圈很淡的光，不画星点，避免像夜景贴图
    const halo = c.createRadialGradient(792, 104, 10, 792, 104, 96);
    halo.addColorStop(0, night ? 'rgba(238,222,178,0.34)' : 'rgba(226,205,158,0.30)');
    halo.addColorStop(1, 'rgba(238,222,178,0)');
    c.fillStyle = halo; c.fillRect(690, 0, 210, 220);
    this.ellipse(792, 104, night ? 27 : 23, night ? 27 : 23, night ? '#EFE3BE' : '#E5D3A6');
    // 远处的滩地与树影：两层很淡的横带，把天空与屋脊接起来，不留大片空白
    c.beginPath(); c.moveTo(-20, 330);
    c.bezierCurveTo(220, 300, 420, 342, 640, 318);
    c.bezierCurveTo(820, 298, 930, 330, 1020, 312);
    c.lineTo(1020, 420); c.lineTo(-20, 420); c.closePath();
    c.fillStyle = night ? 'rgba(30,62,55,0.55)' : 'rgba(214,220,190,0.75)'; c.fill();
    c.beginPath(); c.moveTo(-20, 348);
    c.bezierCurveTo(180, 322, 380, 360, 600, 336);
    c.bezierCurveTo(790, 316, 900, 348, 1020, 330);
    c.lineTo(1020, 430); c.lineTo(-20, 430); c.closePath();
    c.fillStyle = night ? 'rgba(24,52,47,0.6)' : 'rgba(198,208,176,0.8)'; c.fill();
  }

  // 界画式店屋：直线屋面 + 屋身 + 门窗。营业中的店在夜里透出暖光。
  // 屋面用直坡与水平檐口，不做圆拱顶；各店由调用处给出不同高度与屋面深浅，
  // 避免整排房子变成同一种绿三角。
  private kfHouse(x: number, base: number, width: number, height: number, roofColor: string,
    bodyColor: string, lit: boolean): void {
    const c = this.context;
    // 台基
    c.fillStyle = '#9C9473'; c.fillRect(x - width * 0.56, base - 6, width * 1.12, 6);
    // 屋身
    c.fillStyle = bodyColor; c.fillRect(x - width * 0.5, base - height, width, height - 5);
    // 门窗：夜里营业的店把门脸点亮
    c.fillStyle = lit ? '#EBC078' : '#4F5C46';
    c.fillRect(x - width * 0.30, base - height * 0.58, width * 0.22, height * 0.58);
    c.fillRect(x + width * 0.06, base - height * 0.58, width * 0.22, height * 0.58);
    // 门框与窗棂
    c.strokeStyle = lit ? '#B98F4C' : '#7C8567'; c.lineWidth = 1.2;
    c.strokeRect(x - width * 0.30, base - height * 0.58, width * 0.22, height * 0.58);
    c.beginPath();
    c.moveTo(x + width * 0.17, base - height * 0.58); c.lineTo(x + width * 0.17, base - 5);
    c.moveTo(x + width * 0.06, base - height * 0.30); c.lineTo(x + width * 0.28, base - height * 0.30);
    c.stroke();
    // 屋面：直坡 + 微翘檐口 + 正脊
    const eave = base - height + 3;
    const ridge = base - height - 22;
    c.beginPath(); c.moveTo(x - width * 0.70, eave);
    c.quadraticCurveTo(x - width * 0.62, eave - 6, x - width * 0.34, ridge);
    c.lineTo(x + width * 0.34, ridge);
    c.quadraticCurveTo(x + width * 0.62, eave - 6, x + width * 0.70, eave);
    c.quadraticCurveTo(x, eave + 6, x - width * 0.70, eave); c.closePath();
    c.fillStyle = roofColor; c.fill();
    // 正脊与檐口
    this.line(x - width * 0.34, ridge, x + width * 0.34, ridge, '#E3D6B2', 1.8);
    this.line(x - width * 0.70, eave, x + width * 0.70, eave, '#5A6549', 1.6);
    // 瓦垄：只在坡面画短线，不再整体压暗
    c.globalAlpha = 0.28;
    for (let index = 0; index < 6; index++) {
      const t = index / 5;
      this.line(x - width * 0.34 + t * width * 0.68, ridge + 2,
        x - width * 0.62 + t * width * 0.9, eave - 1, '#48573D', 1.1);
    }
    c.globalAlpha = 1;
  }

  // 河岸垂柳：先立干，再垂枝，叶沿枝落下；比通用圆树更贴合汴河两岸。
  private kfWillow(x: number, y: number, scale: number): void {
    const c = this.context;
    c.save(); c.translate(x, y); c.scale(scale, scale);
    c.beginPath(); c.moveTo(0, 4); c.bezierCurveTo(-4, -18, 3, -36, -1, -50);
    c.strokeStyle = '#6A7550'; c.lineWidth = 4; c.stroke();
    this.ellipse(-10, -54, 15, 13, '#93AC7C');
    this.ellipse(9, -58, 16, 14, '#A0B986');
    this.ellipse(0, -64, 14, 12, '#ABC28F');
    // 垂枝只到冠下 1/3 处，短而密，避免在缩小后变成放射状的扇形
    for (let index = 0; index < 6; index++) {
      const spread = (index - 2.5) * 7;
      c.beginPath(); c.moveTo(spread * 0.9, -52);
      c.quadraticCurveTo(spread * 1.05, -44, spread * 1.0, -38);
      c.strokeStyle = '#7E9A66'; c.lineWidth = 1.6; c.stroke();
      this.ellipse(spread * 1.0, -36, 2.6, 3.4, '#8FA878');
    }
    c.restore();
  }

  // 城门与城楼：只作城市轮廓，垛口数量不表示实际城制。
  private kfCityWall(night: boolean): void {
    const c = this.context;
    this.polygon([{ x: 560, y: 372 }, { x: 560, y: 300 }, { x: 1010, y: 292 }, { x: 1010, y: 366 }],
      night ? '#2C4B44' : '#A9A47F');
    for (let index = 0; index < 9; index++) {
      c.fillStyle = night ? '#264740' : '#A49E7B';
      c.fillRect(566 + index * 50, 284 + index * 1, 26, 18);
    }
    c.fillStyle = night ? '#264740' : '#A8A380'; c.fillRect(742, 300, 74, 66);
    // 砖缝与墙基
    c.globalAlpha = 0.35;
    for (let course = 0; course < 5; course++) {
      this.line(566, 312 + course * 13, 1004, 306 + course * 13, night ? '#162E2A' : '#8E8A68', 1.1);
    }
    c.globalAlpha = 1;
    c.fillStyle = night ? '#1F3A35' : '#8F8B6A'; c.fillRect(560, 358, 450, 14);
    // 城楼：重檐 + 平座
    this.polygon([{ x: 706, y: 306 }, { x: 779, y: 262 }, { x: 852, y: 306 }], night ? '#1F3E39' : '#5E6E4B');
    this.line(700, 304, 858, 304, night ? '#3A5B50' : '#D3C9A0', 4);
    this.polygon([{ x: 722, y: 276 }, { x: 779, y: 246 }, { x: 836, y: 276 }], night ? '#28463F' : '#4C5C3F');
    this.line(718, 275, 840, 275, night ? '#43645A' : '#C8BE96', 3);
    // 城楼窗：夜里点亮
    c.fillStyle = night ? '#E0B166' : '#5C6A50';
    c.fillRect(760, 316, 14, 16); c.fillRect(786, 316, 14, 16);
  }

  private kfRiver(night: boolean): void {
    const c = this.context;
    c.beginPath(); c.moveTo(-30, 486);
    c.bezierCurveTo(240, 462, 420, 502, 620, 480);
    c.bezierCurveTo(790, 462, 900, 490, 1030, 470);
    c.lineTo(1030, 646);
    c.bezierCurveTo(830, 660, 640, 628, 460, 648);
    c.bezierCurveTo(280, 668, 120, 640, -30, 660);
    c.closePath();
    const water = c.createLinearGradient(0, 470, 0, 660);
    if (night) {
      water.addColorStop(0, '#2E6357'); water.addColorStop(0.55, '#1C4A44'); water.addColorStop(1, '#123733');
    } else {
      water.addColorStop(0, '#4C8874'); water.addColorStop(0.55, '#2E6C5C'); water.addColorStop(1, '#1D5449');
    }
    c.fillStyle = water; c.fill();
    // 水纹：疏密不同的短横线，靠岸更密
    for (let index = 0; index < 22; index++) {
      const x = -10 + index * 48;
      const y = 512 + Math.sin(index * 0.7) * 12 + (index % 4) * 15;
      c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x + 16, y - 3, x + 34, y + 1);
      c.strokeStyle = night ? '#4E7C6C' : '#8DB8A1'; c.globalAlpha = index % 3 === 0 ? 0.6 : 0.3;
      c.lineWidth = index % 3 === 0 ? 2 : 1.2; c.stroke(); c.globalAlpha = 1;
    }
    // 驳岸：一条石砌边线，说明这是可以停船、上街的河岸
    c.beginPath(); c.moveTo(-30, 486);
    c.bezierCurveTo(240, 462, 420, 502, 620, 480);
    c.bezierCurveTo(790, 462, 900, 490, 1030, 470);
    c.strokeStyle = night ? '#5A5741' : '#B9AE85'; c.lineWidth = 7; c.stroke();
    c.strokeStyle = night ? '#3F4232' : '#9C9169'; c.lineWidth = 1.4; c.stroke();
  }

  // 近岸：站立观看的位置，给出前景深度，也让桥台有落脚处。
  private kfForeground(night: boolean): void {
    const c = this.context;
    c.beginPath(); c.moveTo(-30, 652);
    c.bezierCurveTo(260, 672, 700, 636, 1030, 656);
    c.lineTo(1030, 760); c.lineTo(-30, 760); c.closePath();
    c.fillStyle = night ? '#25352C' : '#C8BC94'; c.fill();
    for (let index = 0; index < 24; index++) {
      const x = -4 + index * 44;
      this.line(x, 748 - (index % 3) * 5, x + 6, 730 - (index % 4) * 6, night ? '#3A4A38' : '#AB9E74', 1.2);
    }
    // 桥前石阶：五级，暗示桥面高于河岸
    for (let step = 0; step < 5; step++) {
      this.line(462 - step * 8, 700 + step * 12, 538 + step * 8, 700 + step * 12,
        night ? '#3B4738' : '#B4A87F', 3);
    }
  }

  // 虹桥：桥面弧线 + 编木拱 + 栏杆 + 桥台。它是本篇章唯一贯穿全画的构件。
  private kfBridge(night: boolean): void {
    const c = this.context;
    const left = 322; const right = 678; const spring = 626; const apex = 486; const center = 500;
    const deckY = (t: number): number => spring - Math.sin(t * Math.PI) * (spring - apex);
    const archY = (t: number): number => spring - Math.sin(t * Math.PI) * (spring - 556);
    // 桥台
    this.polygon([{ x: left - 52, y: spring + 2 }, { x: left - 4, y: spring - 10 },
      { x: left + 2, y: spring + 56 }, { x: left - 58, y: spring + 56 }], night ? '#4A4E3B' : '#A79C77');
    this.polygon([{ x: right + 52, y: spring + 2 }, { x: right + 4, y: spring - 10 },
      { x: right - 2, y: spring + 56 }, { x: right + 58, y: spring + 56 }], night ? '#4A4E3B' : '#A79C77');
    // 编木拱：两组交错斜杆，形成“无柱飞桥”的栅格感
    const members = 20;
    for (let index = 0; index < members; index++) {
      const t0 = index / members; const t1 = (index + 0.5) / members;
      const x0 = left + t0 * (right - left); const x1 = left + t1 * (right - left);
      this.line(x0, deckY(t0) - 2, x1, archY(t1), night ? '#6B5A3B' : '#8A6F49', 2.4);
      if (index < members - 1) this.line(x1, deckY(t1) - 2, x0, archY(t0), night ? '#7A6746' : '#9C7E54', 2.4);
    }
    // 拱腹：把桥面与下弦之间填实，桥才不是几条线
    c.beginPath(); c.moveTo(left, deckY(0));
    for (let index = 1; index <= 24; index++) { const t = index / 24; c.lineTo(left + t * (right - left), deckY(t) - 2); }
    for (let index = 24; index >= 0; index--) { const t = index / 24; c.lineTo(left + t * (right - left), archY(t)); }
    c.closePath();
    c.fillStyle = night ? 'rgba(58,48,32,0.55)' : 'rgba(122,98,62,0.28)'; c.fill();
    // 下弦拱
    c.beginPath(); c.moveTo(left, archY(0));
    c.bezierCurveTo(left + 60, archY(0.2), right - 60, archY(0.8), right, archY(1));
    c.strokeStyle = night ? '#5C4D33' : '#7C6440'; c.lineWidth = 10; c.stroke();
    // 桥面
    c.beginPath(); c.moveTo(left, deckY(0));
    c.bezierCurveTo(left + 70, deckY(0.28), right - 70, deckY(0.72), right, deckY(1));
    c.strokeStyle = night ? '#7C6743' : '#A98D5F'; c.lineWidth = 17; c.stroke();
    c.strokeStyle = night ? '#B39B6C' : '#E0D0A6'; c.lineWidth = 3.4; c.stroke();
    // 栏杆：立柱 + 扶手
    for (let index = 0; index <= 16; index++) {
      const t = index / 16; const x = left + t * (right - left);
      this.line(x, deckY(t) - 3, x, deckY(t) - 22, night ? '#C2AA76' : '#F0E2BC', 2.4);
    }
    c.beginPath(); c.moveTo(left, deckY(0) - 22);
    c.bezierCurveTo(left + 70, deckY(0.28) - 22, right - 70, deckY(0.72) - 22, right, deckY(1) - 22);
    c.strokeStyle = night ? '#D3B983' : '#F4E7C4'; c.lineWidth = 4.6; c.stroke();
    // 桥心：标出“街从桥上穿过”的位置，不写文字
    this.line(center, deckY(0.5) - 22, center, deckY(0.5) + 4, '#7A6A47', 2);
  }

  // 漕船：长身、拱篷、可放倒的桅。夜里有灯。
  private kfBoat(x: number, y: number, scale: number, night: boolean, mastDown: boolean): void {
    const c = this.context; c.save(); c.translate(x, y); c.scale(scale, scale);
    c.beginPath(); c.moveTo(-62, -6); c.bezierCurveTo(-40, 16, 40, 16, 62, -8);
    c.lineTo(52, -18); c.bezierCurveTo(30, 2, -28, 2, -50, -18); c.closePath();
    c.fillStyle = night ? '#7A6038' : '#B08A55'; c.fill();
    this.line(-62, -6, 62, -8, night ? '#C6A46B' : '#E3CD9E', 3);
    // 拱篷
    c.beginPath(); c.moveTo(-20, -16); c.bezierCurveTo(-16, -46, 22, -46, 26, -16); c.closePath();
    c.fillStyle = night ? '#5C5138' : '#7E7350'; c.fill();
    this.line(-20, -16, 26, -16, night ? '#B79A64' : '#CDBA8B', 2);
    // 桅
    if (mastDown) {
      this.line(30, -18, 76, -30, night ? '#A98D5D' : '#C1A575', 3);
    } else {
      this.line(34, -18, 34, -104, night ? '#A98D5D' : '#C1A575', 3);
      this.line(34, -92, 62, -58, night ? '#D8C08A' : '#EFE0B6', 2);
    }
    // 艄公
    this.ellipse(-44, -26, 4, 5, '#B69068');
    this.polygon([{ x: -49, y: -21 }, { x: -39, y: -21 }, { x: -36, y: -8 }, { x: -52, y: -8 }],
      night ? '#C7AB7C' : '#D8C79B');
    if (night) {
      const glow = c.createRadialGradient(0, -30, 4, 0, -30, 54);
      glow.addColorStop(0, 'rgba(226,175,96,0.42)'); glow.addColorStop(1, 'rgba(226,175,96,0)');
      c.fillStyle = glow; c.fillRect(-56, -86, 112, 112);
      this.ellipse(0, -34, 7, 9, '#E8BE7A');
    }
    c.restore();
  }

  // 灯：只在本篇作为原创灯景出现，不与汴京灯笼张的具体样式对应。
  private kfLantern(x: number, y: number, radius: number, lit: boolean, shape: number): void {
    const c = this.context;
    if (lit) {
      const glow = c.createRadialGradient(x, y, 2, x, y, radius * 4.6);
      glow.addColorStop(0, 'rgba(233,184,104,0.5)'); glow.addColorStop(1, 'rgba(233,184,104,0)');
      c.fillStyle = glow; c.fillRect(x - radius * 4.8, y - radius * 4.8, radius * 9.6, radius * 9.6);
    }
    this.line(x, y - radius * 2.2, x, y - radius * 1.05, '#B9A070', 1.6);
    if (shape === 0) {
      this.ellipse(x, y, radius, radius * 1.06, lit ? '#E7BE76' : '#9A8759');
    } else if (shape === 1) {
      this.ellipse(x, y, radius * 1.16, radius * 0.92, lit ? '#E9C684' : '#9A8759');
    } else {
      this.polygon([{ x, y: y - radius * 1.1 }, { x: x + radius, y: y - radius * 0.3 },
        { x: x + radius * 0.72, y: y + radius }, { x: x - radius * 0.72, y: y + radius },
        { x: x - radius, y: y - radius * 0.3 }], lit ? '#E4B96F' : '#9A8759');
    }
    c.strokeStyle = lit ? '#C08F4C' : '#8E7C50'; c.lineWidth = 1.4;
    for (let index = -1; index <= 1; index++) {
      c.beginPath(); c.ellipse(x, y, Math.abs(radius * (0.4 + index * 0.3)), radius * 1.02, 0, 0, Math.PI * 2); c.stroke();
    }
    this.line(x - radius * 0.5, y + radius * 1.0, x + radius * 0.5, y + radius * 1.0, '#C2A874', 3);
    if (lit) this.line(x, y + radius * 1.1, x, y + radius * 1.9, '#C08F4C', 1.6);
  }

  private kfStreetLamps(night: boolean, lit: boolean): void {
    // 桥头两串灯 + 沿岸店前散灯；位置固定，随点亮状态改变明度
    const bridge: number[][] = [[318, 596], [356, 604], [644, 604], [682, 596]];
    bridge.forEach((point: number[], index: number) => {
      this.kfLantern(point[0], point[1], index % 2 === 0 ? 13 : 11, night && lit, index % 3);
    });
    const street: number[][] = [[404, 522], [446, 516], [556, 516], [598, 522]];
    street.forEach((point: number[], index: number) => {
      this.kfLantern(point[0], point[1], 10, night && lit, (index + 1) % 3);
    });
  }

  // 前景灯杆：两盏主灯构成画面的暖色焦点，点亮前后差别一眼可见。
  private kfPole(x: number, base: number, topX: number, topY: number, lit: boolean, shape: number): void {
    this.line(x, base, x, topY - 26, '#8B7B55', 5);
    this.line(x, topY - 26, topX, topY - 34, '#8B7B55', 3);
    this.line(topX, topY - 34, topX, topY - 14, '#B9A070', 1.6);
    this.kfLantern(topX, topY, 21, lit, shape);
  }

  // 时间层：把“城市叠压”画成一个探方剖面，不是实测地层柱状图。
  // 只轻微压暗周围街景，剖面本身是画面主体：自上而下分层，越深越早，
  // 拨动滑条即向下多揭开一层；桥的遗存在更早的层位里露出一段拱。
  private kfStrata(amount: number, night: boolean): void {
    const c = this.context;
    const top = 402; const bottom = 706; const left = 336; const right = 664;
    const depth = bottom - top;
    // 周围轻微压暗，保证街景仍可辨认（不做整块遮罩）
    c.fillStyle = night ? 'rgba(8,24,23,0.30)' : 'rgba(58,62,44,0.16)';
    c.fillRect(0, 0, 1000, 760);
    // 探方外框：深色土壁 + 细边框
    this.polygon([{ x: left - 14, y: top - 14 }, { x: right + 14, y: top - 14 },
      { x: right + 14, y: bottom }, { x: left - 14, y: bottom }], night ? '#1B312C' : '#6A6650');
    this.polygon([{ x: left, y: top }, { x: right, y: top }, { x: right, y: bottom }, { x: left, y: bottom }],
      night ? '#243B34' : '#7C7659');
    const revealed = Math.max(0.10, Math.min(1, amount / 100));
    // 四层：自上而下由浅到深，bump 表示每层厚度占比
    const ratios: number[] = [0.20, 0.26, 0.28, 0.26];
    const colors: string[] = night ? ['#6E6349', '#7C6C4C', '#8A7651', '#5F563F'] :
      ['#C6B183', '#B39C6C', '#9C8558', '#857046'];
    let cursor = 0;
    for (let index = 0; index < ratios.length; index++) {
      const y0 = top + depth * cursor;
      cursor += ratios[index];
      if (cursor > revealed + 0.001) break;
      const y1 = top + depth * cursor;
      this.polygon([{ x: left, y: y0 }, { x: right, y: y0 }, { x: right, y: y1 }, { x: left, y: y1 }], colors[index]);
      // 层内颗粒：短横线，密度随层变化
      c.globalAlpha = 0.28;
      for (let grain = 0; grain < 9; grain++) {
        const gy = y0 + (y1 - y0) * (grain + 0.5) / 9;
        this.line(left + 12 + (grain % 3) * 26, gy, right - 16 - (grain % 4) * 22, gy + (grain % 2) * 2,
          index % 2 === 0 ? '#EFE2BE' : '#5E5238', 1.1);
      }
      c.globalAlpha = 1;
      // 层界：一条略带起伏的线，强调“叠压”而不是表格
      c.beginPath(); c.moveTo(left, y0);
      c.bezierCurveTo(left + 110, y0 + 5, right - 110, y0 - 5, right, y0);
      c.strokeStyle = night ? '#3C4A3A' : '#8A7A55'; c.lineWidth = 1.6; c.stroke();
    }
    // 尚未揭开的深度：用斜线示意“还在下面”，避免出现一块空黑
    const openedY = top + depth * Math.min(1, revealed);
    if (openedY < bottom - 2) {
      c.fillStyle = night ? '#1A2E2A' : '#6E6A4F';
      c.fillRect(left, openedY, right - left, bottom - openedY);
      c.globalAlpha = 0.35;
      for (let hatch = 0; hatch < 26; hatch++) {
        const hx = left + hatch * 14;
        this.line(hx, Math.min(bottom, openedY + (bottom - openedY)), hx + (bottom - openedY),
          openedY, night ? '#4A5B4A' : '#8A8264', 1);
      }
      c.globalAlpha = 1;
      this.line(left, openedY, right, openedY, night ? '#5C6A54' : '#9A9070', 2);
    }
    // 更早层位里的桥拱遗存
    if (revealed > 0.56) {
      const archTop = top + depth * 0.62;
      c.globalAlpha = Math.min(1, (revealed - 0.56) / 0.16);
      c.beginPath(); c.moveTo(left + 52, archTop + 96);
      c.bezierCurveTo(left + 92, archTop + 6, right - 92, archTop + 6, right - 52, archTop + 96);
      c.strokeStyle = night ? '#D8C194' : '#F3E5BE'; c.lineWidth = 9; c.stroke();
      c.beginPath(); c.moveTo(left + 40, archTop + 100); c.lineTo(right - 40, archTop + 100);
      c.strokeStyle = night ? '#B9A578' : '#DCC99E'; c.lineWidth = 3; c.stroke();
      // 桥上方的道路遗迹：几道平行短线
      for (let deck = 0; deck < 3; deck++) {
        this.line(left + 60, archTop - 12 - deck * 9, right - 60, archTop - 14 - deck * 9,
          night ? '#A5936B' : '#C7B78C', 2);
      }
      c.globalAlpha = 1;
    }
    // 右侧深度标尺：每 1/8 一格，长格加粗
    const scaleX = right - 12;
    this.line(scaleX, top, scaleX, bottom, night ? '#B7AB84' : '#F0E2BC', 1.8);
    for (let tick = 0; tick <= 8; tick++) {
      const y = top + depth * tick / 8;
      this.line(scaleX, y, scaleX - (tick % 2 === 0 ? 16 : 9), y, night ? '#B7AB84' : '#F0E2BC', 1.6);
    }
    // 当前揭开到哪一层：朱砂三角
    const markerY = top + depth * revealed;
    this.polygon([{ x: scaleX + 4, y: markerY - 7 }, { x: scaleX + 18, y: markerY },
      { x: scaleX + 4, y: markerY + 7 }], '#F0D5A0');
  }

  private nightScene(): void {
    const night = this.stage === 2;
    const lit = night && this.illuminated && this.choice >= 0;
    this.kfSky(night);
    // 远景屋顶：高度与屋面深浅错开，避免出现一排同形绿三角
    const farRoofs: string[] = night ? ['#24463F', '#2B4E44', '#1F3E39'] : ['#7B8763', '#85906A', '#6F7B58'];
    const farBodies: string[] = night ? ['#2E4E45', '#33544A', '#294740'] : ['#CEC6A0', '#B7AD84', '#DCD4AE'];
    for (let index = 0; index < 7; index++) {
      this.kfHouse(52 + index * 76, 392 + (index % 3) * 5, 56 + (index % 2) * 8, 44 + (index % 3) * 9,
        farRoofs[index % 3], farBodies[index % 3], false);
    }
    this.kfCityWall(night);
    // 近岸店屋：高度、面宽与屋面深浅都错开；夜里让隔一间店的窗透光
    const nearRoofs: string[] = night ? ['#1D3E39', '#254740', '#173733'] : ['#5C6A46', '#6D7A52', '#4F5D3F'];
    const nearBodies: string[] = night ? ['#2A4840', '#305047', '#26423B'] : ['#DED3B4', '#C2A87C', '#E8DEC4'];
    for (let index = 0; index < 6; index++) {
      this.kfHouse(90 + index * 164, 470 + (index % 2) * 4, 96 + (index % 3) * 12, 70 + (index % 3) * 11,
        nearRoofs[index % 3], nearBodies[index % 3], lit && index % 2 === 0);
    }
    // 柳树：汴河两岸常见，作为前景与远景的层次
    this.kfWillow(78, 500, 1.15); this.kfWillow(938, 496, 1.02);
    this.kfRiver(night);
    this.kfForeground(night);
    this.kfBridge(night);
    if (night) {
      // 灯点亮后，河面出现暖色倒影；未点亮时只有很弱的水光
      const reflection = lit ? 0.9 : 0.22;
      for (let index = 0; index < 12; index++) {
        const x = 300 + index * 40;
        const alpha = (index % 2 === 0 ? 0.5 : 0.3) * reflection;
        this.context.globalAlpha = alpha;
        this.line(x, 528 + (index % 4) * 12, x + 26, 530 + (index % 4) * 12, '#E4BC79', 2.4);
        this.context.globalAlpha = 1;
      }
    }
    if (this.stage === 0) {
      // 船位由滑条决定：0%在桥西，100%在桥东，53—78%正好行至桥下
      const boatX = 110 + this.amount * 6.0;
      const nearBridge = this.amount >= 53 && this.amount <= 78;
      this.kfBoat(boatX, 606 + Math.sin(boatX * 0.02) * 3, 0.92, night, nearBridge);
      // 交会标记：一条竖向水线穿过桥心，说明街、桥、河同处一轴
      if (nearBridge) {
        // 交会标记：一条竖线串起街、桥、水，水面加两道涟漪；不再用大圆环抢画面
        this.context.globalAlpha = 0.7;
        this.line(500, 372, 500, 620, '#D9B96F', 1.6);
        this.context.globalAlpha = 1;
        for (let ripple = 0; ripple < 2; ripple++) {
          this.context.beginPath();
          this.context.ellipse(500, 566 + ripple * 12, 30 + ripple * 16, 7 + ripple * 4, 0, 0, Math.PI * 2);
          this.context.strokeStyle = 'rgba(226,196,140,' + (0.55 - ripple * 0.2) + ')';
          this.context.lineWidth = 1.6; this.context.stroke();
        }
        this.context.fillStyle = '#A64C37';
        this.context.fillRect(496, 362, 8, 8);
      }
      this.kfStreetLamps(night, false);
    } else if (this.stage === 1) {
      this.kfStrata(this.amount, night);
    } else {
      this.kfStreetLamps(night, lit);
      this.kfPole(150, 722, 198, 556, lit, 1);
      this.kfPole(856, 716, 806, 548, lit, 2);
      if (lit) {
        // 桥面灯串：点亮后沿桥弧一串亮起
        for (let index = 0; index < 7; index++) {
          const t = 0.14 + index * 0.12;
          const x = 322 + t * 356;
          const y = 626 - Math.sin(t * Math.PI) * 140 - 30;
          this.kfLantern(x, y, 9, true, index % 3);
        }
        this.kfBoat(636, 578, 0.82, true, false);
        this.person(452, 620, '#D9BA77', 0.9);
        this.person(486, 622, '#C58E64', 0.88);
      } else {
        this.kfBoat(642, 580, 0.78, true, false);
      }
    }
  }


  private shell(x: number, y: number, scale: number, angle: number): void {
    const c = this.context; c.save(); c.translate(x, y); c.rotate(angle); c.scale(scale, scale);
    c.beginPath(); c.moveTo(-7, 0); c.bezierCurveTo(-6, -13, 11, -17, 12, -4);
    c.bezierCurveTo(11, 3, 0, 7, -7, 0); c.fillStyle = '#E3D4B2'; c.fill();
    this.line(-4, -1, 9, -6, '#BCAD8A', 1); c.restore();
  }

  private shellAnimal(cx: number, cy: number, dragon: boolean): void {
    // 壳形围出“龙 / 虎”的观看线索，轮廓是原创符号；界面明示不是墓葬平面或蚌塑复原。
    const c = this.context;
    for (let index = 0; index < 47; index++) {
      const t = index / 46; const x = cx - 160 + t * 320;
      const y = cy + Math.sin(t * Math.PI * (dragon ? 2.4 : 1.4)) * (dragon ? 48 : 26);
      this.shell(x, y, 1.05, t * 1.9); this.shell(x + 4, y + 19, 0.85, -t);
    }
    for (let index = 0; index < 9; index++) this.shell(cx + 146 + index % 3 * 11, cy - 22 + Math.floor(index / 3) * 13, 1, index * 0.3);
    for (let foot = 0; foot < 3; foot++) {
      for (let index = 0; index < 7; index++) this.shell(cx - 85 + foot * 88 + index * 4, cy + 22 + index * 10, 0.85, 0.6);
    }
    c.globalAlpha = 0.6; this.ellipse(cx + 163, cy - 18, 3, 3, '#576A55'); c.globalAlpha = 1;
  }

  private dragonScene(): void {
    const c = this.context; this.sky();
    if (this.stage === 0) {
      this.polygon([{ x: 70, y: 304 }, { x: 803, y: 235 }, { x: 941, y: 598 }, { x: 215, y: 695 }], '#B9AD82');
      for (let row = 0; row < 9; row++) for (let col = 0; col < 12; col++) {
        this.ellipse(128 + col * 62 + row * 4, 327 + row * 34, 1.8, 1.3, '#8E986F');
      }
      this.shellAnimal(430, 401, true); this.shellAnimal(600, 555, false);
      const x = this.choice === 0 ? 160 + this.amount * 2.7 : this.choice === 1 ? 250 + this.amount * 3.5 : 175 + this.amount * 6.15;
      const y = this.choice === 0 ? 401 : this.choice === 1 ? 550 : 462;
      c.save(); c.beginPath(); c.rect(0, 0, 1000, 760); c.arc(x, y, 166, 0, Math.PI * 2, true);
      c.fillStyle = 'rgba(217,213,184,0.66)'; c.fill('evenodd'); c.restore();
      c.beginPath(); c.arc(x, y, 167, 0, Math.PI * 2); c.strokeStyle = '#EFE0B5'; c.lineWidth = 8; c.stroke();
    } else if (this.stage === 1) {
      this.hill(185, 576, 275, 150, '#91A17A'); this.tree(136, 602, 0.9);
      this.pavilion(722, 453, 1.1); this.tree(851, 489, 0.75);
      this.polygon([{ x: 281, y: 340 }, { x: 615, y: 320 }, { x: 615, y: 609 }, { x: 281, y: 630 }], '#E3D1A4');
      this.polygon([{ x: 315, y: 370 }, { x: 580, y: 350 }, { x: 580, y: 578 }, { x: 315, y: 598 }], '#F0E2BB');
      for (let index = 0; index < 4; index++) this.line(351, 478 + index * 24, 540 - index % 2 * 34, 467 + index * 24, '#B7B18A', 2);
      if (this.amount < 98) {
        const left = 315 + this.amount * 2.7;
        this.polygon([{ x: left, y: 366 }, { x: 585, y: 350 }, { x: 585, y: 580 }, { x: left, y: 596 }], '#B8C59C');
        this.line(left, 366, left, 596, '#8C9D77', 3);
      }
    } else {
      this.river(); this.pavilion(580, 413, 1.35); this.tree(159, 541, 1.15);
      const colors: string[] = ['#AE6349', '#B6A366', '#769571'];
      for (let index = 0; index < 7; index++) {
        const x = 214 + index * 101; const y = 332 + Math.sin(index * 0.5) * 38;
        this.line(x, y, x + 11, 579, '#777F56', 4);
        this.polygon([{ x, y }, { x: x + 62, y: y + 10 }, { x: x + 45, y: y + 72 }, { x: x + 5, y: y + 54 }],
          this.choice >= 0 ? colors[(index + this.choice) % 3] : '#9BA585');
      }
      if (this.choice >= 0) {
        this.person(388, 566, '#C7AB72', 1.08); this.person(440, 576, '#AE7757', 1.12);
        this.person(655, 550, '#C7CE9B', 0.92); this.person(697, 547, '#997A53', 0.93);
      }
      if (this.choice === 0) {
        this.polygon([{ x: 284, y: 553 }, { x: 684, y: 553 }, { x: 690, y: 687 }, { x: 284, y: 687 }], '#C2B488');
        this.shellAnimal(487, 603, true);
      } else if (this.choice === 1) {
        this.polygon([{ x: 325, y: 542 }, { x: 666, y: 526 }, { x: 666, y: 672 }, { x: 325, y: 686 }], '#E7D8AD');
      } else if (this.choice === 2) {
        this.person(537, 601, '#B9835A', 1.35); this.person(588, 603, '#D5C58B', 1.3);
        this.person(748, 588, '#B89D6A', 1.1); this.person(784, 583, '#849A74', 1.08);
      }
    }
  }

  private draw(): void {
    if (!this.ready || this.widthVp <= 0 || this.heightVp <= 0) return;
    const c = this.context; c.clearRect(0, 0, this.widthVp, this.heightVp);
    c.save(); c.scale(this.widthVp / 1000, this.heightVp / 760);
    if (this.scene === 'ly-spring') this.springScene();
    else if (this.scene === 'zz-meeting') this.meetingScene();
    else if (this.scene === 'kf-night') this.nightScene();
    else if (this.scene === 'py-memory') this.dragonScene();
    else this.homeScene();
    c.restore();
  }

  @Builder
  canvasContent() {
    Canvas(this.context).width('100%').height('100%').id('roam-scene-canvas')
      .onReady(() => { this.ready = true; this.draw(); })
      .onAreaChange((_old: Area, area: Area) => {
        this.widthVp = Number(area.width); this.heightVp = Number(area.height); this.draw();
      })
      .hitTestBehavior(HitTestMode.None)
  }

  @Builder
  spotButton(spotId: string, label: string, x: number) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 5 }) {
        Text(this.found.includes(spotId) ? '✓' : '＋').fontSize(13).fontColor(R.page)
          .width(21).height(21).textAlign(TextAlign.Center).backgroundColor(R.river).borderRadius(11)
        Text(label).fontSize(12).fontWeight(FontWeight.Medium).fontColor(R.ink)
      }
    }.padding({ left: 5, right: 9, top: 5, bottom: 5 }).backgroundColor('#F4EBD4')
      .borderRadius(18).border({ width: 1, color: '#E3D9BA', radius: 18 })
      .position({ x: `${x}%`, y: '63%' }).id(`roam-spot-${spotId}`)
      .accessibilityText(`${label}，${this.found.includes(spotId) ? '已发现' : '观察线索'}`)
      .onClick(() => this.onSpot(spotId))
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.canvasContent()
      if (this.interactive && this.scene === 'smx-home' && this.stage === 0) {
        this.spotButton('kiln', '作', 15)
        this.spotButton('home', '居', 67)
      }
      // 唯一保留的图上小标注：说明这是原创示意而非复原图，属于必须保留的诚实标识。
      Text('原创叙事示意').fontSize(12).fontColor('#4C5F45')
        .padding({ left: 8, right: 8, top: 5, bottom: 5 }).backgroundColor('#F2F3E2D9').borderRadius(3)
        .position({ x: 12, y: 12 }).hitTestBehavior(HitTestMode.None)
    }.width('100%').height(this.sceneHeight).clip(true).id('roam-scene')
      .accessibilityText(`${this.scene === 'kf-night' ? '汴京' : this.scene === 'smx-home' ? '黄土家园' :
        this.scene === 'ly-spring' ? '洛阳春日' : this.scene === 'zz-meeting' ? '溱洧河畔' : '龙乡记忆'}原创场景，线索${this.stage + 1}`)
      .gesture(PanGesture({ direction: PanDirection.Horizontal, distance: 7 })
        .onActionStart(() => { this.panStart = this.amount; })
        .onActionUpdate((event: GestureEvent) => {
          if (!this.interactive) return;
          this.onMove(Math.max(0, Math.min(100, this.panStart + event.offsetX / Math.max(1, this.widthVp) * 140)));
        }))
  }
}
