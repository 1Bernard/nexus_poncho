const LoginLive = {
  mounted() {
    this.handleEvent("login_challenge", ({ challenge }) => {
      this.authenticate(challenge);
    });

    this.handleEvent("login_success", ({ redirect }) => {
      setTimeout(() => { window.location.href = redirect; }, 1500);
    });

    this.initCursor();
    this.setupSensor();
  },

  updated() {
    this.setupSensor();
  },

  initCursor() {
    if (window.innerWidth <= 1024) return;
    const dot = document.getElementById("cursor-dot");
    const ring = document.getElementById("cursor-ring");
    if (!dot || !ring) return;

    // Suppress CSS transition so dot moves instantly (matches gsap duration:0)
    dot.style.transition = "none";

    let targetX = 0, targetY = 0;
    let ringX = 0, ringY = 0, vx = 0, vy = 0;

    document.addEventListener("mousemove", (e) => {
      targetX = e.clientX;
      targetY = e.clientY;
      dot.style.transform = `translate(${e.clientX}px, ${e.clientY}px)`;
    });

    // Spring physics — matches GSAP's organic deceleration feel
    const animateRing = () => {
      vx += (targetX - ringX) * 0.14;
      vy += (targetY - ringY) * 0.14;
      vx *= 0.78;
      vy *= 0.78;
      ringX += vx;
      ringY += vy;
      ring.style.transform = `translate(${ringX}px, ${ringY}px)`;
      this._cursorRaf = requestAnimationFrame(animateRing);
    };
    animateRing();
  },

  destroyed() {
    if (this._cursorRaf) cancelAnimationFrame(this._cursorRaf);
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
          this.pushEvent("biometric_login_start", {});
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

  async authenticate(challengeBase64) {
    try {
      const credential = await navigator.credentials.get({
        publicKey: {
          challenge: this.base64ToBuffer(challengeBase64),
          userVerification: "required",
          timeout: 60000,
        },
      });

      this.pushEvent("login_verify", {
        id: credential.id,
        rawId: this.bufferToBase64(credential.rawId),
        type: credential.type,
        response: {
          authenticatorData: this.bufferToBase64(credential.response.authenticatorData),
          clientDataJSON: this.bufferToBase64(credential.response.clientDataJSON),
          signature: this.bufferToBase64(credential.response.signature),
          userHandle: credential.response.userHandle
            ? this.bufferToBase64(credential.response.userHandle)
            : null,
        },
        ip_address: null,
        user_agent: navigator.userAgent,
      });
    } catch (err) {
      let reason = err.message;
      if (err.name === "NotAllowedError") {
        reason = err.message?.includes("focus") ? "page lost focus" : "sensor not responding";
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
};

export default LoginLive;
