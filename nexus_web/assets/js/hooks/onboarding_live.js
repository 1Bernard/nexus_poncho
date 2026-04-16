const OnboardingLive = {
  mounted() {
    this.handleEvent("biometric_challenge", ({ challenge }) => {
      this.enroll(challenge);
    });

    window.addEventListener("nx:biometric-start", (e) => {
      // Potentially add UI feedback on trigger
      console.log("[WebAuthn] Handshake sequence initiated");
    });
  },

  async enroll(challengeBase64) {
    try {
      console.log("[WebAuthn] Preparing hardware handshake");

      // Ensure the window has focus before starting the handshake
      // This helps prevent NotAllowedError in some browsers
      window.focus();

      // 1. Decode challenge from Base64
      const challenge = this.base64ToBuffer(challengeBase64);
      const userId = this.el.dataset.userId;
      const userBuffer = new TextEncoder().encode(userId);

      // 2. Configure creation options
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
          { alg: -7, type: "public-key" }, // ES256
          { alg: -257, type: "public-key" }, // RS256
        ],
        authenticatorSelection: {
          authenticatorAttachment: "platform", // Force TouchID/FaceID if available
          userVerification: "required",
          residentKey: "required",
        },
        timeout: 60000,
        attestation: "direct",
      };

      // 3. Trigger browser WebAuthn API
      const credential = await navigator.credentials.create({
        publicKey: publicKeyCredentialCreationOptions,
      });

      console.log("[WebAuthn] Handshake successful, encoding attestation");

      // 4. Encode response and send back to LiveView
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
    const binaryString = window.atob(base64);
    const len = binaryString.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes.buffer;
  },

  bufferToBase64(buffer) {
    let binary = "";
    const bytes = new Uint8Array(buffer);
    const len = bytes.byteLength;
    for (let i = 0; i < len; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    return window.btoa(binary);
  },
};

export default OnboardingLive;
