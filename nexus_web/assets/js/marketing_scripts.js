/**
 * Equinox Institutional Marketing Scripts
 * Handles: Custom Cursor, Globals, Three.js Globe, GSAP Animations, Accordions
 */

export const Marketing = {
  init() {
    this.initLucide();
    this.initCursor();
    this.initNav();
    this.initAnimations();
    this.initAccordions();
    this.initGlobe();
    this.initNotifications();
    this.initTickers();
  },

  initLucide() {
    if (window.lucide) {
      window.lucide.createIcons();
    }
  },

  initCursor() {
    const dot = document.getElementById('cursor-dot');
    const ring = document.getElementById('cursor-ring');
    if (!dot || !ring) return;

    let mx = 0, my = 0, rx = 0, ry = 0;
    document.addEventListener('mousemove', e => {
      mx = e.clientX;
      my = e.clientY;
      dot.style.left = mx + 'px';
      dot.style.top = my + 'px';
    });

    const animRing = () => {
      rx += (mx - rx) * 0.12;
      ry += (my - ry) * 0.12;
      ring.style.left = rx + 'px';
      ring.style.top = ry + 'px';
      requestAnimationFrame(animRing);
    };
    animRing();
  },

  initNav() {
    const nav = document.getElementById('main-nav');
    if (!nav) return;
    window.addEventListener('scroll', () => {
      nav.classList.toggle('scrolled', window.scrollY > 80);
    });
  },

  initAnimations() {
    if (!window.gsap || !window.ScrollTrigger) return;
    const gsap = window.gsap;
    gsap.registerPlugin(window.ScrollTrigger);

    // Hero timeline
    const tl = gsap.timeline({ defaults: { ease: 'power3.out' } });
    tl.to('#hero-badge', { opacity: 1, duration: 0.6 })
      .to('#hero-line-1', { opacity: 1, y: 0, duration: 0.8 }, '-=0.3')
      .to('#hero-line-2', { opacity: 1, y: 0, duration: 0.8 }, '-=0.5')
      .to('#hero-desc', { opacity: 1, y: 0, duration: 0.7 }, '-=0.4')
      .to('#hero-ctas', { opacity: 1, duration: 0.6 }, '-=0.3');

    // Scroll reveals
    gsap.utils.toArray('.reveal-y').forEach(el => {
      gsap.to(el, {
        opacity: 1,
        y: 0,
        duration: 0.8,
        ease: 'power3.out',
        scrollTrigger: { trigger: el, start: 'top 85%' }
      });
    });

    // Roadmap line animation (Elite border draw)
    gsap.to('.roadmap-line', {
      height: '100%',
      ease: 'none',
      scrollTrigger: {
        trigger: '#roadmap',
        start: 'top 40%',
        end: 'bottom 60%',
        scrub: true
      }
    });

    // Counter animations
    document.querySelectorAll('.counter').forEach(el => {
      const target = parseFloat(el.dataset.target);
      const isDecimal = target % 1 !== 0;
      window.ScrollTrigger.create({
        trigger: el,
        start: 'top 85%',
        once: true,
        onEnter: () => {
          let start = 0;
          const step = target / 60;
          const timer = setInterval(() => {
            start += step;
            if (start >= target) {
              el.textContent = isDecimal ? target.toFixed(1) : target;
              clearInterval(timer);
            } else {
              el.textContent = isDecimal ? start.toFixed(1) : Math.floor(start);
            }
          }, 16);
        }
      });
    });
  },

  initAccordions() {
    document.querySelectorAll('.accordion-trigger').forEach(btn => {
      btn.addEventListener('click', () => {
        const item = btn.parentElement;
        const content = item.querySelector('.accordion-content');
        const icon = btn.querySelector('.accordion-icon');
        const isOpen = content.classList.contains('active');

        document.querySelectorAll('.accordion-content').forEach(c => c.classList.remove('active'));
        document.querySelectorAll('.accordion-icon').forEach(i => {
          i.textContent = '+';
          i.style.transform = 'rotate(0deg)';
        });

        if (!isOpen) {
          content.classList.add('active');
          icon.textContent = '−';
          icon.style.transform = 'rotate(0deg)';
        }
      });
    });
  },

  initGlobe() {
    const container = document.getElementById('globe-container');
    if (!container || !window.THREE) return;

    const THREE = window.THREE;
    const W = container.clientWidth, H = container.clientHeight;
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setSize(W, H);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    container.appendChild(renderer.domElement);

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(45, W / H, 0.1, 1000);
    camera.position.z = 2.5;

    scene.add(new THREE.AmbientLight(0x222222));
    const sun = new THREE.DirectionalLight(0xffffff, 1.2);
    sun.position.set(-3, 1, 2);
    scene.add(sun);

    // Globe Core
    scene.add(new THREE.Mesh(
      new THREE.SphereGeometry(1, 64, 64),
      new THREE.MeshPhongMaterial({ color: 0x040d14, emissive: 0x001a0a, shininess: 15 })
    ));

    // Grid System
    const gridMat = new THREE.LineBasicMaterial({ color: 0x34d399, transparent: true, opacity: 0.1 });
    for (let lat = -80; lat <= 80; lat += 20) {
      const pts = [];
      for (let lon = 0; lon <= 360; lon += 4)
        pts.push(new THREE.Vector3().setFromSphericalCoords(1.003, (90 - lat) * Math.PI / 180, lon * Math.PI / 180));
      scene.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), gridMat));
    }

    // Helper for Lat/Lon to Vector3
    const llv = (lat, lon, r) => {
      return new THREE.Vector3().setFromSphericalCoords(r, (90 - lat) * Math.PI / 180, (lon + 180) * Math.PI / 180);
    };

    // Cities / Nodes
    const cities = [
      [51.5, -0.1], [40.7, -74.0], [1.3, 103.8], [35.6, 139.7],
      [48.8, 2.3], [25.2, 55.3], [19.0, 72.8], [22.3, 114.2],
      [-23.5, -46.6], [55.7, 37.6], [6.5, 3.4], [-26.2, 28.0],
      [31.2, 121.5], [-33.9, 151.2]
    ];
    const dotG = new THREE.SphereGeometry(0.013, 8, 8);
    const dotM = new THREE.MeshBasicMaterial({ color: 0x34d399 });
    cities.forEach(([lat, lon]) => {
      const d = new THREE.Mesh(dotG, dotM);
      d.position.copy(llv(lat, lon, 1.015));
      scene.add(d);
    });

    // Outer Glow
    scene.add(new THREE.Mesh(
      new THREE.SphereGeometry(1.12, 32, 32),
      new THREE.MeshPhongMaterial({ color: 0x34d399, transparent: true, opacity: 0.04, side: THREE.BackSide })
    ));

    const equatorRing = new THREE.Mesh(
      new THREE.TorusGeometry(1.2, 0.003, 8, 180),
      new THREE.MeshBasicMaterial({ color: 0x34d399, transparent: true, opacity: 0.25 })
    );
    equatorRing.rotation.x = Math.PI / 2.5;
    scene.add(equatorRing);

    // Loop
    const loop = () => {
      requestAnimationFrame(loop);
      equatorRing.rotation.z += 0.0008;
      renderer.render(scene, camera);
    };
    loop();

    window.addEventListener('resize', () => {
      const nW = container.clientWidth, nH = container.clientHeight;
      camera.aspect = nW / nH;
      camera.updateProjectionMatrix();
      renderer.setSize(nW, nH);
    });
  },

  initNotifications() {
    const txEvents = [
      { from: 'London', to: 'Dubai', amount: '$4.2M', currency: 'USD/AED', type: 'FX Transfer' },
      { from: 'Frankfurt', to: 'Singapore', amount: '€8.7M', currency: 'EUR/SGD', type: 'Netting Settlement' },
      { from: 'New York', to: 'Lagos', amount: '$1.9M', currency: 'USD/NGN', type: 'Vault Credit' },
      { from: 'Zurich', to: 'Mumbai', amount: 'CHF 3.1M', currency: 'CHF/INR', type: 'Interco Transfer' },
      { from: 'Tokyo', to: 'Amsterdam', amount: '¥520M', currency: 'JPY/EUR', type: 'FX Hedge' },
    ];
    let txIndex = 0;
    const notifContainer = document.getElementById('notification-container');
    const showTxNotification = () => {
      if (!notifContainer) return;
      const tx = txEvents[txIndex % txEvents.length];
      txIndex++;
      const div = document.createElement('div');
      div.className = 'tx-notification';
      div.style.top = (20 + Math.random() * 60) + '%';
      div.style.left = (5 + Math.random() * 55) + '%';
      div.innerHTML = `
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:6px;">
          <span style="width:6px;height:6px;background:#34d399;border-radius:50%;display:inline-block;box-shadow:0 0 8px #34d399;"></span>
          <span style="font-family:monospace;font-size:9px;color:#34d399;text-transform:uppercase;letter-spacing:0.2em;">${tx.type}</span>
        </div>
        <div style="font-size:13px;font-weight:600;margin-bottom:4px;">${tx.amount} <span style="color:#34d399;">${tx.currency}</span></div>
        <div style="font-size:10px;color:#71717a;">${tx.from} → ${tx.to}</div>`;
      notifContainer.appendChild(div);
      setTimeout(() => {
        div.style.transition = 'opacity 0.5s';
        div.style.opacity = '0';
        setTimeout(() => div.remove(), 500);
      }, 3000);
    };
    setInterval(showTxNotification, 2500);
  },

  initTickers() {
    const nudge = (el, base, spread) => {
      if (!el) return;
      const v = base + (Math.random() - 0.5) * spread;
      el.textContent = v.toFixed(4);
    };
    setInterval(() => {
      nudge(document.getElementById('fx-eurusd'), 1.0847, 0.004);
      nudge(document.getElementById('fx-gbpusd'), 1.2634, 0.005);
      nudge(document.getElementById('fx-usdjpy'), 149.82, 0.1);
    }, 2000);
  }
};
