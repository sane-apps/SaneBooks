(() => {
  const header = document.querySelector(".site-header");
  const onScroll = () => {
    if (!header) return;
    header.classList.toggle("is-scrolled", window.scrollY > 12);
  };
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  const io = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-in");
          io.unobserve(entry.target);
        }
      }
    },
    { threshold: 0.18, rootMargin: "0px 0px -8% 0px" }
  );
  document.querySelectorAll(".reveal, .flow-step").forEach((el) => io.observe(el));

  // Big play overlay → native video. Never use a hash link here (that jumped to #how).
  const video = document.querySelector("#overview-video");
  const playBtn = document.querySelector("#overview-play");
  if (video && playBtn) {
    const hideOverlay = () => {
      playBtn.hidden = true;
    };
    const showOverlay = () => {
      if (video.paused) playBtn.hidden = false;
    };
    const start = () => {
      hideOverlay();
      const play = video.play();
      if (play && typeof play.catch === "function") {
        play.catch(() => {
          showOverlay();
        });
      }
    };
    playBtn.addEventListener("click", start);
    video.addEventListener("play", hideOverlay);
    video.addEventListener("pause", showOverlay);
    video.addEventListener("ended", () => {
      playBtn.hidden = false;
    });
  }
})();
