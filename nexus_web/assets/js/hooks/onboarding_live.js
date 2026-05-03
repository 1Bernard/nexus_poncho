const OnboardingLive = {
  mounted() {
    this.handleEvent("biometric_challenge", ({ challenge }) => {
      this.enroll(challenge);
    });

    this.setupSensor();
    this.initAnimations();
  },

  updated() {
    this.setupSensor();
    this.initAnimations();
  },

  setupSensor() {
    const sensor = this.el.querySelector("#biometric-sensor");
    if (!sensor || sensor._sensorReady) return;
    sensor._sensorReady = true;

    let progress = 0;
    let interval = null;
    let isScanning = false;

    const ring = this.el.querySelector("#scan-ring");
    const scanLine = this.el.querySelector("#scan-line");
    const statusEl = this.el.querySelector("#sensor-status");

    const startScan = (e) => {
      if (isScanning) return;
      e.target.setPointerCapture(e.pointerId);
      isScanning = true;
      progress = 0;

      if (scanLine) { scanLine.classList.add("animate-scan-line"); scanLine.style.opacity = "1"; }
      if (statusEl) statusEl.innerHTML = '<span class="text-emerald-400">Transmitting Entropy...</span>';

      interval = setInterval(() => {
        progress += 2.5;
        if (ring) ring.style.strokeDashoffset = 628 - (628 * (progress / 100));

        const l1 = document.getElementById("scan-l1");
        const l2 = document.getElementById("scan-l2");
        const l3 = document.getElementById("scan-l3");
        if (progress >= 33 && l1) { l1.classList.remove("bg-emerald-400/10"); l1.classList.add("bg-emerald-400"); }
        if (progress >= 66 && l2) { l2.classList.remove("bg-emerald-400/10"); l2.classList.add("bg-emerald-400"); }

        if (progress >= 100) {
          if (l3) { l3.classList.remove("bg-emerald-400/10"); l3.classList.add("bg-emerald-400"); }
          clearInterval(interval);
          this.pushEvent("biometric_start", {});
        }
      }, 40);
    };

    const stopScan = () => {
      if (!isScanning) return;
      clearInterval(interval);
      isScanning = false;

      if (progress < 100) {
        if (ring) ring.style.strokeDashoffset = 628;
        if (scanLine) { scanLine.classList.remove("animate-scan-line"); scanLine.style.opacity = "0"; }
        if (statusEl) statusEl.innerHTML = '<span class="text-rose-400">Scan Interrupted — Hold Sensor</span>';
        ["scan-l1", "scan-l2", "scan-l3"].forEach(id => {
          const el = document.getElementById(id);
          if (el) { el.classList.remove("bg-emerald-400"); el.classList.add("bg-emerald-400/10"); }
        });
        progress = 0;
      }
    };

    sensor.addEventListener("pointerdown", startScan);
    sensor.addEventListener("pointerup", stopScan);
    sensor.addEventListener("pointerleave", stopScan);
  },

  async enroll(challengeBase64) {
    try {
      console.log("[WebAuthn] Preparing hardware handshake");

      window.focus();

      const challenge = this.base64ToBuffer(challengeBase64);
      const userId = this.el.dataset.userId;
      const userBuffer = new TextEncoder().encode(userId);

      const publicKeyCredentialCreationOptions = {
        challenge: challenge,
        rp: {
          name: "Nexus Poncho",
          id: window.location.hostname,
        },
        user: {
          id: userBuffer,
          name: userId,
          displayName: userId,
        },
        pubKeyCredParams: [
          { alg: -7, type: "public-key" },
          { alg: -257, type: "public-key" },
        ],
        authenticatorSelection: {
          authenticatorAttachment: "platform",
          userVerification: "required",
          residentKey: "required",
        },
        timeout: 60000,
        attestation: "direct",
      };

      const credential = await navigator.credentials.create({
        publicKey: publicKeyCredentialCreationOptions,
      });

      console.log("[WebAuthn] Handshake successful, encoding attestation");

      const attestation = {
        id: credential.id,
        rawId: this.bufferToBase64(credential.rawId),
        type: credential.type,
        response: {
          attestationObject: this.bufferToBase64(credential.response.attestationObject),
          clientDataJSON: this.bufferToBase64(credential.response.clientDataJSON),
        },
      };

      this.pushEvent("biometric_complete", { attestation });
    } catch (err) {
      console.error("[WebAuthn] Handshake failed:", err);

      let reason = err.message;
      if (err.name === "NotAllowedError" || err.message.includes("focus")) {
        reason = "Focus required: Please click the scanner directly to grant focus.";
      }

      this.pushEvent("biometric_error", { reason });
    }
  },

  base64ToBuffer(base64) {
    const binary = window.atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes.buffer;
  },

  bufferToBase64(buffer) {
    let binary = "";
    const bytes = new Uint8Array(buffer);
    for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
    return window.btoa(binary);
  },

  // ── Elite Handshake Ceremony ──────────────────────────────────────────────

  initAnimations() {
    // Check if we've already animated the welcome state
    if (this.el.dataset.animatedWelcome === "true") return;

    const card = this.el;
    const items = card.querySelectorAll(".group");
    
    // We only proceed if the identity rows (biodata) are present in the DOM
    if (items.length === 0) return;
    
    this.el.dataset.animatedWelcome = "true";

    const header = card.querySelector("h1");
    const subtext = card.querySelector("p");
    const button = card.querySelector(".cta-primary");

    const tl = gsap.timeline();

    tl.fromTo(header, { y: 20, opacity: 0 }, { duration: 0.8, y: 0, opacity: 1, ease: "power4.out" })
      .fromTo(subtext, { y: 10, opacity: 0 }, { duration: 0.6, y: 0, opacity: 1, ease: "power3.out" }, "-=0.4")
      .fromTo(items, { x: -20, opacity: 0 }, { duration: 0.8, x: 0, opacity: 1, stagger: 0.1, ease: "power2.out" }, "-=0.3")
      .fromTo(button, { y: 20, opacity: 0 }, { duration: 0.6, y: 0, opacity: 1, ease: "back.out(1.7)", clearProps: "all" }, "-=0.4");

    // Scanning Beam Ceremony (one-time on mount/update)
    this.triggerScanningBeam();
  },

  triggerScanningBeam() {
    const card = this.el;
    const beam = document.createElement("div");
    beam.className = "absolute inset-0 z-50 pointer-events-none overflow-hidden rounded-[2.5rem]";
    beam.innerHTML = `<div class="w-full h-px bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.8)] absolute top-0 left-0 opacity-0"></div>`;
    
    card.appendChild(beam);
    const beamLine = beam.firstChild;
    
    gsap.set(beamLine, { top: "0%", opacity: 0 });
    gsap.to(beamLine, { opacity: 1, duration: 0.2 });
    gsap.to(beamLine, {
      top: "100%",
      duration: 1.5,
      ease: "power2.inOut",
      onComplete: () => {
        gsap.to(beamLine, { opacity: 0, duration: 0.3, onComplete: () => beam.remove() });
      }
    });
  }
};

export default OnboardingLive;
