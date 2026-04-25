import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';

export const Marketing = {
    _rafId: null,
    _renderer: null,

    init() {
        this.initCore();
        this.initThreeGlobe();
        this.initAnimations();
        this.initPricingToggle();
        this.initAccordions();
        this.initParallaxCards();
        this.initRoadmapProgress();
    },

    destroy() {
        if (this._rafId) cancelAnimationFrame(this._rafId);
        if (this._renderer) this._renderer.dispose();
        this._rafId = null;
        this._renderer = null;
    },

    initCore() {
        if (typeof gsap === 'undefined') return;
        gsap.registerPlugin(ScrollTrigger);

        // Custom Cursor
        if (window.innerWidth > 1024) {
            const cursorDot = document.getElementById('cursor-dot');
            const cursorRing = document.getElementById('cursor-ring');
            if (cursorDot && cursorRing) {
                window.addEventListener('mousemove', (e) => {
                    gsap.to(cursorDot, { x: e.clientX, y: e.clientY, duration: 0 });
                    gsap.to(cursorRing, { x: e.clientX, y: e.clientY, duration: 0.1 });
                });
            }
        }

        // Navigation Scroll Effect
        const nav = document.getElementById('main-nav');
        if (nav) {
            window.addEventListener('scroll', () => {
                if (window.scrollY > 50) { 
                    nav.classList.add('scrolled'); 
                } else { 
                    nav.classList.remove('scrolled'); 
                }
            });
        }

        // Initialize Lucide Icons
        if (typeof lucide !== 'undefined') {
            lucide.createIcons();
        }
    },

    initThreeGlobe() {
        const container = document.getElementById('globe-container');
        if (!container) return;

        const width = container.clientWidth;
        const height = container.clientHeight;

        const scene = new THREE.Scene();
        scene.background = new THREE.Color(0x010101);

        const camera = new THREE.PerspectiveCamera(45, width / height, 0.1, 1000);
        camera.position.set(0, 0.2, 3.5);

        const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
        renderer.setSize(width, height);
        renderer.setPixelRatio(window.devicePixelRatio);
        container.appendChild(renderer.domElement);
        this._renderer = renderer;

        const controls = new OrbitControls(camera, renderer.domElement);
        controls.enableDamping = true;
        controls.autoRotate = true;
        controls.autoRotateSpeed = 0.5;

        const textureLoader = new THREE.TextureLoader();
        const earthMap = textureLoader.load('/images/textures/earth_atmos_2048.jpg');
        const earthSpecularMap = textureLoader.load('/images/textures/earth_specular_2048.jpg');
        const earthNormalMap = textureLoader.load('/images/textures/earth_normal_2048.jpg');
        const cloudMap = textureLoader.load('/images/textures/earth_clouds_1024.png');
        
        const earthGeometry = new THREE.SphereGeometry(1.0, 128, 128);
        const earthMaterial = new THREE.MeshPhongMaterial({ 
            map: earthMap, 
            specularMap: earthSpecularMap, 
            specular: new THREE.Color('grey'), 
            shininess: 5, 
            normalMap: earthNormalMap 
        });
        const earth = new THREE.Mesh(earthGeometry, earthMaterial);
        scene.add(earth);
        
        const cloudGeometry = new THREE.SphereGeometry(1.01, 128, 128);
        const cloudMaterial = new THREE.MeshPhongMaterial({ 
            map: cloudMap, 
            transparent: true, 
            opacity: 0.15, 
            blending: THREE.AdditiveBlending 
        });
        const clouds = new THREE.Mesh(cloudGeometry, cloudMaterial);
        scene.add(clouds);
        
        const cities = [
            { lat: 40.7, lon: -74.0, name: 'New York' }, 
            { lat: 51.5, lon: -0.1, name: 'London' }, 
            { lat: 35.7, lon: 139.7, name: 'Tokyo' },
            { lat: 22.3, lon: 114.2, name: 'Hong Kong' }, 
            { lat: 1.3, lon: 103.8, name: 'Singapore' }, 
            { lat: 37.8, lon: -122.4, name: 'San Francisco' }
        ];
        
        function latLonToVector(lat, lon, radius) {
            const phi = (90 - lat) * Math.PI / 180;
            const theta = lon * Math.PI / 180;
            return new THREE.Vector3(
                radius * Math.sin(phi) * Math.cos(theta), 
                radius * Math.cos(phi), 
                radius * Math.sin(phi) * Math.sin(theta)
            );
        }
        
        cities.forEach(city => {
            const pos = latLonToVector(city.lat, city.lon, 1.02);
            const sphereGeo = new THREE.SphereGeometry(0.015, 16, 16);
            const sphereMat = new THREE.MeshStandardMaterial({ 
                color: 0x34d399, 
                emissive: 0x34d399, 
                emissiveIntensity: 1 
            });
            const node = new THREE.Mesh(sphereGeo, sphereMat);
            node.position.copy(pos);
            scene.add(node);
        });
        
        const particles = [];
        const routes = [
            { from: cities[0], to: cities[1] }, { from: cities[1], to: cities[2] }, 
            { from: cities[2], to: cities[3] }, { from: cities[3], to: cities[4] }, 
            { from: cities[4], to: cities[5] }, { from: cities[5], to: cities[0] }
        ];
        
        routes.forEach(route => {
            const start = latLonToVector(route.from.lat, route.from.lon, 1.03);
            const end = latLonToVector(route.to.lat, route.to.lon, 1.03);
            const points = [];
            for (let t = 0; t <= 1; t += 0.05) {
                const point = start.clone().lerp(end, t);
                const height = Math.sin(t * Math.PI) * 0.12;
                const dir = point.clone().normalize();
                points.push(dir.multiplyScalar(1.03 + height));
            }
            const lineGeometry = new THREE.BufferGeometry().setFromPoints(points);
            const lineMaterial = new THREE.LineBasicMaterial({ color: 0x34d399, transparent: true, opacity: 0.2 });
            const line = new THREE.Line(lineGeometry, lineMaterial);
            scene.add(line);
        });

        for (let i = 0; i < 80; i++) {
            const route = routes[i % routes.length];
            const start = latLonToVector(route.from.lat, route.from.lon, 1.03);
            const end = latLonToVector(route.to.lat, route.to.lon, 1.03);
            const particleGeo = new THREE.SphereGeometry(0.006, 8, 8);
            const particleMat = new THREE.MeshStandardMaterial({ color: 0x34d399, emissive: 0x34d399, emissiveIntensity: 2 });
            const particle = new THREE.Mesh(particleGeo, particleMat);
            particle.userData = { start, end, progress: Math.random(), speed: 0.001 + Math.random() * 0.002, route };
            scene.add(particle);
            particles.push(particle);
        }

        const ambientLight = new THREE.AmbientLight(0x404040);
        scene.add(ambientLight);
        const directionalLight = new THREE.DirectionalLight(0xffffff, 1.2);
        directionalLight.position.set(5, 3, 5);
        scene.add(directionalLight);
        const fillLight = new THREE.PointLight(0x34d399, 0.5);
        fillLight.position.set(-2, -2, -2);
        scene.add(fillLight);

        let activeNotifications = 0;
        let lastNotificationTime = 0;

        const showTransactionNotification = (fromCity, toCity, amount) => {
            const now = Date.now();
            if (activeNotifications >= 4 || now - lastNotificationTime < 1500) return;
            lastNotificationTime = now;
            
            const container = document.getElementById('notification-container');
            if (!container) return;
            const notification = document.createElement('div');
            activeNotifications++;
            notification.className = 'tx-notification';
            notification.style.bottom = Math.random() * 40 + 30 + '%';
            notification.style.left = Math.random() * 50 + 25 + '%';
            notification.innerHTML = `<div class="flex items-center gap-2 mb-1"><div class="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse"></div><span class="text-[8px] font-mono text-emerald-400 uppercase tracking-widest">Global Settlement</span></div><div class="text-[10px] font-semibold text-white mb-0.5">${fromCity} → ${toCity}</div><div class="text-xs font-bold text-white">$${amount}M <span class="text-[8px] text-zinc-500 font-light ml-1">USDC</span></div>`;
            container.appendChild(notification);
            gsap.fromTo(notification, { opacity: 0, scale: 0.8 }, { opacity: 1, scale: 1, duration: 0.5 });
            gsap.to(notification, { opacity: 0, y: -20, delay: 3, duration: 0.5, onComplete: () => { notification.remove(); activeNotifications--; } });
        }

        const animate = () => {
            this._rafId = requestAnimationFrame(animate);
            particles.forEach(p => {
                p.userData.progress += p.userData.speed;
                if (p.userData.progress >= 1) {
                    p.userData.progress = 0;
                    showTransactionNotification(p.userData.route.from.name, p.userData.route.to.name, Math.floor(Math.random() * 500 + 50));
                }
                const t = p.userData.progress;
                const pos = p.userData.start.clone().lerp(p.userData.end, t);
                const height = Math.sin(t * Math.PI) * 0.12;
                p.position.copy(pos.clone().normalize().multiplyScalar(1.03 + height));
            });
            clouds.rotation.y += 0.0005;
            earth.rotation.y += 0.0002;
            controls.update();
            renderer.render(scene, camera);
        }
        animate();

        window.addEventListener('resize', () => {
            camera.aspect = container.clientWidth / container.clientHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(container.clientWidth, container.clientHeight);
        });
    },

    initAnimations() {
        if (typeof gsap === 'undefined') return;

        // Hero Animations
        const tl = gsap.timeline();
        tl.to('#hero-line-1', { opacity: 1, y: 0, duration: 1.2, ease: "expo.out" }, 0.5)
          .to('#hero-line-2', { opacity: 1, y: 0, duration: 1.2, ease: "expo.out" }, 0.8)
          .to('#hero-desc', { opacity: 1, y: 0, duration: 1.2, ease: "expo.out" }, 1.1)
          .to('#hero-ctas', { opacity: 1, y: 0, duration: 1.2, ease: "expo.out" }, 1.3);

        // Global Reveal
        document.querySelectorAll('.reveal-y').forEach(el => {
            gsap.to(el, {
                scrollTrigger: { trigger: el, start: "top 90%" },
                y: 0, opacity: 1, duration: 1.2, ease: "expo.out"
            });
        });

        // Stats Counters
        document.querySelectorAll('.counter').forEach(counter => {
            const target = parseFloat(counter.getAttribute('data-target'));
            ScrollTrigger.create({
                trigger: counter,
                start: "top 95%",
                onEnter: () => {
                    gsap.to(counter, {
                        innerText: target,
                        duration: 2,
                        snap: { innerText: target % 1 === 0 ? 1 : 0.01 },
                        ease: "power2.out"
                    });
                }
            });
        });

        // Realtime sync ghosts
        gsap.to("#cursor-ghost-1", { x: 60, y: 20, duration: 3, repeat: -1, yoyo: true, ease: "sine.inOut" });
        gsap.to("#cursor-ghost-2", { x: -40, y: -30, duration: 4, repeat: -1, yoyo: true, ease: "sine.inOut" });
        gsap.to("#cursor-ghost-3", { x: 20, y: 50, duration: 5, repeat: -1, yoyo: true, ease: "sine.inOut", delay: 1 });

        // Vector Matrix Initialization
        this.initVectorMatrix();

        // Vector Search Floating
        gsap.to(".vector-dot", {
            y: "random(-8, 8)",
            x: "random(-8, 8)",
            duration: 2.5,
            repeat: -1, yoyo: true, stagger: 0.2, ease: "sine.inOut"
        });

        // Edge Functions Globe
        const globeViz = document.getElementById('globe-viz');
        if (globeViz) gsap.to(globeViz, { rotation: 360, duration: 80, repeat: -1, ease: "none" });
    },

    initPricingToggle() {
        const pricingToggles = document.querySelectorAll('.pricing-toggle');
        if (pricingToggles.length < 2) return;

        pricingToggles[0].classList.add('bg-emerald-400', 'text-obsidian');
        pricingToggles[1].classList.add('text-zinc-500');

        pricingToggles.forEach(toggle => {
            toggle.addEventListener('click', () => {
                const period = toggle.getAttribute('data-period');
                pricingToggles.forEach(btn => {
                    btn.classList.toggle('bg-emerald-400', btn === toggle);
                    btn.classList.toggle('text-obsidian', btn === toggle);
                    btn.classList.toggle('text-zinc-500', btn !== toggle);
                });
                document.querySelectorAll('.price-display').forEach(display => {
                    const target = parseFloat(display.getAttribute(`data-${period}`));
                    gsap.to(display, {
                        innerText: target,
                        duration: 0.6,
                        snap: { innerText: 1 },
                        onUpdate: function() { display.innerHTML = `$${Math.ceil(this.targets()[0].innerText)}`; }
                    });
                });
                document.querySelectorAll('.price-period').forEach(p => {
                    p.innerText = period === 'monthly' ? '/month' : '/year';
                });
            });
        });
    },

    initAccordions() {
        document.querySelectorAll('.accordion-trigger').forEach(trigger => {
            trigger.addEventListener('click', () => {
                const item = trigger.parentElement;
                const content = item.querySelector('.accordion-content');
                const icon = item.querySelector('.accordion-icon');
                const isOpen = item.classList.contains('active');

                document.querySelectorAll('.accordion-item').forEach(other => {
                    if (other !== item && other.classList.contains('active')) {
                        other.classList.remove('active');
                        gsap.to(other.querySelector('.accordion-content'), { height: 0, duration: 0.5 });
                        other.querySelector('.accordion-icon').innerText = '+';
                    }
                });

                item.classList.toggle('active');
                if (!isOpen) {
                    gsap.to(content, { height: "auto", duration: 0.5 });
                    icon.innerText = '−';
                } else {
                    gsap.to(content, { height: 0, duration: 0.5 });
                    icon.innerText = '+';
                }
            });
        });
    },

    initParallaxCards() {
        document.querySelectorAll('.elite-card').forEach(card => {
            card.addEventListener('mousemove', (e) => {
                const rect = card.getBoundingClientRect();
                const x = (e.clientX - rect.left) / rect.width - 0.5;
                const y = (e.clientY - rect.top) / rect.height - 0.5;
                gsap.to(card.querySelectorAll('.parallax-layer, svg'), {
                    x: x * 20, y: y * 20, rotationY: x * 10, rotationX: -y * 10, duration: 0.5
                });
            });
            card.addEventListener('mouseleave', () => {
                gsap.to(card.querySelectorAll('.parallax-layer, svg'), {
                    x: 0, y: 0, rotationY: 0, rotationX: 0, duration: 0.8, ease: "elastic.out(1, 0.3)"
                });
            });
        });
    },

    initRoadmapProgress() {
        const roadmapContainer = document.getElementById('roadmap-container');
        const progressBar = document.getElementById('roadmap-progress');
        if (!roadmapContainer || !progressBar) return;

        gsap.to(progressBar, {
            height: "100%",
            ease: "none",
            scrollTrigger: {
                trigger: roadmapContainer,
                start: "top 80%",
                end: "bottom 80%",
                scrub: true
            }
        });

        document.querySelectorAll('.roadmap-item').forEach((item) => {
            ScrollTrigger.create({
                trigger: item,
                start: "top 80%",
                onEnter: () => {
                    gsap.to(item, { opacity: 1, y: 0, duration: 0.8 });
                    const dot = item.querySelector('.roadmap-dot');
                    if (dot) {
                        dot.style.background = '#34d399';
                        dot.style.boxShadow = '0 0 15px #34d399';
                    }
                },
                onLeaveBack: () => {
                    const dot = item.querySelector('.roadmap-dot');
                    if (dot) {
                        dot.style.background = 'rgba(52, 211, 153, 0.2)';
                        dot.style.boxShadow = 'none';
                    }
                }
            });
        });
    },

    initVectorMatrix() {
        const matrix = document.getElementById('vector-dots-matrix');
        if (!matrix) return;

        const count = 12;
        const spacing = 15;
        const startX = 100 - (count * spacing) / 2;
        const startY = 100 - (count * spacing) / 2;

        for (let i = 0; i < count; i++) {
            for (let j = 0; j < count; j++) {
                const dot = document.createElementNS("http://www.w3.org/2000/svg", "circle");
                const x = startX + i * spacing;
                const y = startY + j * spacing;
                dot.setAttribute("cx", x);
                dot.setAttribute("cy", y);
                dot.setAttribute("r", 0.6);
                dot.setAttribute("class", "vector-dot opacity-20 fill-emerald-400");
                matrix.appendChild(dot);
            }
        }
    }
};
