/**
 * AccessProtocol Hook
 * Manages institutional deployment animations using GSAP
 */
export const AccessProtocol = {
  mounted() {
    this.initAnimations();
    
    // Listen for step changes from the server
    this.handleEvent("step_changed", ({ step }) => {
      this.animateStepTransition(step);
    });
  },

  initAnimations() {
    // Initial entrance animation
    // Initial entrance animation
    gsap.from(".text-center", {
      duration: 1.2,
      y: 30,
      opacity: 0,
      ease: "power4.out"
    });

    // Animate the protocol labels in the sidebar
    const protocolSteps = document.querySelectorAll(".protocol-step");
    if (protocolSteps.length > 0) {
      gsap.from(protocolSteps, {
        duration: 0.8,
        x: -15,
        opacity: 0,
        stagger: 0.08,
        delay: 0.3,
        ease: "power2.out",
        clearProps: "opacity,transform"
      });
    }
  },

  animateStepTransition(step) {
    const activeStep = document.querySelector(`[data-step="${step}"]`);
    if (!activeStep) return;

    // Animate the new step content
    gsap.fromTo(activeStep, 
      { x: 30, opacity: 0 },
      { x: 0, opacity: 1, duration: 0.8, ease: "power4.out" }
    );

    // Animate a "scanning" beam over the card
    const beam = document.createElement("div");
    beam.className = "absolute inset-0 z-50 pointer-events-none overflow-hidden rounded-[2.5rem]";
    beam.innerHTML = `<div class="w-full h-px bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.8)] absolute top-0 left-0 opacity-0 transition-opacity duration-300"></div>`;
    
    const card = document.querySelector(".prestige-card");
    if (card) {
      card.appendChild(beam);
      const beamLine = beam.firstChild;
      
      gsap.to(beamLine, { opacity: 1, duration: 0.2 });
      gsap.to(beamLine, {
        top: "100%",
        duration: 1.2,
        ease: "power2.inOut",
        onComplete: () => {
          gsap.to(beamLine, { opacity: 0, duration: 0.3, onComplete: () => beam.remove() });
        }
      });
    }
  }
};
